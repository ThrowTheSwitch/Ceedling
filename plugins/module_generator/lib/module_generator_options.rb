# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# The options Unity's module generator and CMock's skeleton generator need for one
# module request, built from the project configuration.
#
# Paths come from the project's :paths collections. Without a hint, each kind of file
# goes to its configured :path_src, :path_inc, or :path_tst, else the first path of its
# collection. With a hint, each goes to the path the hint matches best in its own
# collection, or to that collection's first path when the hint matches nothing there.
# A hint that matches nothing in any collection is a mistake and stops the task.
# Without include paths, headers go where the source goes.
class ModuleGeneratorOptions

  # The :naming values Unity's module generator accepts, passed to it as given
  NAMING = %w[bumpy camel snake caps].freeze

  KINDS = %i[src inc tst].freeze

  TEST_GUARDS = %w[ifdef if].freeze

  attr_reader :test_guard

  # `path_finder` returns the path in a list a hint matches best, or nil for no match.
  # `boilerplate_reader` returns a file's contents, or nil when it does not exist.
  def initialize(config:, cmock_config:, path_finder:, boilerplate_reader:)
    @config       = config
    @cmock_config = cmock_config
    @path_finder  = path_finder
    @naming       = naming( config[:module_generator_naming] )
    @test_guard   = guard_style( config[:module_generator_test_guard] )
    @boilerplates = boilerplates( boilerplate_reader )
    @collections  = collections
    @shared       = shared_options
  end

  def unity(request)
    src, inc, tst = paths( request.path_hint )
    return @shared.merge( pattern: request.pattern, path_src: src, path_inc: inc, path_tst: tst )
  end

  # The header to read and the CMock options that write its skeleton beside the source.
  # A subdirectory the name carries applies to both.
  def stub(request)
    src, inc, = paths( request.path_hint )
    subdir    = File.dirname( request.name ).then { |dir| dir == '.' ? nil : dir }

    return {
      header: File.join( inc, "#{request.name}.h" ),
      cmock:  @cmock_config.merge( skeleton_path: src, subdir: subdir )
    }
  end

  # The header to parse, the test file to write, and what goes into it. A subdirectory
  # the name carries applies to both paths.
  def test(request)
    _, inc, tst = paths( request.path_hint )
    module_name = File.basename( request.name )
    subdir      = File.dirname( request.name )

    return {
      header: File.join( inc, "#{request.name}.h" ),
      path:   File.join( [tst, (subdir unless subdir == '.'), "#{@shared[:test_prefix]}#{module_name}.c"].compact ),
      cmock:  @cmock_config,
      file:   { module_name: module_name, header: "#{module_name}.h", includes: @shared[:includes][:tst],
                boilerplate: @boilerplates[:tst], test_define: test_define, test_guard: @test_guard }
    }
  end

  def test_define = @shared[:test_define]

  private

  def naming(value)
    return nil if value.nil?

    str = value.to_s
    return str if NAMING.include?( str )

    raise CeedlingException.new( "Module Generator :naming `#{value}` is not one of #{NAMING.map { |key| ":#{key}" }.join( ', ' )}." )
  end

  def guard_style(value)
    guard = (value || :ifdef).to_s
    return guard if TEST_GUARDS.include?( guard )

    raise CeedlingException.new( "Module Generator :test_guard `#{value}` is not one of #{TEST_GUARDS.map { |key| ":#{key}" }.join( ', ' )}." )
  end

  # Configured boilerplates, each replaced by the contents of a configured boilerplate file
  def boilerplates(reader)
    files = @config[:module_generator_boilerplate_files] || {}

    return KINDS.to_h do |kind|
      path = files[kind]
      next [kind, (@config[:module_generator_boilerplates] || {})[kind]] if path.nil?

      contents = reader.call( path )
      raise CeedlingException.new( "Module Generator boilerplate file `#{path}` does not exist." ) if contents.nil?

      [kind, contents]
    end
  end

  def collections
    source = @config[:collection_paths_source] || []
    return {
      src: source,
      inc: (@config[:collection_paths_include] || []).then { |include| include.empty? ? source : include },
      tst: @config[:collection_paths_test] || []
    }
  end

  # Unity options every request shares. Unity's own Subversion support stays off.
  def shared_options
    return {
      test_prefix:  @config[:project_test_file_prefix],
      mock_prefix:  @config[:cmock_mock_prefix] || 'Mock',
      includes:     KINDS.to_h { |kind| [kind, Array( (@config[:module_generator_includes] || {})[kind] )] },
      boilerplates: @boilerplates,
      naming:       @naming,
      update_svn:   false,
      test_define:  @config[:module_generator_test_define] || 'TEST',
      test_guard:   @test_guard
    }
  end

  # Source, include, and test paths for a hint, or the configured defaults without one
  def paths(hint)
    return KINDS.map { |kind| @config[:"module_generator_path_#{kind}"] || @collections[kind].first } if hint.nil?

    return matched_paths( hint )
  end

  def matched_paths(hint)
    matches = KINDS.map { |kind| @path_finder.call( hint, @collections[kind] ) }
    if matches.none?
      raise CeedlingException.new( "Module path hint `#{hint}` matches no source, include, or test path in the project's :paths." )
    end

    return KINDS.zip( matches ).map { |kind, match| match || @collections[kind].first }
  end

end
