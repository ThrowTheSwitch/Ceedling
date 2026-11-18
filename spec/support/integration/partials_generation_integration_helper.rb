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
# `CExtractor#from_file` against what `Preprocessinator#preprocess_partial_file`
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
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partializer_reconciler'
require 'ceedling/partials/partializer_utils'
require 'ceedling/partials/partializer_config'
require 'ceedling/partials/partials'
require 'ceedling/preprocess/preprocessinator_reconstructor'
require 'ceedling/preprocess/preprocessinator_comment_stripper'
require 'ceedling/preprocess/c_comment_scanner'
require 'ceedling/preprocess/preprocessinator_file_assembler'
require 'ceedling/preprocess/preprocessinator_code_finder'
require 'ceedling/parsing_parcels'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/includes/includes'


# Structs and errors the harness hands back, namespaced so they do not collide with the
# production types they stand next to.
module PartialsGeneration

  # What a case gets back. `types_h` is nil when the module defines no types, matching
  # GeneratorPartials#generate_types returning nil for that case. `pp_header` and `pp_source`
  # are the reconstituted files the extractor actually parsed, which is where to look when a
  # generated file is missing something the original module had.
  # `carry` is the plan the implementation source was written from, or nil when nothing
  # was selected to test.
  Result = Struct.new(
    :dir, :module_name, :mode,
    :types_h, :impl_h, :impl_c, :interface_h, :extras_h,
    :pp_header, :pp_source, :carry,
    keyword_init: true
  ) do
    # Generated file contents by role, so the accessors below read one way for any of them.
    # A case naming a file Partials did not generate gets nil rather than a confusing empty
    # result -- that distinction is itself worth asserting.
    def content(file)
      case file
      when :types_h     then types_h
      when :impl_h      then impl_h
      when :impl_c      then impl_c
      when :interface_h then interface_h
      when :extras_h    then extras_h
      else raise ArgumentError, "unknown generated file '#{file}'"
      end
    end

    # Include directives in emitted order, as a plain Array of String. Absence assertions
    # need the same shape presence assertions use, so every accessor here returns a flat
    # Array a case can match with `include` / `not_to include`.
    def includes(file)
      content( file ).to_s.lines.grep(/^\s*#include/).map( &:strip )
    end

    # Macro names defined in a generated file, without their values. A case asserting a
    # guard-spoof cares that the name is defined, not what it expands to.
    def defines(file)
      content( file ).to_s.lines.filter_map do |line|
        match = line.match(/^\s*#\s*define\s+([A-Za-z_]\w*)/)
        match && match[1]
      end
    end

    # Names a generated file establishes as types -- typedef names and aggregate tags.
    # Catches a type emitted twice or emitted into the wrong file, neither of which an
    # include-list assertion sees.
    def type_names(file)
      text = content( file ).to_s
      typedef_names( text ) + text.scan(/\b(?:struct|union|enum)\s+([A-Za-z_]\w*)\s*\{/).flatten
    end

    # Declarator name of every typedef in the text. A fixture-grade extractor, not a C
    # parser: it tracks brace depth so an aggregate body's own semicolons cannot end the
    # statement early, then reads the name off the declarator.
    def typedef_names(text)
      text.to_enum( :scan, /\btypedef\b/ ).map do
        statement = typedef_statement( text, Regexp.last_match.end( 0 ) )
        declarator_name( statement )
      end.compact
    end

    # Text between `typedef` and its terminating semicolon at brace depth zero.
    def typedef_statement(text, from)
      depth = 0
      index = from

      while index < text.length
        case text[index]
        when '{' then depth += 1
        when '}' then depth -= 1
        when ';' then break if depth.zero?
        end
        index += 1
      end

      text[from...index].to_s
    end

    # A function-pointer typedef carries its name inside `(* … )`, so that shape is read
    # first. Otherwise the name is the last identifier once array dimensions are removed.
    def declarator_name(statement)
      pointer = statement.match(/\(\s*\*+\s*([A-Za-z_]\w*)\s*\)/)
      return pointer[1] if pointer

      statement.gsub(/\[[^\]]*\]/, ' ').scan(/[A-Za-z_]\w*/).last
    end

    # Position of an include within a generated file, or nil when absent. Ordering is only
    # meaningful against another position, so cases compare two of these rather than
    # asserting an absolute index.
    def include_index(file, fragment)
      includes( file ).index { |line| line.include?( fragment ) }
    end

    # Position of a #define among the emitted lines of a generated file. Measured in source
    # lines rather than among the defines alone, so it is directly comparable with
    # line_index below and therefore with an include's own line.
    def define_index(file, macro)
      line_index( file, /^\s*#\s*define\s+#{Regexp.escape( macro )}\b/ )
    end

    # Position of the first line matching a pattern, or nil. The common currency for every
    # ordering assertion that spans two kinds of content -- a #define against an #include,
    # say, which cannot be compared within either one's own list.
    def line_index(file, pattern)
      content( file ).to_s.lines.index { |line| line.match?( pattern ) }
    end

    # Named conveniences for the three files cases reach for most.
    def impl_h_includes      = includes( :impl_h )
    def types_h_includes     = includes( :types_h )
    def interface_h_includes = includes( :interface_h )

    def impl_h_index(fragment)      = include_index( :impl_h, fragment )
    def interface_h_index(fragment) = include_index( :interface_h, fragment )
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

  # Raised when a preprocessor run fails outright. Production falls back for that file. A
  # case that cannot preprocess is a broken case, so the harness refuses rather than silently
  # measuring a different path than the one asked for.
  class PreprocessFailure < StandardError; end

end


module PartialsGenerationHelpers

  # Generates a Partial from in-memory C and returns the generated files' contents.
  #
  # `header_includes` and `source_includes` are include spellings; `<name>` marks a system
  # header and anything else a user header, matching what reconciliation hands the assembler.
  # `source: nil` makes a header-only module, which has no source to write or preprocess.
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
      mode: :accurate,
      tests_expose: PartializerConfig::DEDUCT,
      mocks_expose: PartializerConfig::DEDUCT,
      tests_subtract: [],
      mocks_add: [],
      mocks_subtract: [],
      suppress_redundant_decls: true,
      extern_variables: :weak,
      dir: nil
    )
    # A caller supplies `dir` to generate two modules into one working directory, which is
    # what a link across two partialized modules needs.
    dir ||= Dir.mktmpdir( 'partials-generation-' )

    # Byte for byte, so a module's line endings are the same on every platform
    File.binwrite( File.join( dir, "#{module_name}.h" ), header )
    File.binwrite( File.join( dir, "#{module_name}.c" ), source ) unless source.nil?
    extra.each { |name, text| File.binwrite( File.join( dir, name ), text ) }

    # Each file is preprocessed as stages 6 and 7 preprocess it, into the record they fill in
    header_file = preprocess_partial_file(
      dir: dir, filename: "#{module_name}.h", kind: :header, includes: header_includes, defines: defines, mode: mode
    )
    # A header-only module's source keeps the empty record PartialsManager leaves it
    source_file =
      if source.nil?
        Partials::ConfigFileInfo.new
      else
        preprocess_partial_file(
          dir: dir, filename: "#{module_name}.c", kind: :source, includes: source_includes, defines: defines, mode: mode
        )
      end

    # DEDUCT with no subtractions is what TEST_PARTIAL_ALL_MODULE resolves to -- every function
    # exposed. The two sides are separate because a module is routinely tested at one visibility
    # and mocked at another, which splits its own content across two generated files. Visibility
    # filtering has its own thorough unit coverage, so a case states the exposure it wants rather
    # than re-proving the filter.
    config = PartializerConfig::Config.new(
      module: module_name,
      tests: PartializerConfig::PartialFunctions.new( type: tests_expose, subtractions: tests_subtract ),
      mocks: PartializerConfig::PartialFunctions.new( type: mocks_expose, additions: mocks_add, subtractions: mocks_subtract ),
      header: header_file,
      source: source_file
    )

    generator   = build_partials_generator
    partializer = build_partializer

    # Extraction runs as PartialsManager runs it. Each file is extracted, reconciled with its
    # expansion, located in its raw copy or in fallback its source, and has its function-scope
    # statics promoted. The two merge, and declarations an included header defines inline are
    # marked.
    c_module = partializer.extract_module_contents( 'PartialsGenerationTest', config )

    # Partials refuses a module whose shape fallback preprocessing cannot resolve, rather than
    # generating from a guess and leaving a compiler to report something arcane later. The
    # refusal comes right after extraction, before generation, as in PartialsManager.
    partializer.validate_config( c_module: c_module, config: config, name: 'PartialsGenerationTest' )

    # Generated-file boilerplate carried in from the reconstituted files is stripped before
    # generation, exactly as PartialsManager#stage_generate_partials does. Skipping this
    # leaves synthetic include guards in the extracted macros and misreports what a real
    # build would emit. The real header's own guard goes too, since every generated file states it.
    partializer.sanitize( c_module, include_guard: partializer.extract_module_include_guard( config.header.filepath ) )

    # The header remaps take the source's and the header's lists apart, as partials_manager
    # hands them. The implementation source's remap takes them joined, source first.
    source_objects = source_file.includes
    header_objects = header_file.includes
    raw_includes   = source_objects + header_objects
    apart          = { source_includes: source_objects, header_includes: header_objects }

    # Production hands the remaps the whole test file's partials hash, which includes the module
    # being generated. That entry is what tells the source remap to carry this module's own
    # interface header, so omitting it hides a real behavior.
    all_partials = partials.merge( module_name => config )

    implementation = partializer.extract_implementation_functions(
      test: 'PartialsGenerationTest', partial: module_name,
      definitions: c_module.function_definitions, config: config
    )

    interface = partializer.extract_interface_functions(
      test: 'PartialsGenerationTest', partial: module_name,
      definitions: c_module.function_definitions,
      declarations: c_module.function_declarations, config: config
    )

    # The types header carries its own dependencies and its own guard-spoof, so both are
    # computed here the way partials_manager does and handed to the generator.
    types_includes = partializer.remap_types_header_includes(
      name: module_name, **apart, partials: all_partials
    )
    include_guard = partializer.extract_module_include_guard( config.header.filepath )

    types_h_name = generator.generate_types(
      name: module_name, c_module: c_module, output_path: dir,
      includes: types_includes.leading, following_includes: types_includes.following,
      include_guard: include_guard
    )

    header_list = partializer.remap_implementation_header_includes(
      name: module_name, **apart, partials: all_partials,
      types_header: types_h_name
    )

    source_list = partializer.remap_implementation_source_includes(
      name: module_name, includes: raw_includes, partials: all_partials
    )

    interface_list = partializer.remap_interface_header_includes(
      name: module_name, **apart, partials: all_partials,
      types_header: types_h_name
    )

    # What the implementation carries beyond the selection, planned as PartialsManager plans it
    carry = nil
    unless implementation.nil?
      carry = partializer.plan_carry(
        test: 'PartialsGenerationTest', c_module: c_module, impl: implementation, interface: interface,
        header_guarded: !include_guard.nil?, config: config
      )
    end

    generator.generate_implementation(
      name: module_name,
      function_definitions: implementation || [],
      source_includes: source_list,
      header_includes: header_list.leading,
      header_following_includes: header_list.following,
      c_module: c_module,
      output_path: dir,
      include_guard: include_guard,
      carry: carry || Partials::CarryPlan.new,
      suppress_redundant_decls: suppress_redundant_decls,
      extern_variables: extern_variables
    )

    # A mock-only Partial's interface keeps the rest of its real header in an extras header,
    # planned as PartialsManager plans it
    extras = nil
    if implementation.nil? and !interface.nil?
      extras = partializer.plan_interface_extras(
        test: 'PartialsGenerationTest', c_module: c_module, interface: interface, header_guarded: !include_guard.nil?, config: config
      )
    end

    # The mockable interface header is what CMock mocks in place of the real module header,
    # and it carries the same types header the implementation header does. Both land in one
    # translation unit when a module is tested and mocked in the same test file.
    generator.generate_interface(
      name: module_name,
      function_declarations: interface || [],
      includes: interface_list.leading,
      following_includes: interface_list.following,
      c_module: c_module,
      output_path: dir,
      include_guard: include_guard,
      extras: extras
    )

    PartialsGeneration::Result.new(
      dir: dir,
      module_name: module_name,
      mode: mode,
      types_h: read_generated( dir, types_h_name ),
      impl_h: read_generated( dir, "ceedling_partial_#{module_name}_impl.h" ),
      impl_c: read_generated( dir, "ceedling_partial_#{module_name}_impl.c" ),
      interface_h: read_generated( dir, "ceedling_partial_#{module_name}_interface.h" ),
      extras_h: read_generated( dir, "ceedling_partial_#{module_name}_extras.h" ),
      pp_header: File.read( header_file.assembled_filepath, encoding: 'UTF-8' ),
      pp_source: source_file.assembled_filepath && File.read( source_file.assembled_filepath, encoding: 'UTF-8' ),
      carry: carry
    )
  end

  # Preprocesses one module file as stages 6 and 7 do, and gives the record they fill in. The
  # accurate path keeps a raw directives-only copy, which locates functions and marks inline
  # bodies. Both paths keep a full expansion and its own lines as plain code, which
  # reconciliation parses.
  def preprocess_partial_file(dir:, filename:, kind:, includes:, defines:, mode:)
    path = File.join( dir, filename )

    raw =
      case mode
      when :accurate then directives_only( dir: dir, path: path, defines: defines )
      when :fallback then nil
      else raise ArgumentError, "unknown preprocessing mode '#{mode}'"
      end

    raw_expansion, expansion = expand( dir: dir, path: path, defines: defines )

    return Partials::ConfigFileInfo.new(
      filepath: path, raw_directives_only_filepath: raw, raw_expansion_filepath: raw_expansion, expansion_filepath: expansion,
      assembled_filepath: reconstitute_partial_file( dir: dir, filename: filename, kind: kind, includes: includes, raw: raw, defines: defines ),
      fallback: raw.nil?, includes: partial_include_objects( includes )
    )
  end

  # GCC's -fdirectives-only output with its comments stripped, as Preprocessinator#generate_directives_only_output
  # leaves it. Defines reach every pass, as they do in production. Without them a case pairing
  # `defines:` with accurate mode would silently measure the undefined configuration instead.
  def directives_only(dir:, path:, defines:)
    raw = "#{path}.directives_only"
    run_partials_preprocessor( dir: dir, path: path, output: raw, defines: defines, flags: '-fdirectives-only' )
    partials_comment_stripper.strip_file( raw )

    return raw
  end

  # The full expansion and its own lines, as Preprocessinator#generate_partial_expansion writes them
  def expand(dir:, path:, defines:)
    raw  = "#{path}.full_expansion"
    code = "#{path}.expanded_code"
    run_partials_preprocessor( dir: dir, path: path, output: raw, defines: defines )

    contents = partials_file_assembler.collect_own_lines( source_filepath: path, preprocessed_filepath: raw )
    partials_file_assembler.assemble_preprocessed_code_file( preprocessed_filepath: code, contents: contents, extras: [], includes: [] )

    return raw, code
  end

  def run_partials_preprocessor(dir:, path:, output:, defines:, flags: '')
    defines = defines.map { |name| "-D#{name}" }.join( ' ' )
    command = "#{partials_compiler} -E #{flags} #{defines} -I#{dir} -x c #{path} -o #{output}".squeeze( ' ' )

    _out, stderr, status = Open3.capture3( command )
    raise PartialsGeneration::PreprocessFailure, "#{command}\n#{stderr}" unless status.success?
  end

  # Reproduces the assembled copy Preprocessinator#preprocess_partial_file leaves for the
  # extractor, in the same steps and with the same collaborators, and gives its path.
  #
  # The accurate path reads GCC's directives-only output, which resolves every conditional and
  # follows every include while leaving macro directives as written. The fallback path never
  # runs a compiler: it scans the file's own text, tracking conditionals approximately, which
  # is why it resolves less and why Partials needs to refuse some shapes outright under it.
  def reconstitute_partial_file(dir:, filename:, kind:, includes:, raw:, defines:)
    path = File.join( dir, filename )
    contents, extras = raw ? reconstitute_accurate( path: path, raw: raw ) : reconstitute_fallback( path: path, defines: defines )

    assembled    = File.join( dir, "preprocessed_#{filename}" )
    include_list = partial_include_objects( includes )

    if kind == :header
      partials_file_assembler.assemble_preprocessed_header_file(
        filepath: filename, preprocessed_filepath: assembled,
        contents: contents, extras: extras, includes: include_list
      )
    else
      partials_file_assembler.assemble_preprocessed_code_file(
        preprocessed_filepath: assembled, contents: contents, extras: extras, includes: include_list
      )
    end

    return assembled
  end

  # Only lines belonging to this file survive. A type arriving from an included header is
  # discarded here, which is why an extracted type can reference something no generated file
  # declares. On Windows, GCC's directives-only output of a CRLF source ends each line in
  # "\r\r\n", and the production reader's text mode keeps one line break, not two.
  def reconstitute_accurate(path:, raw:)
    return partials_file_assembler.collect_own_lines( source_filepath: path, preprocessed_filepath: raw, rejoin: false ), []
  end

  # Fallback strips every directive line out of the content, so the macros and pragmas the
  # extractor still needs are recovered separately and reinserted as assembler extras. That
  # second pass is what keeps a type's array-size macro visible when no compiler ran.
  def reconstitute_fallback(path:, defines:)
    contents = partials_file_assembler.collect_file_contents_fallback( source_filepath: path, defines: defines )
    extras   = partials_file_assembler.collect_macros_and_pragmas_fallback( source_filepath: path, defines: defines )

    return contents, extras
  end

  # ---- compilation -------------------------------------------------------------

  # GCC before 14 only warns about a call to an undeclared function, as Clang does not. A
  # missing prototype has to fail on every compiler for a case about carrying one to mean anything.
  STRICT_DECLARATIONS = '-Werror=implicit-function-declaration' unless const_defined?( :STRICT_DECLARATIONS )

  # Compiles a translation unit that includes the generated implementation header, the way a
  # generated test runner would. Syntax-only: this probes declarations and ordering, not code
  # generation.
  def compile_partial(result, prelude: '')
    probe = File.join( result.dir, "probe_#{result.module_name}_impl.c" )
    File.write( probe, "#{prelude}#include \"ceedling_partial_#{result.module_name}_impl.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  # Compiles a translation unit including both generated headers at once, which is the shape
  # a module tested and mocked in the same test file produces. The implementation header
  # arrives directly; the interface header arrives the way CMock's generated mock brings it.
  def compile_both_headers(result)
    probe = File.join( result.dir, "probe_#{result.module_name}_both.c" )
    File.write( probe, <<~C )
      #include "ceedling_partial_#{result.module_name}_impl.h"
      #include "ceedling_partial_#{result.module_name}_interface.h"
      int main(void) { return 0; }
    C

    syntax_only( result, probe )
  end

  # Compiles a translation unit that includes the generated interface header, the way the mock
  # CMock generates from it includes it
  def compile_interface(result)
    probe = File.join( result.dir, "probe_#{result.module_name}_interface.c" )
    File.write( probe, "#include \"ceedling_partial_#{result.module_name}_interface.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  # Compiles the types header entirely on its own, which is the question of whether that
  # header is self-contained. Nothing else is included first.
  def compile_types_header_alone(result)
    probe = File.join( result.dir, 'probe_types_alone.c' )
    File.write( probe, "#include \"ceedling_partial_#{result.module_name}_types.h\"\nint main(void) { return 0; }\n" )

    syntax_only( result, probe )
  end

  def syntax_only(result, probe)
    command = "#{partials_compiler} #{STRICT_DECLARATIONS} -fsyntax-only -I#{result.dir} #{probe}"
    _out, stderr, status = Open3.capture3( command )

    PartialsGeneration::Compilation.new( ok: status.success?, stderr: stderr, command: command )
  end

  # ---- linking -----------------------------------------------------------------
  #
  # A syntax-only check reaches missing declarations and conflicting types. It cannot reach
  # the two failure modes that matter most to a feature built on copying and mutating
  # symbols: a definition that went missing, and two definitions colliding. Only a real
  # object file and a real link surface `undefined reference to` and `multiple definition
  # of`, so stripping `static` from a file-scope variable -- which turns a module-private
  # name into one that participates in link-time resolution -- is testable only here.

  # Compiles one result's generated implementation source to a real object file. `flags`
  # reach the compiler as given, so a case can hold the source to a warning set.
  def compile_objects(result, flags: '')
    object = File.join( result.dir, "ceedling_partial_#{result.module_name}_impl.o" )
    source = File.join( result.dir, "ceedling_partial_#{result.module_name}_impl.c" )

    command = "#{partials_compiler} #{STRICT_DECLARATIONS} #{flags} -c -I#{result.dir} #{source} -o #{object}".squeeze( ' ' )
    _out, stderr, status = Open3.capture3( command )

    PartialsGeneration::Compilation.new( ok: status.success?, stderr: stderr, command: command )
  end

  # Links one or more results' generated implementations against a stand-in test translation
  # unit. The stand-in takes the address of each named symbol so the linker has to resolve
  # it; a symbol that merely compiles is not proof the definition survived.
  #
  # `stubs` is C the stand-in test file defines, the way a real test defines a stub for a
  # function it subtracted. `flags` reach the compiler as given.
  def link_partials(results, references: [], stubs: '', flags: '')
    results = Array( results )
    dir     = results.first.dir

    headers = results.map { |r| "#include \"ceedling_partial_#{r.module_name}_impl.h\"" }
    body =
      if references.empty?
        '  return 0;'
      else
        refs = references.map { |symbol| "(const void*)&#{symbol}" }.join( ", " )
        "  const void* refs[] = { #{refs} };\n  return refs[0] == 0;"
      end

    probe = File.join( dir, "probe_link_#{results.map( &:module_name ).join( '_' )}.c" )
    File.write( probe, "#{headers.join( "\n" )}\n#{stubs}\nint main(void) {\n#{body}\n}\n" )

    sources = results.map { |r| File.join( r.dir, "ceedling_partial_#{r.module_name}_impl.c" ) }
    includes = results.map( &:dir ).uniq.map { |d| "-I#{d}" }.join( ' ' )
    output = File.join( dir, "probe_link_#{results.map( &:module_name ).join( '_' )}" )

    command = "#{partials_compiler} #{STRICT_DECLARATIONS} #{flags} #{includes} #{probe} #{sources.join( ' ' )} -o #{output}".squeeze( ' ' )
    _out, stderr, status = Open3.capture3( command )

    PartialsGeneration::Compilation.new( ok: status.success?, stderr: stderr, command: command )
  end

  def link_partial(result, references: [], stubs: '', flags: '')
    link_partials( [result], references: references, stubs: stubs, flags: flags )
  end

  # A `partials:` entry for some *other* partialized module in the same test file. The remap
  # methods read `mocks.type` to decide between dropping that module's include and redirecting
  # it to the module's generated interface header, so a case has to say which it is.
  def other_partial(module_name, mocked: false)
    {
      module_name => PartializerConfig::Config.new(
        module: module_name,
        tests: PartializerConfig::PartialFunctions.new( type: PartializerConfig::DEDUCT ),
        mocks: PartializerConfig::PartialFunctions.new(
          type: mocked ? PartializerConfig::DEDUCT : nil
        )
      )
    }
  end

  # A working directory shared by two generated modules, for cases where a collision between
  # them is the subject. Cleaned up by the caller through cleanup_dir.
  def shared_partials_dir
    Dir.mktmpdir( 'partials-generation-shared-' )
  end

  def cleanup_dir(dir)
    FileUtils.rm_rf( dir ) if dir
  end

  def cleanup_partial(result)
    FileUtils.rm_rf( result.dir ) if result&.dir
  end

  def partials_compiler
    ENV.fetch( 'PARTIALS_GENERATION_CC', 'gcc' )
  end

  # Clang answers to `gcc` on macOS, and some warnings only GCC reports
  def partials_compiler_gcc?
    @partials_compiler_gcc = !`#{partials_compiler} --version 2>&1`.match?( /clang/i ) if @partials_compiler_gcc.nil?
    return @partials_compiler_gcc
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
    partials_c_extractor.from_string( content: content )
  end

  # A real extractor that reads files with a real file wrapper, as Partializer reads the
  # assembled copies and reconciliation reads the expanded code
  def partials_c_extractor
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
        file_wrapper:              partials_file_wrapper
      }
    )
    extractor.setup()
    extractor
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

  # Include remapping, #sanitize, and function extraction all run for real, so the helper is
  # real too. File discovery and configuration are the only doubled collaborators.
  def build_partializer
    Partializer.new(
      {
        configurator:                   RSpec::Mocks::Double.new( 'Configurator' ).as_null_object,
        partializer_helper:             partials_helper,
        partializer_reconciler:         PartializerReconciler.new( c_extractor: partials_c_extractor, loginator: partials_null_loginator ),
        file_finder:                    RSpec::Mocks::Double.new( 'FileFinder' ).as_null_object,
        c_extractor:                    partials_c_extractor,
        file_path_utils:                partials_file_path_utils,
        preprocessinator_reconstructor: partials_reconstructor,
        file_wrapper:                   partials_file_wrapper,
        reportinator:                   RSpec::Mocks::Double.new( 'Reportinator' ).as_null_object,
        loginator:                      partials_null_loginator
      }
    )
  end

  # One instance per case, memoized so extraction and the later passes share state. Every
  # collaborator is real, so selected bodies and carried items alike carry the #line a build
  # gives them.
  def partials_helper
    @partials_helper ||= PartializerHelper.new(
      {
        # A real finder, so a carried prototype's #line names its true line and reaches the compiler
        partializer_utils:        PartializerUtils.new(
                                    {
                                      preprocessinator_code_finder: PreprocessinatorCodeFinder.new( { file_wrapper: partials_file_wrapper } ),
                                      loginator: partials_null_loginator
                                    }
                                  ),
        c_extractor_declarations: CExtractorDeclarations.new(
                                    { c_extractor_code_text: CExtractorCodeText.new }
                                  ).tap( &:setup ),
        parsing_parcels:          ParsingParcels.new,
        loginator:                partials_null_loginator
      }
    ).tap( &:setup )
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

  # Of the nine collaborators, the assemble and fallback-collect methods used here consult
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
        reportinator:                   RSpec::Mocks::Double.new( 'Reportinator' ).as_null_object,
        build_step_doctor:              RSpec::Mocks::Double.new( 'BuildStepDoctor' ).as_null_object
      }
    )
  end

  def partials_file_wrapper
    FileWrapper.new( loginator: partials_null_loginator, verbosinator: partials_null_verbosinator )
  end

  # Partializer names generated files with it. Each record carries its preprocessed paths, so
  # no build tree is needed.
  def partials_file_path_utils
    FilePathUtils.new(
      configurator: RSpec::Mocks::Double.new( 'Configurator', project_test_preprocess_files_path: '/no/preprocessed/files' ).as_null_object,
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
