# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Drives Partial generation directly and compiles the result, skipping the test build.
#
# A full `ceedling test:` run costs seconds per case and buries the generated files under
# mock generation, runner generation, linking, and execution. None of that bears on how a
# Partial's content is composed. This harness runs the real components that do, then hands
# the output to a real compiler.
#
# Preprocessing is part of what it runs, and that matters more than it looks. Partials never
# sees a module's original text. `Partializer#extract_module_contents` calls
# `CExtractor#from_file` against what `Preprocessinator#preprocess_partial_*_preserve_macros`
# reconstituted, so conditionals are already resolved, comments are gone, every line
# belonging to an included header has been discarded, and the file has been rebuilt from the
# survivors plus a reconciled include list. A harness fed original source would report
# defects that preprocessing already prevents.
#
# `mode:` selects which preprocessing path runs, and it is always a caller's choice rather
# than something inferred from the toolchain. Fallback is a real production path -- it is
# what runs wherever `-fdirectives-only` is unavailable -- and it resolves strictly less than
# the accurate path does, so it needs coverage everywhere rather than only where a weak
# toolchain happens to force it.
#
# Real objects throughout, with doubles only where a collaborator is consulted for
# configuration rather than behavior. The extractor construction mirrors
# c_extractor_composition_spec.rb, which already proves that wiring.
#
# Includes are supplied by the caller. They stand in for the reconciled list the preprocessor
# stage produces, which in production reaches the generators as
# `config.source.includes + config.header.includes`. Stating them per case is also what makes
# include ordering testable.

require 'fileutils'
require 'tmpdir'
require 'open3'

require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_functions'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/c_extractor/c_extractor_definitions'
require 'ceedling/generators/generator_partials'
require 'ceedling/partials/partializer'
require 'ceedling/preprocess/preprocessinator_reconstructor'
require 'ceedling/preprocess/preprocessinator_comment_stripper'
require 'ceedling/preprocess/c_comment_scanner'
require 'ceedling/preprocess/preprocessinator_file_assembler'
require 'ceedling/parsing_parcels'
require 'ceedling/file_path_utils'
require 'ceedling/file_wrapper'
require 'ceedling/includes/includes'


# Structs and errors the harness hands back, namespaced so they do not collide with the
# production types they stand next to.
module PartialsGeneration

  # What a case gets back. `types_h` is nil when the module defines no types, matching
  # GeneratorPartials#generate_types returning nil for that case. `pp_header` and `pp_source`
  # are the reconstituted files the extractor actually parsed, which is where to look when a
  # generated file is missing something the original module had.
  Result = Struct.new(
    :dir, :module_name, :mode,
    :types_h, :impl_h, :impl_c, :interface_h,
    :header_include_list, :source_include_list, :interface_include_list,
    :pp_header, :pp_source,
    keyword_init: true
  ) do
    # Include directives in emitted order, as a plain Array of String.
    def impl_h_includes
      impl_h.to_s.lines.grep(/^\s*#include/).map( &:strip )
    end

    def types_h_includes
      types_h.to_s.lines.grep(/^\s*#include/).map( &:strip )
    end

    # Position of an include within the implementation header, or nil when absent.
    def impl_h_index(fragment)
      impl_h_includes.index { |line| line.include?( fragment ) }
    end
  end

  # A compile or link attempt. `ok` is the only thing most cases assert; `stderr` explains a
  # failure without the case having to parse it.
  Compilation = Struct.new( :ok, :stderr, :command, keyword_init: true ) do
    def first_error
      stderr.to_s.lines.find { |line| line =~ /error:/ }&.strip
    end

    # A linker diagnostic carries no "error:" prefix, so cases asserting a link failure
    # match on the message itself.
    def first_diagnostic
      stderr.to_s.lines.reject { |line| line.strip.empty? }.first&.strip
    end
  end

  # Raised when the accurate preprocessing pass fails outright. Production falls back to a
  # text scan here; a case that cannot preprocess is a broken case, so the harness refuses
  # rather than silently measuring a different path than the one asked for.
  class PreprocessFailure < StandardError; end

end


module PartialsGenerationHelpers

  # Generates a Partial from in-memory C and returns the generated files' contents.
  #
  # `header_includes` and `source_includes` are include spellings; `<name>` marks a system
  # header and anything else a user header, matching what reconciliation hands the assembler.
  # `extra` writes additional headers into the working directory, where the preprocessor and
  # the later compile resolve them. `partials` defaults to empty: this module is partialized,
  # which the remap methods handle from `name:` alone. The hash names *other* partialized
  # modules, whose includes get removed or redirected.
  def generate_partial(
      module_name:,
      header: '',
      source: '',
      header_includes: [],
      source_includes: [],
      extra: {},
      partials: {},
      defines: [],
      mode: :accurate
    )
    dir = Dir.mktmpdir( 'partials-generation-' )

    File.write( File.join( dir, "#{module_name}.h" ), header )
    File.write( File.join( dir, "#{module_name}.c" ), source )
    extra.each { |name, text| File.write( File.join( dir, name ), text ) }

    pp_header = reconstitute_partial_file(
      dir: dir, filename: "#{module_name}.h", kind: :header,
      includes: header_includes, defines: defines, mode: mode
    )
    pp_source = reconstitute_partial_file(
      dir: dir, filename: "#{module_name}.c", kind: :source,
      includes: source_includes, defines: defines, mode: mode
    )

    c_module = extract_c( pp_header ) + extract_c( pp_source )

    generator   = build_partials_generator
    partializer = build_partializer

    # Generated-file boilerplate carried in from the reconstituted files is stripped before
    # generation, exactly as PartialsManager#stage_generate_partials does. Skipping this
    # leaves synthetic include guards in the extracted macros and misreports what a real
    # build would emit.
    partializer.sanitize( c_module )

    # Header list first, then source list -- the order partials_manager uses when it
    # concatenates the two before remapping.
    raw_includes = partial_include_objects( source_includes + header_includes )

    types_h_name = generator.generate_types(
      name: module_name, c_module: c_module, output_path: dir
    )

    header_list = partializer.remap_implementation_header_includes(
      name: module_name, includes: raw_includes, partials: partials,
      types_header: types_h_name
    )

    source_list = partializer.remap_implementation_source_includes(
      name: module_name, includes: raw_includes, partials: partials
    )

    interface_list = partializer.remap_interface_header_includes(
      name: module_name, includes: raw_includes, partials: partials,
      types_header: types_h_name
    )

    generator.generate_implementation(
      test: 'PartialsGenerationTest',
      name: module_name,
      function_definitions: [],
      source_includes: source_list,
      header_includes: header_list,
      c_module: c_module,
      output_path: dir
    )

    # The mockable interface header is what CMock mocks in place of the real module header,
    # and it carries the same types header the implementation header does. Both land in one
    # translation unit when a module is tested and mocked in the same test file.
    generator.generate_interface(
      test: 'PartialsGenerationTest',
      name: module_name,
      function_declarations: [],
      includes: interface_list,
      c_module: c_module,
      output_path: dir
    )

    PartialsGeneration::Result.new(
      dir: dir,
      module_name: module_name,
      mode: mode,
      types_h: read_generated( dir, types_h_name ),
      impl_h: read_generated( dir, "ceedling_partial_#{module_name}_impl.h" ),
      impl_c: read_generated( dir, "ceedling_partial_#{module_name}_impl.c" ),
      interface_h: read_generated( dir, "ceedling_partial_#{module_name}_interface.h" ),
      header_include_list: header_list.map( &:to_s ),
      source_include_list: source_list.map( &:to_s ),
      interface_include_list: interface_list.map( &:to_s ),
      pp_header: pp_header,
      pp_source: pp_source
    )
  end

  # Reproduces what Preprocessinator#preprocess_partial_{header,source}_file_preserve_macros
  # leaves on disk for the extractor to read, in the same steps and with the same
  # collaborators.
  #
  # The accurate path runs real GCC, which resolves every conditional and follows every
  # include while leaving macro directives as written. The fallback path never runs a
  # compiler: it scans the file's own text, tracking conditionals approximately, which is
  # why it resolves less and why Partials needs to refuse some shapes outright under it.
  def reconstitute_partial_file(dir:, filename:, kind:, includes:, defines: [], mode: :accurate)
    path = File.join( dir, filename )

    contents, extras =
      case mode
      when :accurate then reconstitute_accurate( dir: dir, path: path )
      when :fallback then reconstitute_fallback( path: path, defines: defines )
      else raise ArgumentError, "unknown preprocessing mode '#{mode}'"
      end

    assembled = File.join( dir, "preprocessed_#{filename}" )
    include_list = partial_include_objects( includes )

    if kind == :header
      partials_file_assembler.assemble_preprocessed_header_file(
        filepath: filename, preprocessed_filepath: assembled,
        contents: contents, extras: extras, includes: include_list
      )
    else
      partials_file_assembler.assemble_preprocessed_code_file(
        filename: filename, preprocessed_filepath: assembled,
        contents: contents, extras: extras, includes: include_list
      )
    end

    File.read( assembled, encoding: 'UTF-8' )
  end

  # Only lines belonging to this file survive the reconstructor; a type arriving from an
  # included header is discarded here, which is why an extracted type can reference
  # something no generated file declares.
  def reconstitute_accurate(dir:, path:)
    raw = "#{path}.directives_only"

    command = "#{partials_compiler} -E -fdirectives-only -I#{dir} -x c #{path} -o #{raw}"
    _out, stderr, status = Open3.capture3( command )
    raise PartialsGeneration::PreprocessFailure, "#{command}\n#{stderr}" unless status.success?

    partials_comment_stripper.strip_file( raw )

    contents = File.open( raw, 'rb' ) do |file|
      partials_reconstructor.extract_file_as_array_from_expansion( file, path )
    end

    [contents, []]
  end

  # Fallback strips every directive line out of the content, so the macros and pragmas the
  # extractor still needs are recovered separately and reinserted as assembler extras. That
  # second pass is what keeps a type's array-size macro visible when no compiler ran.
  def reconstitute_fallback(path:, defines: [])
    contents = partials_file_assembler.collect_file_contents_fallback(
      source_filepath: path, defines: defines
    )
    extras = partials_file_assembler.collect_macros_and_pragmas_fallback(
      source_filepath: path, defines: defines
    )

    [contents, extras]
  end

  # ---- compilation -------------------------------------------------------------

  # Compiles a translation unit that includes the generated implementation header, the way a
  # generated test runner would. Syntax-only: this probes declarations and ordering, not code
  # generation.
  def compile_partial(result, prelude: '')
    probe = File.join( result.dir, 'probe_impl.c' )
    File.write( probe, "#{prelude}#include \"ceedling_partial_#{result.module_name}_impl.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  # Compiles the types header entirely on its own, which is the question of whether that
  # header is self-contained. Nothing else is included first.
  def compile_types_header_alone(result)
    probe = File.join( result.dir, 'probe_types_alone.c' )
    File.write( probe, "#include \"ceedling_partial_#{result.module_name}_types.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  # The mockable interface header standing alone, the same question asked of the file CMock
  # consumes.
  def compile_interface_header_alone(result)
    probe = File.join( result.dir, 'probe_interface_alone.c' )
    File.write( probe, "#include \"ceedling_partial_#{result.module_name}_interface.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  def syntax_only(result, probe)
    command = "#{partials_compiler} -fsyntax-only -I#{result.dir} #{probe}"
    _out, stderr, status = Open3.capture3( command )

    PartialsGeneration::Compilation.new( ok: status.success?, stderr: stderr, command: command )
  end

  def cleanup_partial(result)
    FileUtils.rm_rf( result.dir ) if result&.dir
  end

  def partials_compiler
    ENV.fetch( 'PARTIALS_GENERATION_CC', 'gcc' )
  end

  # ---- construction -------------------------------------------------------------

  # `<name>` is a system header, everything else a user header -- the distinction
  # reconciliation draws, and the one that decides how each renders.
  def partial_include_objects(names)
    names.map do |name|
      if name.start_with?( '<' ) && name.end_with?( '>' )
        SystemInclude.new( name[1..-2] )
      else
        UserInclude.new( name )
      end
    end
  end

  def extract_c(content)
    code_text     = CExtractorCodeText.new
    declarations  = CExtractorDeclarations.new({ c_extractor_code_text: code_text })
    functions     = CExtractorFunctions.new({ c_extractor_code_text: code_text })
    preprocessing = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
    definitions   = CExtractorDefinitions.new({ c_extractor_code_text: code_text })
    declarations.setup()
    functions.setup()

    extractor = CExtractor.new(
      {
        c_extractor_code_text:     code_text,
        c_extractor_functions:     functions,
        c_extractor_declarations:  declarations,
        c_extractor_preprocessing: preprocessing,
        c_extractor_definitions:   definitions,
        # Bare double so #respond_to? is false and CExtractor uses its own default buffer
        # length, as c_extractor_composition_spec.rb does.
        configurator:              RSpec::Mocks::Double.new( 'Configurator' ),
        loginator:                 RSpec::Mocks::Double.new( 'Loginator' ).as_null_object,
        file_wrapper:              RSpec::Mocks::Double.new( 'FileWrapper' ).as_null_object
      }
    )
    extractor.setup()
    extractor.from_string( content: content )
  end

  def build_partials_generator
    GeneratorPartials.new(
      {
        file_wrapper:    partials_file_wrapper,
        file_path_utils: partials_file_path_utils,
        loginator:       partials_null_loginator
      }
    )
  end

  # Only the include-remapping methods and #sanitize are exercised, so every collaborator
  # except file_path_utils and loginator is a null double.
  def build_partializer
    Partializer.new(
      {
        configurator:       RSpec::Mocks::Double.new( 'Configurator' ).as_null_object,
        partializer_helper: RSpec::Mocks::Double.new( 'Helper' ).as_null_object,
        file_finder:        RSpec::Mocks::Double.new( 'FileFinder' ).as_null_object,
        c_extractor:        RSpec::Mocks::Double.new( 'CExtractor' ).as_null_object,
        file_path_utils:    partials_file_path_utils,
        reportinator:       RSpec::Mocks::Double.new( 'Reportinator' ).as_null_object,
        loginator:          partials_null_loginator
      }
    )
  end

  def partials_reconstructor
    PreprocessinatorReconstructor.new(
      { parsing_parcels: ParsingParcels.new, file_wrapper: partials_file_wrapper }
    )
  end

  def partials_comment_stripper
    PreprocessinatorCommentStripper.new(
      { c_comment_scanner: CCommentScanner.new, file_wrapper: partials_file_wrapper }
    )
  end

  # Of the eight collaborators, the assemble and fallback-collect methods used here consult
  # only the reconstructor, the file wrapper, and parsing parcels; the rest serve collection
  # methods the harness drives itself.
  def partials_file_assembler
    PreprocessinatorFileAssembler.new(
      {
        preprocessinator_reconstructor: partials_reconstructor,
        configurator:                   RSpec::Mocks::Double.new( 'Configurator' ).as_null_object,
        tool_executor:                  RSpec::Mocks::Double.new( 'ToolExecutor' ).as_null_object,
        file_path_utils:                partials_file_path_utils,
        file_wrapper:                   partials_file_wrapper,
        parsing_parcels:                ParsingParcels.new,
        loginator:                      partials_null_loginator,
        reportinator:                   RSpec::Mocks::Double.new( 'Reportinator' ).as_null_object
      }
    )
  end

  def partials_file_wrapper
    FileWrapper.new( loginator: partials_null_loginator, verbosinator: partials_null_verbosinator )
  end

  def partials_file_path_utils
    FilePathUtils.new(
      configurator: RSpec::Mocks::Double.new( 'Configurator' ).as_null_object,
      file_wrapper: partials_file_wrapper
    )
  end

  def partials_null_loginator
    RSpec::Mocks::Double.new( 'Loginator' ).as_null_object
  end

  def partials_null_verbosinator
    RSpec::Mocks::Double.new( 'Verbosinator' ).as_null_object
  end

  def read_generated(dir, name)
    return nil if name.nil?

    path = File.join( dir, name )
    File.exist?( path ) ? File.read( path, encoding: 'UTF-8' ) : nil
  end

end


RSpec.configure do |config|
  config.include PartialsGenerationHelpers
end
