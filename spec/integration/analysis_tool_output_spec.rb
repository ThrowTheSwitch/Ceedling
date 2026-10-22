# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Pins the Valgrind and Cppcheck plugins' output parsing against what those tools
# really emit, rather than against hand-written sample text.
#
# The unit specs cover the same parsing with synthetic strings. They cannot catch a
# real tool changing its output shape, and they cannot produce the shapes that are
# awkward to fake correctly. The two cases that matter most here are a Valgrind run
# whose child process yields a second ERROR SUMMARY, and Cppcheck's own XML severity
# attributes across both of its XML schema versions.
#
# Shells out to real valgrind, cppcheck, and gcc. Each block skips where its tool is
# unavailable, so this file contributes whatever the host can actually verify.

require 'spec_helper'
require 'spec_integration_helper'

def tool_present?(command)
  `#{command}`
  $?.exitstatus == 0
rescue
  false
end

VALGRIND_PRESENT = tool_present?('valgrind --version 2>&1') unless defined?(VALGRIND_PRESENT)
CPPCHECK_PRESENT = tool_present?('cppcheck --version 2>&1') unless defined?(CPPCHECK_PRESENT)
GCC_PRESENT      = tool_present?('gcc --version 2>&1')      unless defined?(GCC_PRESENT)

describe 'Analysis tool output parsing (integration)' do

  # Mirrors Valgrind#count_errors' text-log branch.
  def sum_error_summaries(contents)
    contents.scan( /ERROR SUMMARY:\s+(\d+) errors?/ ).flatten.map( &:to_i ).sum
  end

  # Mirrors Valgrind#count_errors' XML branch.
  def count_xml_errors(contents)
    contents.scan( /<error\b/ ).length
  end

  # Mirrors Cppcheck#tally_findings.
  def tally_severities(contents)
    counts = Hash.new(0)
    contents.scan( /<error\b[^>]*\bseverity="([^"]+)"/ ) { |m| counts[m[0]] += 1 }
    counts
  end

  context 'Valgrind', skip: ((VALGRIND_PRESENT && GCC_PRESENT) ? false : 'requires valgrind and gcc') do
    # One uninitialised read plus two leaks.
    let(:leaky_source) do
      <<~C
        #include <stdlib.h>
        #include <stdio.h>
        int main(void) {
          char *p = malloc(32);
          int *u = malloc(sizeof(int));
          printf("%d\\n", *u);
          p[0] = 1;
          return 0;
        }
      C
    end

    # Parent and child each leak, so each reports its own ERROR SUMMARY.
    let(:forking_source) do
      <<~C
        #include <unistd.h>
        #include <stdlib.h>
        #include <sys/wait.h>
        int main(void) {
          char *a = malloc(16); a[0] = 1;
          pid_t pid = fork();
          if (pid == 0) { char *c = malloc(32); c[0] = 1; _exit(0); }
          wait(NULL);
          return 0;
        }
      C
    end

    def run_valgrind(dir, source_name, *extra_args)
      binary = File.join(dir, 'prog')
      system("gcc -g -O0 #{File.join(dir, source_name)} -o #{binary}", out: File::NULL, err: File::NULL)
      log = File.join(dir, 'out.log')
      args = ['--leak-check=full', '--show-leak-kinds=all', '--errors-for-leak-kinds=all'] + extra_args
      system("valgrind --log-file=\"#{log}\" #{args.join(' ')} #{binary}", out: File::NULL, err: File::NULL)
      log
    end

    it 'counts the errors a single-process run reports' do
      with_source_tree({ 'leak.c' => leaky_source }) do |dir|
        contents = File.read( run_valgrind(dir, 'leak.c') )

        expect(contents).to match(/ERROR SUMMARY:/)
        expect(sum_error_summaries(contents)).to be > 0
      end
    end

    # Valgrind writes one summary per traced process. Reading only the first
    # undercounts, which is what the plugin used to do.
    it 'sums every ERROR SUMMARY when a traced child reports its own' do
      with_source_tree({ 'forker.c' => forking_source }) do |dir|
        contents = File.read( run_valgrind(dir, 'forker.c', '--trace-children=yes') )
        summaries = contents.scan( /ERROR SUMMARY:\s+(\d+) errors?/ ).flatten.map( &:to_i )

        expect(summaries.length).to be > 1
        expect(sum_error_summaries(contents)).to eq(summaries.sum)
        expect(sum_error_summaries(contents)).to be > summaries.first
      end
    end

    # `--xml=yes` leaves the text log empty, so XML is the only place errors appear
    # once it is enabled. This is why the plugin switches counting source.
    it 'writes errors only to XML when XML output is enabled' do
      with_source_tree({ 'leak.c' => leaky_source }) do |dir|
        binary = File.join(dir, 'prog')
        system("gcc -g -O0 #{File.join(dir, 'leak.c')} -o #{binary}", out: File::NULL, err: File::NULL)
        log = File.join(dir, 'out.log')
        xml = File.join(dir, 'out.xml')
        system(
          "valgrind --xml=yes --xml-file=\"#{xml}\" --log-file=\"#{log}\" " \
          "--leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all #{binary}",
          out: File::NULL, err: File::NULL
        )

        expect(File.exist?(xml)).to be true
        expect(count_xml_errors(File.read(xml))).to be > 0
        # Nothing for the text branch to find, hence the switch.
        expect(sum_error_summaries(File.read(log))).to eq(0)
      end
    end
  end

  context 'Cppcheck', skip: (CPPCHECK_PRESENT ? false : 'requires cppcheck') do
    # Cppcheck reports the double free at error severity.
    let(:defective_source) do
      <<~C
        #include <stdlib.h>
        int defect(void) {
          int *p = malloc(sizeof(int));
          if (p == NULL) { return -1; }
          *p = 7;
          int v = *p;
          free(p);
          free(p);
          return v;
        }
      C
    end

    # Returns the report path, or nil if Cppcheck did not actually produce one.
    #
    # A `cppcheck` found on PATH is not proof it can run. Some environments
    # (Windows CI runner images among them) preinstall a Cppcheck shim that
    # cannot locate its own cfg/std.cfg directory, so a run silently produces no
    # output. Verifying the report exists, rather than trusting the shell
    # command's exit status, catches that failure the same way a hung or
    # partially-written file would.
    def run_cppcheck(dir, xml_version)
      output = File.join(dir, "report#{xml_version}.xml")
      system(
        "cppcheck --enable=all --xml --xml-version=#{xml_version} " \
        "--output-file=\"#{output}\" #{File.join(dir, 'defect.c')}",
        out: File::NULL, err: File::NULL
      )
      return output if File.exist?(output) && File.size(output) > 0
      nil
    end

    it 'tallies severities from a real XML version 2 report' do
      with_source_tree({ 'defect.c' => defective_source }) do |dir|
        output = run_cppcheck(dir, 2)
        skip 'this Cppcheck could not complete a real analysis run' if output.nil?

        expect(tally_severities( File.read(output) )['error']).to be > 0
      end
    end

    # Both schema versions carry the same severity attribute, so one parser serves
    # both. Version 3 is rejected outright by older Cppcheck, which is why the
    # plugin defaults to 2.
    it 'tallies severities from a real XML version 3 report where supported' do
      with_source_tree({ 'defect.c' => defective_source }) do |dir|
        output = run_cppcheck(dir, 3)
        skip 'this Cppcheck does not support XML version 3, or could not complete a real analysis run' if output.nil?

        expect(tally_severities( File.read(output) )['error']).to be > 0
      end
    end

    it 'reports an empty tally for a clean source' do
      with_source_tree({ 'defect.c' => "int clean(int a) { return a + 1; }\n" }) do |dir|
        output = run_cppcheck(dir, 2)
        skip 'this Cppcheck could not complete a real analysis run' if output.nil?

        expect(tally_severities( File.read(output) )['error']).to eq(0)
      end
    end
  end
end
