# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'contract/contract'
require 'contract/directives'
require 'contract/normalizer'

module Contract

  # Turns what the probe saw in one build, and the build's log, into the normalized
  # report a row's current column records.
  #
  # The sections are `outcome`, `resolved`, `search_paths`, `placements`, `link_set` and
  # `entered`. Every path in them is normalized (see Normalizer), and `entered` keeps
  # each raw spelling beside it.
  class Report

    SECTIONS     = %w[outcome resolved search_paths placements link_set entered].freeze
    STANDIN_MARK = '// Ceedling stand-in header'.freeze
    # A tool's or a test's own error line is preferred to the exception Ceedling raises
    # around it
    COMPILER_ERROR = /\berror:|:FAIL:|undefined reference|multiple definition|Undefined symbols|duplicate symbol/.freeze
    ERROR_LINE     = /\b(error|EXCEPTION|ERROR)\b:|:FAIL:|undefined reference|Undefined symbols/.freeze

    # `probe` is the probe's parsed JSON, nil when the build ended before the probe loaded.
    # `objects` maps each object to its source across a variant's builds, since a later
    # build links objects an earlier one compiled.
    def self.build(probe:, output:, status:, workspace:, tree:, mock_prefix:, objects: {})
      return new( probe, output, status, workspace, tree, mock_prefix, objects ).to_h
    end

    def initialize(probe, output, status, workspace, tree, mock_prefix, objects)
      @probe       = probe || {}
      @output      = output.to_s
      @status      = status
      @workspace   = workspace
      @tree        = tree
      @mock_prefix = mock_prefix
      @objects     = objects
      @norm        = Normalizer.new( workspace )
      @testables   = (Array( @probe['builds'] ).last || {})['testables'] || {}

      Array( @probe['compiles'] ).each { |compile| @objects[norm( compile['object'] )] = norm( compile['source'] ) }
    end

    def to_h
      return {
        'outcome'      => outcome,
        'resolved'     => resolved,
        'search_paths' => search_paths,
        'placements'   => placements,
        'link_set'     => link_set,
        'entered'      => entered
      }
    end

    private

    def norm(path)
      return @norm.path( path )
    end

    def app_file?(path)
      return !path.start_with?( '<', '%', '../' ) && File.file?( File.join( @workspace.app, path ) )
    end

    # ------------------------------------------------------------------------- outcome

    # Pass or fail by exit status, then the first error line and the stage it fell under.
    # `stages` holds each stage heading's progress lines, so a delta build shows which
    # stages did work.
    def outcome
      stages = log_stages
      stage, error = first_error( stages, COMPILER_ERROR ) || first_error( stages, ERROR_LINE ) || [nil, nil]
      error ||= log_lines.find { |text| text.match?( ERROR_LINE ) }

      return {
        'status' => @status.to_i.zero? ? 'pass' : 'fail',
        'stage'  => stage,
        'error'  => error,
        'stages' => stages
      }
    end

    # The first stage heading and line matching `pattern`, nil when none does
    def first_error(stages, pattern)
      stages.each do |heading, lines|
        line = lines.find { |text| text.match?( pattern ) }
        return [heading, line] unless line.nil?
      end
      return nil
    end

    # The log after setup, normalized, without blank lines
    def log_lines
      lines = @output.gsub( "\r\n", "\n" ).lines.map( &:chomp )
      start = lines.index { |line| line.match?( /set up completed/ ) }
      lines = lines[(start + 1)..-1] unless start.nil?
      return lines.map { |line| @norm.text( line ) }
    end

    # Each heading's progress lines. A heading is a line its own width of dashes
    # underlines, or a line ending `...` that stands alone between blank lines. A test
    # summary, which a dashed line opens, and the build failure summary belong to no stage.
    def log_stages
      lines   = log_lines
      stages  = {}
      current = nil

      lines.each_with_index do |line, index|
        following = lines[index + 1]
        previous  = index.zero? ? '' : lines[index - 1]
        dashes    = line.match?( /\A-+\z/ )

        if line.strip == 'BUILD FAILURE SUMMARY' || line.match?( /\ACeedling (operations completed|could not complete)/ )
          current = nil
          next
        end

        underlined = !following.nil? && following.match?( /\A-+\z/ ) && following.length == line.length && !line.strip.empty?
        alone      = previous.strip.empty? && line.end_with?( '...' ) && (following.nil? || following.strip.empty?)

        if (underlined || alone) && !dashes
          current = line.strip
          stages[current] ||= []
          next
        end

        next if dashes && previous.strip == current
        if dashes
          current = nil
          next
        end
        next if current.nil? || line.strip.empty?

        stages[current] << line.strip
      end

      return stages
    end

    # ------------------------------------------------------------------------ resolved

    # What Ceedling believes each of a test file's `#include`s reaches: a mock's header, a
    # Partial's module header and source, a plain header and the sources paired with it
    def resolved
      result = {}
      @testables.each_value do |testable|
        test = testable['filepath'].to_s
        mocks( result, test, testable )
        partials( result, test, testable )
        headers( result, test, testable )
      end
      return result.sort.to_h
    end

    def mocks(result, test, testable)
      (testable['mocks'] || {}).each_value do |mock|
        next if mock['partial']

        result["#{norm( test )} \"#{mock['include_path']}\""] = norm( mock['source'] )
      end
    end

    def test_directives(test)
      text = @tree[norm( test )]
      return text.nil? ? [] : Directives.in_file( norm( test ), text )
    end

    def partials(result, test, testable)
      configs = (testable['partials'] || {})['configs'] || {}
      test_directives( test ).select( &:partial? ).each do |directive|
        config = configs[module_key( directive )] || {}
        header = config.dig( 'header', 'filepath' )
        source = config.dig( 'source', 'filepath' )
        result[directive.key]             = header.nil? ? 'none' : norm( header )
        result["#{directive.key} source"] = source.nil? ? 'none' : norm( source )
      end
    end

    # A Partials directive's module, as Ceedling keys its configuration
    def module_key(directive)
      dir = directive.partial_dir
      return directive.partial_module if dir.nil?

      segments = dir.split( %r{[\\/]} ).reject { |segment| segment.empty? || segment == '.' }
      return File.join( *segments, directive.partial_module )
    end

    # A plain `#include` pairs with the runner's include that names it most closely. Only
    # a runner include naming a project file is a belief, since without test preprocessing
    # an include holds its text as written. The sources paired with it are those the test
    # links that share the header's stem, or the spelling's where no header is believed.
    def headers(result, test, testable)
      pool = Array( testable.dig( 'runner', 'includes' ) ).filter_map do |include|
        next if include['class'] == 'SystemInclude'

        path = norm( include['filepath'] )
        next unless app_file?( path ) && !path.start_with?( 'build/' )

        { 'path' => path, 'spelling' => include['include_path'] || include['filepath'] }
      end

      sources = Array( testable['sources'] ).map { |source| norm( source ) }
      plain   = test_directives( test ).reject { |directive| directive.partial? || directive.framework? || mock?( directive.spelling ) }

      plain.each do |directive|
        found = pick( pool, directive.spelling )
        pool.delete( found ) unless found.nil?
        result[directive.key] = found['path'] unless found.nil?

        stem = File.basename( found.nil? ? directive.spelling : found['path'], '.*' )
        result["#{directive.key} source"] = sources.select { |source| File.basename( source, '.*' ) == stem }
      end
    end

    def mock?(spelling)
      return File.basename( spelling ).start_with?( @mock_prefix )
    end

    def pick(pool, spelling)
      return pool.find { |item| item['spelling'] == spelling } ||
             pool.find { |item| item['path'] == spelling || item['path'].end_with?( "/#{spelling}" ) } ||
             pool.find { |item| File.basename( item['path'] ) == File.basename( spelling ) }
    end

    # -------------------------------------------------------------------- search paths

    def search_paths
      stage5 = @probe['stage5'] || {}
      tests  = {}

      @testables.each do |name, testable|
        snapshot = stage5[name] || {}
        entry = {
          'derived'  => Array( testable['derived_search_paths'] ).map { |path| norm( path ) },
          'refusals' => (testable['search_path_refusals'] || {}).map { |query, why| [query, @norm.text( why.to_s )] }.sort.to_h,
          'test'     => Array( snapshot['search_paths'] ).map { |path| norm( path ) },
          'mocks'    => Array( snapshot['mock_search_paths'] ).map { |path| norm( path ) }
        }
        final = Array( testable['search_paths'] ).map { |path| norm( path ) }
        entry['final'] = final unless final == entry['test']
        tests[name] = entry
      end

      compile = {}
      Array( @probe['compiles'] ).each do |item|
        compile["#{item['module_name']} #{norm( item['source'] )}"] = item['search_paths'].map { |path| norm( path ) }
      end

      link = {}
      Array( @probe['links'] ).each { |item| link[norm( item['executable'] )] = item['libpaths'].map { |path| norm( path ) } }

      return { 'tests' => tests, 'compile' => compile, 'link' => link }
    end

    # ---------------------------------------------------------------------- placements

    # The generated files on disk below each test's generated roots after the build, each
    # object this build compiled, and what this build itself generated
    def placements
      files = { 'mocks' => [], 'standins' => [], 'copies' => [], 'partials' => [], 'runners' => [], 'preprocessed' => [] }
      mock_headers = {}

      @testables.each_value do |testable|
        paths = testable['paths'] || {}

        walk( paths['mocks'] ).each do |path|
          files[mock_kind( path )] << norm( path )
        end
        walk( paths['partials'] ).each { |path| files['partials'] << norm( path ) }
        walk( paths['preprocess_files'] ).each { |path| files['preprocessed'] << norm( path ) }

        runner = testable.dig( 'runner', 'output_filepath' )
        files['runners'] << norm( runner ) if runner && File.file?( File.join( @workspace.app, runner ) )

        (testable['mocks'] || {}).each_value do |mock|
          mock_headers[mock['include_path'].to_s] = @norm.raw( mock['source'] ) unless mock['partial']
        end
      end

      result = files.transform_values { |list| list.uniq.sort }
      result['objects']      = Array( @probe['compiles'] ).map { |item| ["#{item['module_name']} #{norm( item['source'] )}", norm( item['object'] )] }.sort.to_h
      result['mock_headers'] = mock_headers.sort.to_h
      result['isolation']    = isolation
      result['generated']    = {
        'mocks'   => Array( @probe['mocks'] ).map { |mock| norm( mock['header_file'] ) }.uniq.sort,
        'runners' => Array( @probe['runners'] ).map { |runner| norm( runner['runner_file'] ) }.uniq.sort
      }
      return result
    end

    def mock_kind(path)
      head = File.binread( File.join( @workspace.app, path ), STANDIN_MARK.length ).to_s
      return 'standins' if head == STANDIN_MARK
      return 'mocks' if File.basename( path ).start_with?( @mock_prefix )

      return 'copies'
    end

    # Every file below a build directory, relative to the project root
    def walk(dir)
      return [] if dir.nil?

      base = File.join( @workspace.app, dir )
      return [] unless File.directory?( base )

      return Dir.glob( '**/*', base: base ).select { |path| File.file?( File.join( base, path ) ) }.map { |path| File.join( dir, path ) }
    end

    def isolation
      result = {}
      Array( @probe['isolations'] ).each do |item|
        copies = (item['copies'] || {}).map { |original, copy| [norm( original ), norm( copy )] }.sort.to_h
        result[item['test']] = { 'dir' => norm( item['dir'] ), 'copies' => copies }
      end
      return result
    end

    # ------------------------------------------------------------------------ link set

    # Each linked executable's objects, as the sources they were compiled from
    def link_set
      result = {}
      Array( @probe['links'] ).each do |link|
        result[norm( link['executable'] )] = link['objects'].map do |object|
          path = norm( object )
          @objects[path] || path
        end
      end
      return result
    end

    # ------------------------------------------------------------------------- entered

    # The headers each compiled object's `.d` file lists, and the files each test's
    # directives-only preprocessing entered by its line markers, raw beside normalized, with
    # what it found at each mock's path. System headers are left out.
    def entered
      dependencies = {}
      Array( @probe['compiles'] ).each do |compile|
        file = File.join( @workspace.app, compile['dependencies'].to_s )
        next if compile['dependencies'].to_s.empty? || !File.file?( file )

        listed = Normalizer.parse_d( File.binread( file ) ).filter_map { |token| entry( token ) }
        dependencies["#{compile['module_name']} #{norm( compile['source'] )}"] = listed
      end

      markers    = {}
      mocks_read = {}
      @testables.each do |name, testable|
        raw = testable.dig( 'preprocess', 'directives_only', 'filepath' )
        next if raw.nil?

        file = File.join( @workspace.app, raw )
        next unless File.file?( file )

        text = File.binread( file )
        markers[name] = Normalizer.parse_markers( text ).filter_map { |literal| entry( literal, literal: true ) }

        read = mocks_read( text, testable.dig( 'paths', 'mocks' ) )
        mocks_read[name] = read unless read.empty?
      end

      return { 'dependencies' => dependencies, 'markers' => markers, 'mocks_read' => mocks_read }
    end

    # What the test's directives-only preprocessing found at each mock's path, `mock` for
    # a generated mock and `stand-in` for anything else. The output keeps every #define, so
    # a generated mock shows its own include guard, named from its filename as CMock names it.
    def mocks_read(text, mocks_root)
      return {} if mocks_root.nil?

      root    = norm( mocks_root )
      current = nil
      found   = {}

      text.each_line do |line|
        literal = Normalizer.parse_markers( line ).first
        unless literal.nil?
          current = norm( Normalizer.unescape_c( literal ) )
          found[current] ||= 'stand-in' if current.start_with?( "#{root}/" )
          next
        end

        next if current.nil? || !found.key?( current )

        guard = "_#{File.basename( current, '.*' ).upcase}_H"
        found[current] = 'mock' if line.match?( /\A#\s*define\s+#{Regexp.escape( guard )}\b/ )
      end

      return found.select { |path, _| File.basename( path ).start_with?( @mock_prefix ) }.sort.to_h
    end

    def entry(token, literal: false)
      path = norm( literal ? Normalizer.unescape_c( token ) : token )
      return nil if path == Normalizer::SYSTEM

      return { 'raw' => @norm.raw( token ), 'path' => path }
    end

  end

end
