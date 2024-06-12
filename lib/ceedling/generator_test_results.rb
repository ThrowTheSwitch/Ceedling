# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for .ext()
require 'ceedling/constants'
require 'ceedling/exceptions'

class GeneratorTestResults

  constructor :configurator, :generator_test_results_sanity_checker, :yaml_wrapper

  def setup()
    # Aliases
    @sanity_checker = @generator_test_results_sanity_checker
  end

  def process_and_write_results(executable, unity_shell_result, results_file, test_file)
    output_file = results_file

    results = get_results_structure

    results[:source][:dirname] = File.dirname(test_file)
    results[:source][:basename] = File.basename(test_file)
    results[:source][:file] = test_file
    results[:time] = unity_shell_result[:time] unless unity_shell_result[:time].nil?

    # Process test statistics
    if (unity_shell_result[:output] =~ TEST_STDOUT_STATISTICS_PATTERN)
      results[:counts][:total] =   $1.to_i
      results[:counts][:failed] =  $2.to_i
      results[:counts][:ignored] = $3.to_i
      results[:counts][:passed] = (results[:counts][:total] - results[:counts][:failed] - results[:counts][:ignored])
    else
      raise CeedlingException.new( "Could not parse output for `#{executable}`: \"#{unity_shell_result[:output]}\"" ) 
    end

    # Remove test statistics lines
    output_string = unity_shell_result[:output].sub(TEST_STDOUT_STATISTICS_PATTERN, '')
    output_string.lines do |line|
      # Process Unity output
      case line.chomp
      when /(:IGNORE)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:ignores] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:PASS$)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:PASS \(.* ms\)$)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:FAIL)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:failures] << elements[0]
        results[:stdout] << elements[1] if (!elements[1].nil?)
      else # Collect up all other output
        results[:stdout] << line.chomp
      end
    end

    @sanity_checker.verify( results, unity_shell_result[:exit_code] )

    output_file = results_file.ext(@configurator.extension_testfail) if (results[:counts][:failed] > 0)

    @yaml_wrapper.dump(output_file, results)

    return { :result_file => output_file, :result => results }
  end

  # TODO: Filter test cases with command line test case matchers
  def create_crash_failure(source, shell_result, test_cases)
    count = test_cases.size()

    output = []
    test_cases.each do |test_case|
      output << "#{source}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test executable crashed"
    end

    shell_result[:output] = 
      regenerate_test_executable_stdout(
        total:   count,
        failed:  count,
        ignored: 0,
        output:  output
      )

    shell_result[:exit_code] = count

    return shell_result
  end

  def regenerate_test_executable_stdout(total:, failed:, ignored:, output:[])
    values = {
      :total => total,
      :failed => failed,
      :ignored => ignored,
      :output => output.map {|line| line.strip()}.join("\n"),
      :result => (failed > 0) ? 'FAIL' : 'OK'
    }

    return UNITY_TEST_RESULTS_TEMPLATE % values
  end

  ### Private ### 
  
  private

  def get_results_structure
    return {
      :source    => {:file => '', :dirname => '', :basename => '' },
      :successes => [],
      :failures  => [],
      :ignores   => [],
      :counts    => {:total => 0, :passed => 0, :failed => 0, :ignored  => 0},
      :stdout    => [],
      :time      => 0.0
      }
  end

  def extract_line_elements(executable, line, filename)
    # Handle anything preceding filename in line as extra output to be collected
    stdout = nil
    stdout_regex = /(.+)#{Regexp.escape(filename)}:[0-9]+:(PASS|IGNORE|FAIL).+/i
    unity_test_time = 0 

    if (line =~ stdout_regex)
      stdout = $1.clone
      line.sub!(/#{Regexp.escape(stdout)}/, '')
    end

    # Collect up test results minus any extra output
    elements = (line.strip.split(':'))[1..-1]

    # Find timestamp if available
    if (elements[-1] =~ / \((\d*(?:\.\d*)?) ms\)/)
      unity_test_time = $1.to_f / 1000
      elements[-1].sub!(/ \((\d*(?:\.\d*)?) ms\)/, '')
    end

    if elements[3..-1]
      message = (elements[3..-1].join(':')).strip
    else
      message = nil
    end

    components = {
      :test => elements[1],
      :line => elements[0].to_i,
      # Decode any multline strings
      :message => message.nil? ? nil : message.gsub( '\n', "\n" ),
      :unity_test_time => unity_test_time
    }

    return components, stdout if elements.size >= 3
    
    # Fall through failure case
    raise CeedlingException.new( "Could not parse results output line \"line\" for `#{executable}`" )
  end

end
