# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'open3'
require 'fileutils'
require 'contract/contract'
require 'contract/directives'
require 'contract/normalizer'
require 'contract/tree_writer'

module Contract

  # Asks the compiler which file each `#include` in a row enters.
  #
  # The row's files are written into a scratch workspace, away from any build. For each
  # pair of includer directory and spelling, a one-line probe file holding just that
  # `#include` is written into the includer's directory and run through `-E -H`, with
  # `-I` in the configured `:paths` order. The first depth-1 `-H` entry is the answer, and
  # "No such file" is `missing`. The quote rule and the angle-bracket skip come from the
  # compiler itself. One probe per directive needs no pairing of `-H` entries with
  # directives, which `#if` blocks would break.
  #
  # A Partials directive names a module, not a file. The compiler expands its macro, as a
  # build does, and the answer is what the expanded module's header, `<dir>/<module>.h`,
  # resolves to from the includer's directory.
  class Oracle

    MISSING      = 'missing'.freeze
    PROBE        = '__contract_probe.c'.freeze
    PARTIAL_HEAD = 'ceedling_partial_'.freeze
    CEEDLING_H   = File.join( CHECKOUT, 'lib', 'ceedling', 'ceedling.h' ).freeze

    # The `:paths` sections that become `-I`, in the order a test's search paths list them
    INCLUDE_SECTIONS = [:test, :support, :include, :libraries].freeze

    attr_reader :cc

    # `project` is the row's whole project configuration, as the build reads it
    def initialize(project:, cc: Contract.cc)
      @project = project
      @cc      = cc
    end

    # The compiler's answer for every directive in `tree`, keyed by Directive#key
    def resolve(tree)
      answers = {}
      Workspace.create do |scratch|
        TreeWriter.write( scratch, tree )
        normalizer = Normalizer.new( scratch )
        includes   = search_order( scratch )

        Directives.scan( tree ).each do |directive|
          answers[directive.key] ||= answer( scratch, normalizer, includes, directive )
        end
      end
      return answers
    end

    # The `-I` directories for a workspace, as the project file spells them, with globs
    # expanded as Ceedling documents them
    def search_order(scratch)
      paths = @project[:paths] || {}
      return INCLUDE_SECTIONS.flat_map { |section| expand( scratch, Array( paths[section] ) ) }.uniq
    end

    # Runs the compiler on one probe file, from the project root. Returns its stderr.
    def run_compiler(scratch, args, probe)
      command = [cc, '-E', '-H', *args, '-o', File::NULL, probe]
      _out, err, _status = Open3.capture3( *command, chdir: scratch.app )
      return err
    end

    private

    def answer(scratch, normalizer, includes, directive)
      return partial_answer( scratch, normalizer, includes, directive ) if directive.partial?

      return probe( scratch, normalizer, includes, directive.includer, directive.spelling, angle: directive.angle )
    end

    def probe(scratch, normalizer, includes, includer, spelling, angle: false)
      includer_dir = File.dirname( scratch.locate( includer ) )
      probe_path   = File.join( includer_dir, PROBE )
      File.write( probe_path, angle ? "#include <#{spelling}>\n" : "#include \"#{spelling}\"\n" )

      begin
        err = run_compiler( scratch, flags( includes ), probe_path )
      ensure
        FileUtils.rm_f( probe_path )
      end

      found = first_entry( err )
      if found.nil?
        return MISSING if err.match?( /No such file|file not found|cannot open/i )

        raise OracleError, "#{cc} gave no -H entry and no missing-file error for #{spelling} from #{includer}:\n#{err}"
      end

      check_angle!( scratch, includes, includer_dir, spelling, found ) if angle
      return normalizer.path( found )
    end

    # The first depth-1 `-H` line names the file the probe's own `#include` entered
    def first_entry(err)
      err.each_line do |line|
        match = line.chomp.match( /\A\. (.+)\z/ )
        return match[1] unless match.nil?
      end
      return nil
    end

    # An angle include never searches its includer's own directory, unless a search path
    # names that directory too. An answer there means the oracle, not the row, is wrong.
    def check_angle!(scratch, includes, includer_dir, spelling, found)
      found_dir = File.dirname( File.expand_path( Normalizer.slashed( Normalizer.unescape_c( found ) ), scratch.app ) )
      return unless same_dir?( found_dir, includer_dir )
      return if includes.any? { |dir| same_dir?( File.expand_path( dir, scratch.app ), includer_dir ) }

      raise OracleError, "the answer for <#{spelling}> lies in its includer's own directory #{includer_dir}, which no search path names"
    end

    def same_dir?(left, right)
      return File.expand_path( left ) == File.expand_path( right )
    end

    def flags(includes)
      return includes.map { |dir| "-I#{dir}" } + defines.map { |define| "-D#{define}" }
    end

    # The row's test defines, which decide what a macro expands to
    def defines
      value = @project.dig( :defines, :test )
      return value.is_a?( Array ) ? value.map( &:to_s ) : []
    end

    def mock_prefix
      return (@project.dig( :cmock, :mock_prefix ) || 'mock_').to_s
    end

    # The module header a Partials macro names, after the compiler expands it
    def partial_answer(scratch, normalizer, includes, directive)
      generated = expand_partial( scratch, directive )
      return MISSING if generated.nil?

      dir    = File.dirname( generated )
      name   = File.basename( generated )
      name   = name.delete_prefix( mock_prefix ) if directive.macro.start_with?( 'MOCK_' )
      module_name = name.delete_prefix( PARTIAL_HEAD ).sub( /_(impl|interface)\.h\z/, '' )
      header = dir == '.' ? "#{module_name}.h" : "#{dir}/#{module_name}.h"

      return probe( scratch, normalizer, includes, directive.includer, header )
    end

    # The filename the macro stringifies to, with the row's defines and the compiler's own
    def expand_partial(scratch, directive)
      probe_path = File.join( scratch.app, PROBE )
      text = "#define CEEDLING_PARTIALS_PREFIX #{PARTIAL_HEAD}\n" \
             "#define CMOCK_MOCK_PREFIX #{mock_prefix}\n" \
             "#include \"#{CEEDLING_H}\"\n" \
             "__contract__ #{directive.macro}(#{directive.args.join( ', ' )})\n"
      File.write( probe_path, text )

      begin
        command = [cc, '-E', '-P', *defines.map { |define| "-D#{define}" }, probe_path]
        out, _err, _status = Open3.capture3( *command, chdir: scratch.app )
      ensure
        FileUtils.rm_f( probe_path )
      end

      match = out.match( /__contract__\s+"([^"]*)"/ )
      return match.nil? ? nil : match[1]
    end

    # Ceedling's glob conventions: `x/**` is x and every directory below it, `x/*` is x
    # and its immediate subdirectories, and a `-:` entry removes what it names
    def expand(scratch, entries)
      paths = []
      entries.each do |entry|
        entry    = scratch.expand( entry.to_s )
        subtract = entry.start_with?( '-:' )
        entry    = entry.sub( /\A[-+]:/, '' )
        found    = expand_one( scratch, entry )

        if subtract
          paths.reject! { |path| found.any? { |gone| path == gone || path.start_with?( "#{gone}/" ) } }
        else
          paths.concat( found )
        end
      end
      return paths.uniq
    end

    def expand_one(scratch, entry)
      if entry.end_with?( '/**', '/*' )
        base    = entry.sub( %r{/\*\*?\z}, '' )
        pattern = entry.end_with?( '/**' ) ? '**/*' : '*'
        below   = Dir.glob( pattern, base: File.expand_path( base, scratch.app ) ).select do |path|
          File.directory?( File.join( File.expand_path( base, scratch.app ), path ) )
        end
        return [base] + below.sort.map { |path| base == '.' ? path : "#{base}/#{path}" }
      end

      if entry.match?( /[*?\[{]/ )
        return Dir.glob( entry, base: scratch.app ).select { |path| File.directory?( File.expand_path( path, scratch.app ) ) }.sort
      end

      return [entry]
    end

  end

end
