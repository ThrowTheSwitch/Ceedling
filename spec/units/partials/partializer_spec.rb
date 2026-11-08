
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/includes'
require 'ceedling/partials/partializer'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_config'
require 'ceedling/reportinator'
require 'ceedling/c_extractor/c_extractor_types'
require 'ostruct'

describe Partializer do
  before(:each) do
    @partializer_helper = double("PartializerHelper")
    @file_finder        = double("FileFinder")
    @c_extractor        = double("CExtractor")
    @file_path_utils    = double("FilePathUtils")
    @reportinator       = Reportinator.new
    @loginator          = double("Loginator").as_null_object

    # Guard extraction reads the module's own header text through these two.
    @preprocessinator_reconstructor = double("PreprocessinatorReconstructor")
    @file_wrapper                   = double("FileWrapper")

    @configurator = double( "Configurator" )
    allow(@configurator).to receive(:paths_test).and_return( ['test'] )
    allow(@configurator).to receive(:paths_support).and_return( [] )
    allow(@configurator).to receive(:paths_include).and_return( ['include'] )
    allow(@configurator).to receive(:collection_mirror_roots_headers).and_return( ['test', 'include'] )

    @partializer = described_class.new(
      {
        :configurator       => @configurator,
        :partializer_helper => @partializer_helper,
        :file_finder        => @file_finder,
        :c_extractor        => @c_extractor,
        :file_path_utils    => @file_path_utils,
        :preprocessinator_reconstructor => @preprocessinator_reconstructor,
        :file_wrapper       => @file_wrapper,
        :reportinator       => @reportinator,
        :loginator          => @loginator
      }
    )

    # Logging happens in production use only and is not directly tested.
    # Silence all private logging helpers so that test doubles for extracted
    # functions and variable declarations do not need .signature / .text stubs.
    allow(@partializer).to receive(:_log_module_contents)
    allow(@partializer).to receive(:_log_impl_functions)
    allow(@partializer).to receive(:_log_interface_functions)
  end

  # A stand-in for another partialized module's config. Only the two visibility types matter to
  # include remapping: a non-nil mocks type means that module has a generated interface header
  # to redirect to.
  def make_partial_config(mocks_type: nil, tests_type: nil)
    OpenStruct.new(
      mocks: OpenStruct.new(type: mocks_type),
      tests: OpenStruct.new(type: tests_type)
    )
  end

  ###
  ### populate_filepaths()
  ###

  context "#populate_filepaths" do
    def make_tests(present:)
      OpenStruct.new(present?: present)
    end

    def make_mocks(present:, type: nil)
      OpenStruct.new(present?: present, type: type)
    end

    def make_config(tests:, mocks:)
      OpenStruct.new(
        tests:  tests,
        mocks:  mocks,
        header: OpenStruct.new(filepath: nil),
        source: OpenStruct.new(filepath: nil)
      )
    end

    it "returns the configs hash unchanged when empty" do
      result = @partializer.populate_filepaths({})
      expect(result).to eq({})
    end

    # --- Resolution against this test's own search paths ---
    #
    # A module's header is resolved against the ordered collection its own test would
    # search, so a TEST_INCLUDE_PATH() in that test decides the outcome. Resolving
    # against one project-wide collection instead lets two modules sharing a basename
    # collapse to whichever appears first, regardless of which test asked.
    context "resolving against a caller's collection" do
      it "forwards the collection it is given to the header lookup" do
        configs = { 'config' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }
        ordered = ['include/drivers/uart/config.h']

        expect(@file_finder).to receive(:find_header_file)
          .with('config', :ignore, collection: ordered)
          .and_return('include/drivers/uart/config.h')
        allow(@file_finder).to receive(:find_source_file).and_return('src/drivers/uart/config.c')
        allow(PathMirror).to receive(:relative_subdir).and_return('drivers/uart')

        @partializer.populate_filepaths(configs, collection: ordered)
      end
    end

    # A bare module name says nothing about which directory it meant, so pairing one
    # module's header with another module's source is possible. Narrowing the source
    # lookup by the resolved header's own directory removes that mismatch.
    context "a bare module name whose header resolved under a directory" do
      before(:each) do
        @configs = { 'config' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }
        allow(@file_finder).to receive(:find_header_file).and_return('include/drivers/uart/config.h')
        allow(PathMirror).to receive(:relative_subdir).and_return('drivers/uart')
      end

      it "looks the source up under that same directory" do
        expect(@file_finder).to receive(:find_source_file)
          .with('drivers/uart/config', :ignore)
          .and_return('src/drivers/uart/config.c')

        @partializer.populate_filepaths(@configs)

        expect(@configs['config'].source.filepath).to eq('src/drivers/uart/config.c')
      end

      # A project whose source and include trees do not mirror one another has a
      # header under a directory and a source that is not. The bare name still has to
      # work there.
      it "falls back to the bare name when nothing sits under that directory" do
        allow(@file_finder).to receive(:find_source_file).with('drivers/uart/config', :ignore).and_return(nil)
        expect(@file_finder).to receive(:find_source_file).with('config', :ignore).and_return('src/config.c')

        @partializer.populate_filepaths(@configs)

        expect(@configs['config'].source.filepath).to eq('src/config.c')
      end
    end

    context "a bare module name whose header resolved directly in a root" do
      it "looks the source up by the bare name alone" do
        configs = { 'config' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }
        allow(@file_finder).to receive(:find_header_file).and_return('include/config.h')
        allow(PathMirror).to receive(:relative_subdir).and_return('')

        expect(@file_finder).to receive(:find_source_file).with('config', :ignore).once.and_return('src/config.c')

        @partializer.populate_filepaths(configs)
      end
    end

    # A module named by directory was spelled out by its author, so both lookups use it
    # verbatim and neither falls back to a bare name. Falling back would defeat the
    # point of naming the directory.
    context "a module named by directory" do
      it "looks both the header and the source up verbatim" do
        configs = { 'drivers/uart/config' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }

        allow(@file_finder).to receive(:find_header_file).and_return('include/drivers/uart/config.h')
        expect(@file_finder).to receive(:find_source_file)
          .with('drivers/uart/config', :ignore).once
          .and_return('src/drivers/uart/config.c')

        @partializer.populate_filepaths(configs)
      end

      it "raises when it names no header" do
        configs = { 'drivers/uart/confg' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }

        allow(@file_finder).to receive(:find_header_file).and_return(nil)
        allow(@file_finder).to receive(:find_source_file).and_return(nil)

        expect {
          @partializer.populate_filepaths(configs)
        }.to raise_error( CeedlingException, /drivers\/uart\/confg/ )
      end
    end

    context "a Partial that only mocks public functions" do
      it "never looks up a source, whichever way its module was named" do
        configs = {
          'drivers/uart/config' => make_config(
            tests: make_tests(present: false),
            mocks: make_mocks(present: true, type: Partials::PUBLIC)
          )
        }

        allow(@file_finder).to receive(:find_header_file).and_return('include/drivers/uart/config.h')
        expect(@file_finder).to_not receive(:find_source_file)

        @partializer.populate_filepaths(configs)
      end
    end

    it "populates header and source for a test config" do
      configs = { 'mod' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore, collection: nil).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "populates header only for mock-public config" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PUBLIC)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore, collection: nil).and_return('mod.h')
      expect(@file_finder).not_to receive(:find_source_file)

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to be_nil
    end

    it "populates header and source for mock-private config" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PRIVATE)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore, collection: nil).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "populates header and source when mocks.type is nil" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: nil)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore, collection: nil).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "handles multiple modules independently" do
      configs = {
        'a' => make_config(tests: make_tests(present: true),  mocks: make_mocks(present: false)),
        'b' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PUBLIC))
      }

      allow(@file_finder).to receive(:find_header_file).with('a', :ignore, collection: nil).and_return('a.h')
      allow(@file_finder).to receive(:find_source_file).with('a', :ignore).and_return('a.c')
      allow(@file_finder).to receive(:find_header_file).with('b', :ignore, collection: nil).and_return('b.h')
      expect(@file_finder).not_to receive(:find_source_file).with('b', :ignore)

      @partializer.populate_filepaths(configs)

      expect(configs['a'].header.filepath).to eq('a.h')
      expect(configs['a'].source.filepath).to eq('a.c')
      expect(configs['b'].header.filepath).to eq('b.h')
      expect(configs['b'].source.filepath).to be_nil
    end
  end

  ###
  ### validate_config()
  ###

  context "#validate_config" do
    it "delegates to three validation helpers in order" do
      c_module = double("CModule")
      config   = double("Config")
      name     = "test_foo"

      expect(@partializer_helper).to receive(:validate_function_names_exist)
        .with(c_module, config, name).ordered
      expect(@partializer_helper).to receive(:validate_no_additions_subtractions_overlap)
        .with(config, name).ordered
      expect(@partializer_helper).to receive(:validate_additions_subtractions_visibility)
        .with(c_module, config, name).ordered

      @partializer.validate_config(c_module: c_module, config: config, name: name, fallback: false)
    end

    # The fourth check only applies where preprocessing resolved less than it could, so the
    # accurate path must not pay for it.
    it "does not check fallback sufficiency when preprocessing was accurate" do
      allow(@partializer_helper).to receive(:validate_function_names_exist)
      allow(@partializer_helper).to receive(:validate_no_additions_subtractions_overlap)
      allow(@partializer_helper).to receive(:validate_additions_subtractions_visibility)

      expect(@partializer_helper).not_to receive(:validate_fallback_sufficiency)

      @partializer.validate_config(
        c_module: double("CModule"), config: double("Config"), name: 'test_foo', fallback: false
      )
    end

    it "hands the module's own header and source text to the fallback sufficiency check" do
      allow(@partializer_helper).to receive(:validate_function_names_exist)
      allow(@partializer_helper).to receive(:validate_no_additions_subtractions_overlap)
      allow(@partializer_helper).to receive(:validate_additions_subtractions_visibility)

      config = PartializerConfig::Config.new(
        module: 'Foo',
        header: Partials::ConfigFileInfo.new( filepath: 'src/Foo.h' ),
        source: Partials::ConfigFileInfo.new( filepath: 'src/Foo.c' )
      )

      allow(@file_wrapper).to receive(:read).with('src/Foo.h').and_return('header text')
      allow(@file_wrapper).to receive(:read).with('src/Foo.c').and_return('source text')

      expect(@partializer_helper).to receive(:validate_fallback_sufficiency).with(
        name: 'test_foo',
        module_name: 'Foo',
        files: { 'src/Foo.h' => 'header text', 'src/Foo.c' => 'source text' }
      )

      @partializer.validate_config(
        c_module: double("CModule"), config: config, name: 'test_foo', fallback: true
      )
    end

    # A declaration-only Partial is a prototype with no matching definition, which leaves its
    # source filepath legitimately nil.
    it "skips a Partial's absent source file rather than reading nil" do
      allow(@partializer_helper).to receive(:validate_function_names_exist)
      allow(@partializer_helper).to receive(:validate_no_additions_subtractions_overlap)
      allow(@partializer_helper).to receive(:validate_additions_subtractions_visibility)

      config = PartializerConfig::Config.new(
        module: 'Foo',
        header: Partials::ConfigFileInfo.new( filepath: 'src/Foo.h' ),
        source: Partials::ConfigFileInfo.new( filepath: nil )
      )

      allow(@file_wrapper).to receive(:read).with('src/Foo.h').and_return('header text')

      expect(@partializer_helper).to receive(:validate_fallback_sufficiency).with(
        name: 'test_foo', module_name: 'Foo', files: { 'src/Foo.h' => 'header text' }
      )

      @partializer.validate_config(
        c_module: double("CModule"), config: config, name: 'test_foo', fallback: true
      )
    end
  end

  ###
  ### extract_module_include_guard()
  ###

  context "#extract_module_include_guard" do
    # Read from the original header, not the reconstituted copy: that copy carries a synthetic
    # guard which #sanitize then strips, and fallback preprocessing excludes a guard from the
    # macros it recovers. Neither is a dependable source for the name to spoof.
    it "reads a bounded prefix of the module's own header and returns the guard found" do
      expect(@file_wrapper).to receive(:read)
        .with('src/Foo.h', Partializer::GUARD_SCAN_BYTES)
        .and_return("#ifndef FOO_H\n#define FOO_H\n")
      allow(@preprocessinator_reconstructor).to receive(:extract_include_guard)
        .with("#ifndef FOO_H\n#define FOO_H\n")
        .and_return('FOO_H')

      expect( @partializer.extract_module_include_guard('src/Foo.h') ).to eq('FOO_H')
    end

    # A `#pragma once` header offers no macro any generated file could define, which is what a
    # nil return means to every caller.
    it "returns nil when the header carries no guard macro" do
      allow(@file_wrapper).to receive(:read).and_return("#pragma once\n")
      allow(@preprocessinator_reconstructor).to receive(:extract_include_guard).and_return(nil)

      expect( @partializer.extract_module_include_guard('src/Foo.h') ).to be_nil
    end

    it "returns nil for an absent filepath without reading anything" do
      expect(@file_wrapper).not_to receive(:read)

      expect( @partializer.extract_module_include_guard(nil) ).to be_nil
    end
  end

  ###
  ### sanitize()
  ###

  context "#sanitize" do
    def make_macro(text)
      CExtractorTypes::CStatement.new(text: text, line_num: 1)
    end

    def make_module(macros: [], sequence: nil)
      m = CExtractorTypes::CModule.new
      m.macro_definitions = macros.dup
      m.element_sequence  = sequence || macros.dup
      m
    end

    it "leaves macro_definitions unchanged when no macro carries a generated include guard" do
      macro = make_macro('#define MY_GUARD_H')
      mod   = make_module(macros: [macro])

      @partializer.sanitize(mod)

      expect(mod.macro_definitions).to eq([macro])
    end

    it "leaves element_sequence unchanged when no macro carries a generated include guard" do
      macro = make_macro('#define MY_GUARD_H')
      mod   = make_module(macros: [macro])

      @partializer.sanitize(mod)

      expect(mod.element_sequence).to eq([macro])
    end

    it "removes macros carrying a generated include guard from macro_definitions" do
      generated = make_macro('#ifndef GEN0123ABCD_FOO_H_CEEDLING')
      kept      = make_macro('#define MY_DEFINE 1')
      mod       = make_module(macros: [generated, kept])

      @partializer.sanitize(mod)

      expect(mod.macro_definitions).to eq([kept])
      expect(mod.macro_definitions).not_to include(generated)
    end

    it "removes the same macro objects from element_sequence" do
      generated = make_macro('#ifndef GEN0123ABCD_BAR_H_CEEDLING')
      kept      = make_macro('#define MY_DEFINE 2')
      mod       = make_module(macros: [generated, kept])

      @partializer.sanitize(mod)

      expect(mod.element_sequence).not_to include(generated)
      expect(mod.element_sequence).to include(kept)
    end

    it "removes all macros when every macro carries a generated include guard" do
      m1  = make_macro('#ifndef GEN0123ABCD_A_H_CEEDLING')
      m2  = make_macro('#define GEN0123ABCD_A_H_CEEDLING')
      mod = make_module(macros: [m1, m2])

      @partializer.sanitize(mod)

      expect(mod.macro_definitions).to be_empty
      expect(mod.element_sequence).to be_empty
    end

    # A generated guard opens with GEN and eight hex digits and closes with _CEEDLING, each
    # at an identifier boundary, so a macro merely resembling one stays
    it "keeps macros whose names only resemble a generated include guard" do
      lookalikes = [
        make_macro('#define MY_GEN0123ABCD_FOO_H_CEEDLING 1'),
        make_macro('#define GEN0123ABCD_FOO_H_CEEDLING_LIMIT 2'),
        make_macro('#define GEN0123ABC_FOO_H_CEEDLING 3'),
        make_macro('#define GEN0123ABCD_CEEDLING 4')
      ]
      mod = make_module(macros: lookalikes)

      @partializer.sanitize(mod)

      expect(mod.macro_definitions).to eq(lookalikes)
    end

    it "does not remove non-macro elements from element_sequence" do
      generated  = make_macro('#ifndef GEN0123ABCD_C_H_CEEDLING')
      other_elem = double('CFunction', text: 'void foo(void){}')
      mod = CExtractorTypes::CModule.new
      mod.macro_definitions = [generated]
      mod.element_sequence  = [generated, other_elem]

      @partializer.sanitize(mod)

      expect(mod.element_sequence).to include(other_elem)
      expect(mod.element_sequence).not_to include(generated)
    end

    it "handles empty macro_definitions without error" do
      mod = make_module(macros: [])

      expect { @partializer.sanitize(mod) }.not_to raise_error
      expect(mod.macro_definitions).to be_empty
      expect(mod.element_sequence).to be_empty
    end
  end

  ###
  ### validate_extracted_functions()
  ###

  context "#plan_carry" do
    it "returns the helper's plan for the module and both selections" do
      c_module = CExtractorTypes::CModule.new
      impl     = [Partials.manufacture_function_definition( name: 'get', signature: 'int get(void)', code_block: '' )]
      plan     = Partials::CarryPlan.new

      expect(@partializer_helper).to receive(:plan_carry).with(
        c_module: c_module, impl: impl, interface: nil, fallback: false, header_guarded: true
      ).and_return( plan )

      result = @partializer.plan_carry(
        test: 'test_foo', partial: 'Foo', c_module: c_module, impl: impl, interface: nil,
        fallback: false, header_guarded: true, header_filepath: 'src/Foo.h', source_filepath: 'src/Foo.c'
      )

      expect( result ).to equal( plan )
    end

    def plan_for(prototypes: [], helpers: [], skipped: [])
      plan = Partials::CarryPlan.new
      prototypes.each { |sig, reason| plan.add_prototype( CExtractorTypes::CFunctionDeclaration.new( name: sig[/(\w+)\(/, 1], signature: sig ), reason ) }
      helpers.each do |name, reason|
        plan.add_helper( Partials.manufacture_function_definition( name: name, signature: "int #{name}(int v)", code_block: '' ), reason )
      end
      skipped.each { |name, kind| plan.skip( name, kind ) }
      plan
    end

    def carry_with(plan)
      allow(@partializer_helper).to receive(:plan_carry).and_return( plan )
      @partializer.plan_carry(
        test: 'test_engine', partial: 'engine', c_module: CExtractorTypes::CModule.new, impl: [], interface: nil,
        fallback: false, header_guarded: true, header_filepath: 'src/engine.h', source_filepath: 'src/engine.c'
      )
    end

    # A match in the original file can't belong to a header that file includes
    it "locates each carried prototype in the text of the file it came from" do
      header_proto = CExtractorTypes::CFunctionDeclaration.new( name: 'tick', signature: 'int tick(void);', origin: :header )
      source_proto = CExtractorTypes::CFunctionDeclaration.new( name: 'twice', signature: 'extern inline int twice(void);', origin: :source )
      plan = Partials::CarryPlan.new
      plan.add_prototype( header_proto, 'external: no body in module' )
      plan.add_prototype( source_proto, 'external: no body in module' )
      allow(@partializer_helper).to receive(:plan_carry).and_return( plan )
      allow(@file_wrapper).to receive(:read).with('src/engine.h').and_return('header text')
      allow(@file_wrapper).to receive(:read).with('src/engine.c').and_return('source text')

      expect(@partializer_helper).to receive(:associate_declaration_line_numbers).with(
        decls: [header_proto], filepath: 'src/engine.h', text: 'header text'
      )
      expect(@partializer_helper).to receive(:associate_declaration_line_numbers).with(
        decls: [source_proto], filepath: 'src/engine.c', text: 'source text'
      )

      carry_with( plan )
    end

    # A prototype with no known file, or from a file the module lacks, is written without a #line
    it "searches no file for a prototype whose file is unknown" do
      unknown = CExtractorTypes::CFunctionDeclaration.new( name: 'tick', signature: 'int tick(void);', origin: nil )
      source  = CExtractorTypes::CFunctionDeclaration.new( name: 'twice', signature: 'int twice(void);', origin: :source )
      plan    = Partials::CarryPlan.new
      plan.add_prototype( unknown, 'external: no body in module' )
      plan.add_prototype( source, 'external: no body in module' )
      allow(@partializer_helper).to receive(:plan_carry).and_return( plan )

      expect(@file_wrapper).not_to receive(:read)
      expect(@partializer_helper).not_to receive(:associate_declaration_line_numbers)

      @partializer.plan_carry(
        test: 'test_engine', partial: 'engine', c_module: CExtractorTypes::CModule.new, impl: [], interface: nil,
        fallback: false, header_guarded: true, header_filepath: 'src/engine.h', source_filepath: nil
      )
    end

    it "reads no file when nothing is carried" do
      expect(@file_wrapper).not_to receive(:read)

      carry_with( Partials::CarryPlan.new )
    end

    it "lists everything carried, with reasons, at debug verbosity" do
      plan = plan_for(
        prototypes: [['int board_tick(void);', 'external: no body in module'], ['int engine_poll(void);', 'left out: body not selected']],
        helpers:    [['clamp', 'helper: referenced by `engine_get`']]
      )

      expect(@loginator).to receive(:log_list).with(
        ['`int board_tick(void);` (external: no body in module)',
         '`int engine_poll(void);` (left out: body not selected)',
         '`clamp()` (helper: referenced by `engine_get`)'],
        'Carried into Partial test_engine::engine implementation:',
        Verbosity::DEBUG
      )

      carry_with( plan )
    end

    it "lists nothing when nothing is carried" do
      expect(@loginator).not_to receive(:log_list)

      carry_with( Partials::CarryPlan.new )
    end

    it "gives notice of a helper fallback left with more than one definition" do
      plan = plan_for( skipped: [['clamp', :helper_conflict]] )

      expect(@loginator).to receive(:log).with(
        "Partial test_engine::engine \u23e9\ufe0f Not carrying helper `clamp()`: fallback preprocessing found more than one definition. Add `+clamp` if a selected function needs it",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      carry_with( plan )
    end

    it "gives one notice naming every helper an unguarded module header kept out" do
      plan = plan_for( skipped: [
        ['clamp', :unguarded_helper],
        ['counter', :unguarded_helper]
      ] )

      allow(@loginator).to receive(:log)

      carry_with( plan )

      expect(@loginator).to have_received(:log).with(
        "Partial test_engine::engine \u23e9\ufe0f Not carrying helpers `clamp()`, `counter()` from src/engine.h.\n" \
        "Selected functions call these helpers, but src/engine.h has no include guard. Without a guard\n" \
        "a Partial cannot stand in for the header everywhere it is included, and a carried copy could\n" \
        "collide with the real one.\n" \
        "\n" \
        "OPTIONS:\n" \
        "  1. Give src/engine.h an include guard so the Partial can stand in for it.\n" \
        "  2. Select the helpers with `+name` (for example `+clamp`). This works only when no other\n" \
        "     header this module includes pulls in src/engine.h.\n" \
        "\n" \
        "See the docs on Partials conventions.\n",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )
      expect(@loginator).to have_received(:log).once
    end

    it "words the unguarded-header notice for a single helper" do
      plan = plan_for( skipped: [['clamp', :unguarded_helper]] )

      expect(@loginator).to receive(:log).with(
        a_string_including( 'Not carrying helper `clamp()` from src/engine.h.', 'call this helper', 'Select the helper with' ),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      carry_with( plan )
    end

    # Additions can't name a function the module only declares, so no `+name` hint follows
    it "gives notice of a prototype fallback left with conflicting declarations" do
      plan = plan_for( skipped: [['board_tick', :prototype_conflict]] )

      expect(@loginator).to receive(:log).with(
        "Partial test_engine::engine \u23e9\ufe0f Not carrying `board_tick()`: fallback preprocessing found conflicting declarations",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      carry_with( plan )
    end

    context "marking extern variables of incomplete types" do
      def extern_var(name, type)
        CExtractorTypes::CVariableDeclaration.new( name: name, type: type, decorators: ['extern'], text: "#{type} #{name};" )
      end

      # Each file's raw directives-only copy, present only where `copies` gives its text. Files and
      # copies are read as bytes, since the search needs nothing more.
      def stub_texts(header:, source:, copies: {})
        allow(@file_wrapper).to receive(:read_binary).with('src/engine.h').and_return( header )
        allow(@file_wrapper).to receive(:read_binary).with('src/engine.c').and_return( source )
        allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath) { |path, _test| "raw/#{path}" }
        allow(@file_wrapper).to receive(:exist?) { |path| copies.key?( path ) }
        copies.each { |path, text| allow(@file_wrapper).to receive(:read_binary).with( path ).and_return( text ) }
      end

      def incomplete_for(c_module, fallback: false)
        allow(@partializer_helper).to receive(:plan_carry).and_return( Partials::CarryPlan.new )
        @partializer.plan_carry(
          test: 'test_engine', partial: 'engine', c_module: c_module, impl: [], interface: nil,
          fallback: fallback, header_guarded: true, header_filepath: 'src/engine.h', source_filepath: 'src/engine.c'
        ).incomplete
      end

      it "marks a struct variable whose struct the module only declares" do
        stub_texts( header: "struct handle_s;\nextern struct handle_s handle;\n", source: "#include \"engine.h\"\n" )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'handle', 'struct handle_s' )] )

        expect( incomplete_for( c_module ) ).to eq( Set['handle'] )
      end

      # A pointer is complete whatever it points to, so a function pointer can always be defined
      it "leaves alone a function pointer returning a struct the module only declares" do
        stub_texts( header: "struct handle_s;\nextern struct handle_s (*make_handle)(void);\n", source: '' )
        maker = CExtractorTypes::CVariableDeclaration.new(
          name: 'make_handle', type: 'struct handle_s', declarator: '(*make_handle)(void)',
          decorators: ['extern'], text: 'struct handle_s (*make_handle)(void);'
        )

        expect( incomplete_for( CExtractorTypes::CModule.new( variable_declarations: [maker] ) ) ).to be_empty
      end

      it "follows a typedef to the struct it names" do
        stub_texts( header: "typedef struct handle_s handle_t;\nextern handle_t handle;\n", source: '' )
        c_module = CExtractorTypes::CModule.new(
          variable_declarations: [extern_var( 'handle', 'handle_t' )],
          type_definitions:      [CExtractorTypes::CStatement.new( text: 'typedef struct handle_s handle_t;' )]
        )

        expect( incomplete_for( c_module ) ).to eq( Set['handle'] )
      end

      it "follows a typedef to the union it names" do
        stub_texts( header: "typedef union word_u word_t;\nextern word_t word;\n", source: '' )
        c_module = CExtractorTypes::CModule.new(
          variable_declarations: [extern_var( 'word', 'word_t' )],
          type_definitions:      [CExtractorTypes::CStatement.new( text: 'typedef union word_u word_t;' )]
        )

        expect( incomplete_for( c_module ) ).to eq( Set['word'] )
      end

      it "leaves alone a variable whose struct the module defines" do
        stub_texts( header: "extern struct point_s origin;\n", source: "struct point_s { int x; };\n" )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect( incomplete_for( c_module ) ).to be_empty
      end

      # A directives-only copy holds the text of every header its file includes
      it "leaves alone a variable whose struct an included header defines" do
        stub_texts(
          header: "#include \"point.h\"\nextern struct point_s origin;\n", source: '',
          copies: { 'raw/src/engine.h' => "struct point_s {\n  int x;\n};\nextern struct point_s origin;\n" }
        )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect( incomplete_for( c_module ) ).to be_empty
      end

      # Fallback writes no raw copy, so any copy on disk is stale
      it "reads no raw copy under fallback preprocessing" do
        stub_texts(
          header: "#include \"point.h\"\nextern struct point_s origin;\n", source: '',
          copies: { 'raw/src/engine.h' => "struct point_s {\n  int x;\n};\n" }
        )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect(@file_wrapper).not_to receive(:read_binary).with('raw/src/engine.h')
        expect( incomplete_for( c_module, fallback: true ) ).to eq( Set['origin'] )
      end

      it "still searches the module's own files under fallback preprocessing" do
        stub_texts( header: "extern struct point_s origin;\n", source: "struct point_s { int x; };\n" )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect( incomplete_for( c_module, fallback: true ) ).to be_empty
      end

      # A file read as bytes may hold CRLF line endings and bytes no encoding accepts
      it "finds the completing definition in text read as bytes" do
        stub_texts( header: "extern struct point_s origin;\n".b, source: "/* \xFF */\r\nstruct point_s\r\n{ int x; };\r\n".b )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect( incomplete_for( c_module ) ).to be_empty
      end

      # A tag that merely ends in the variable's tag completes a different type
      it "does not take a longer tag's definition for the variable's own" do
        stub_texts( header: "extern struct point_s origin;\n", source: "struct my_point_s { int x; };\n" )
        c_module = CExtractorTypes::CModule.new( variable_declarations: [extern_var( 'origin', 'struct point_s' )] )

        expect( incomplete_for( c_module ) ).to eq( Set['origin'] )
      end

      it "reads no file when no extern variable names a struct or union" do
        expect(@file_wrapper).not_to receive(:read)
        expect(@file_wrapper).not_to receive(:read_binary)
        c_module = CExtractorTypes::CModule.new( variable_declarations: [
          extern_var( 'count', 'int' ),
          extern_var( 'next', 'struct node_s*' ),
          CExtractorTypes::CVariableDeclaration.new( name: 'own', type: 'struct node_s', text: 'struct node_s own;' )
        ] )

        expect( incomplete_for( c_module ) ).to be_empty
      end
    end
  end

  context "#validate_extracted_functions" do
    def make_impl(name)
      Partials.manufacture_function_definition(
        name: name, signature: "void #{name}(void)", code_block: "void #{name}(void) {}"
      )
    end

    def make_iface(name)
      Partials.manufacture_function_declaration(name: name, signature: "void #{name}(void)")
    end

    it "does not raise when impl is nil" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: nil, interface: [make_iface('foo')]
        )
      }.not_to raise_error
    end

    it "does not raise when interface is nil" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [make_impl('foo')], interface: nil
        )
      }.not_to raise_error
    end

    it "does not raise when impl is empty" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [], interface: [make_iface('foo')]
        )
      }.not_to raise_error
    end

    it "does not raise when interface is empty" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [make_impl('foo')], interface: []
        )
      }.not_to raise_error
    end

    it "does not raise when impl and interface have no overlapping functions" do
      impl      = [make_impl('foo'), make_impl('bar')]
      interface = [make_iface('baz'), make_iface('qux')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.not_to raise_error
    end

    it "raises CeedlingException when one function appears in both impl and interface" do
      impl      = [make_impl('foo'), make_impl('shared')]
      interface = [make_iface('shared'), make_iface('bar')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.to raise_error(CeedlingException, /shared/)
    end

    # Validation aborts the build on the first overlap it finds. It reports one
    # function, not all of them, which is why this example no longer claims it
    # raises "for each" overlapping function.
    it "raises naming the first overlapping function when multiple functions overlap" do
      impl      = [make_impl('alpha'), make_impl('beta')]
      interface = [make_iface('alpha'), make_iface('beta')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.to raise_error(
        CeedlingException,
        "test_mod: Partial 'mod' \u23e9\ufe0f Function 'alpha' cannot be both testable and mockable"
      )
    end
  end

  ###
  ### remap_implementation_header_includes()
  ###

  context "#remap_implementation_header_includes" do
    it "returns empty array when input is empty and no partials" do
      includes = []
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([])
    end

    it "removes module's own header from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
    end

    # A module's own header is compared by basename, since that is what an #include
    # carries. Leaving it in the generated Partial would emit an #include whose own
    # resolution depends on search path order, which is how a Partial for one module
    # ends up reading another module's header.
    it "removes the module's own header when the module is named by directory" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('config.h'), UserInclude.new('header2.h')]

      result = @partializer.remap_implementation_header_includes(
        name: 'drivers/uart/config',
        includes: includes,
        partials: {}
      )

      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "splices the types header in at the position of a directory-named module's own header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('config.h'), UserInclude.new('header2.h')]

      result = @partializer.remap_implementation_header_includes(
        name: 'drivers/uart/config',
        includes: includes,
        partials: {},
        types_header: 'drivers/uart/ceedling_partial_config_types.h'
      )

      expect(result.map(&:filepath)).to eq(
        ['header1.h', 'drivers/uart/ceedling_partial_config_types.h', 'header2.h']
      )
    end

    it "removes another partialized module's header when that module is named by directory" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('other.h')]

      result = @partializer.remap_implementation_header_includes(
        name: 'drivers/uart/config',
        includes: includes,
        partials: { 'drivers/spi/other' => nil }
      )

      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    it "removes partialized module headers from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => { types: [:test_public] }
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "removes multiple partialized module headers" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial1.h'), 
        UserInclude.new('partial2.h'), 
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial1' => nil,
        'partial2' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "preserves includes that are not partialized" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial_module.h'), 
        UserInclude.new('header2.h'), 
        UserInclude.new('header3.h')
      ]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array(
        [
          UserInclude.new('header1.h'), 
          UserInclude.new('header2.h'), 
          UserInclude.new('header3.h')
        ]
      )
    end

    it "removes duplicates after removing partialized headers" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial_module.h'), 
        UserInclude.new('header1.h'), 
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles case-insensitive module header removal" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('MODULE.H'),
        UserInclude.new('header2.h')
      ]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles partials with different configuration types" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial1.h'), 
        UserInclude.new('partial2.h'), 
        UserInclude.new('partial3.h')
      ]
      partials = {
        'partial1' => nil,
        'partial2' => nil,
        'partial3' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    it "handles empty partials hash" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('module.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles complex scenario with module header, partials, and duplicates" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header3.h')
      ]
      partials = {
        'partial1' => nil,
        'partial2' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array(
        [
          UserInclude.new('header1.h'),
          UserInclude.new('header2.h'),
          UserInclude.new('header3.h')
        ]
      )
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "appends the shared types header when one was generated for this module" do
      includes = [UserInclude.new('header1.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials,
        types_header: 'ceedling_partial_module_types.h'
      )

      expect(result).to include(UserInclude.new('ceedling_partial_module_types.h'))
    end

    it "does not append a types header when the module has none" do
      includes = [UserInclude.new('header1.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )

      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    # The shared types header's own top-of-file guard-spoofing macro must
    # be defined before anything later in the list gets a chance to transitively
    # re-include this module's real header a second, unguarded way -- splicing the
    # types header in at the module's own original position (rather than appending it
    # after everything else) is what guarantees that ordering.
    it "splices the shared types header in at the module's own original list position, not at the end" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('header2.h')
      ]
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: {},
        types_header: 'ceedling_partial_module_types.h'
      )

      expect(result).to eq([
        UserInclude.new('header1.h'),
        UserInclude.new('ceedling_partial_module_types.h'),
        UserInclude.new('header2.h')
      ])
    end

    it "appends the shared types header when the module's own header wasn't in the includes list to begin with" do
      includes = [UserInclude.new('header1.h')]
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: {},
        types_header: 'ceedling_partial_module_types.h'
      )

      expect(result).to eq([
        UserInclude.new('header1.h'),
        UserInclude.new('ceedling_partial_module_types.h')
      ])
    end
  end

  ###
  ### remap_interface_header_includes()
  ###

  context "#remap_interface_header_includes" do
    it "returns empty array when input is empty and no partials" do
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: [],
        partials: {}
      )
      expect(result).to eq([])
    end

    it "removes module's own header from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h')]
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: {}
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
    end

    it "removes partialized module headers from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = { 'partial_module' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "removes multiple partialized module headers" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header2.h')
      ]
      partials = { 'partial1' => nil, 'partial2' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "preserves includes that are not partialized" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('header3.h')
      ]
      partials = { 'partial_module' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([
        UserInclude.new('header1.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('header3.h')
      ])
    end

    it "removes duplicates after removing partialized headers" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header2.h')
      ]
      partials = { 'partial_module' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles case-insensitive module header removal" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('MODULE.H'),
        UserInclude.new('header2.h')
      ]
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: {}
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles partials with different configuration types" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('partial3.h')
      ]
      partials = { 'partial1' => nil, 'partial2' => nil, 'partial3' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    it "handles empty partials hash" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('module.h')]
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: {}
      )
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles complex scenario with module header, partials, and duplicates" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header3.h')
      ]
      partials = { 'partial1' => nil, 'partial2' => nil }
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      expect(result).to match_array([
        UserInclude.new('header1.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('header3.h')
      ])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "appends the shared types header when one was generated for this module" do
      includes = [UserInclude.new('header1.h')]
      partials = {}
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials,
        types_header: 'ceedling_partial_module_types.h'
      )

      expect(result).to include(UserInclude.new('ceedling_partial_module_types.h'))
    end

    it "does not append a types header when the module has none" do
      includes = [UserInclude.new('header1.h')]
      partials = {}
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )

      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    # See the matching example in #remap_implementation_header_includes for the full
    # rationale; the mockable interface header needs the identical ordering guarantee.
    it "splices the shared types header in at the module's own original list position, not at the end" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('header2.h')
      ]
      result = @partializer.remap_interface_header_includes(
        name: 'module',
        includes: includes,
        partials: {},
        types_header: 'ceedling_partial_module_types.h'
      )

      expect(result).to eq([
        UserInclude.new('header1.h'),
        UserInclude.new('ceedling_partial_module_types.h'),
        UserInclude.new('header2.h')
      ])
    end
  end

  ###
  ### remap_implementation_source_includes()
  ###

  context "#remap_implementation_source_includes" do
    # A module tested and mocked in one test file splits its own content across two generated
    # headers: the implementation carries the public bodies and the interface declares the
    # private functions those bodies call. The generated source needs both, so this module's own
    # interface header belongs in its own include list. wondrous_forest's ForestMonitor is
    # exactly this shape, and dropping the entry leaves its private transition function
    # undeclared at compile time.
    it "carries this module's own interface header when it is also mocked" do
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module').and_return('ceedling_partial_module_impl.h')
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('module').and_return('ceedling_partial_module_interface.h')

      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: [UserInclude.new('module.h')],
        partials: { 'module' => make_partial_config(tests_type: :public, mocks_type: :private) }
      )

      expect( result.map( &:filename ) ).to eq(
        ['ceedling_partial_module_impl.h', 'ceedling_partial_module_interface.h']
      )
    end

    it "carries no interface header for a module that is tested but not mocked" do
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module').and_return('ceedling_partial_module_impl.h')

      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: [UserInclude.new('module.h')],
        partials: { 'module' => make_partial_config(tests_type: :public) }
      )

      expect( result.map( &:filename ) ).to eq(['ceedling_partial_module_impl.h'])
    end

    it "returns implementation header when input is empty and no partials" do
      includes = []
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([impl_header])
    end

    it "adds implementation header to includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h')]
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "removes module's own header from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h')]
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('module.h'))
    end

    it "remaps mockable public partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "remaps mockable private partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::PRIVATE)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    # Regression test for #1215: PUBLIC/PRIVATE were once the only mock modes that existed,
    # so this method's own "does this module have a mock to redirect to" check only ever
    # listed those two. DEDUCT (MOCK_PARTIAL_ALL_MODULE) was added later without updating
    # this check, so a module mocked via MOCK_PARTIAL_ALL_MODULE -- e.g. a vendor header
    # whose only mockable functions are static inline, which requires DEDUCT to select at
    # all -- was silently never redirected to its mock interface header.
    it "remaps mockable deduct (ALL_MODULE) partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::DEDUCT)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)

      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)

      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)

      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )

      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    # Same regression as the DEDUCT case above, for ACCUMULATE (MOCK_PARTIAL_MODULE).
    it "remaps mockable accumulate partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::ACCUMULATE)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)

      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)

      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)

      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )

      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "remaps multiple mockable partials to interface headers" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial1' => make_partial_config(mocks_type: Partials::PUBLIC),
        'partial2' => make_partial_config(mocks_type: Partials::PRIVATE)
      }
      impl_filename = 'module_impl.h'
      interface_filename1 = 'partial1_module_interface.h'
      interface_filename2 = 'partial2_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header1 = UserInclude.new(interface_filename1)
      interface_header2 = UserInclude.new(interface_filename2)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface_filename1)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial2')
        .and_return(interface_filename2)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include(interface_header2)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "remaps testable partial to implementation header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => make_partial_config(tests_type: Partials::PUBLIC)
      }
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('partial_module.h'))
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "remaps mix of mockable and testable partials" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial1' => make_partial_config(mocks_type: Partials::PUBLIC),
        'partial2' => make_partial_config(tests_type: Partials::PRIVATE)
      }
      impl_filename = 'module_impl.h'
      interface1_filename = 'partial1_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header1 = UserInclude.new(interface1_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface1_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include(UserInclude.new('partial2.h'))
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
    end

    it "removes duplicates after remapping" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)

      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)

      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)

      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )

      expect(result.count(UserInclude.new('header1.h'))).to eq(1)
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "handles case-insensitive module header removal" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('MODULE.H'),
        UserInclude.new('header2.h')
      ]
      partials = {}
      filename ='module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles case-insensitive partial module remapping" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('PARTIAL_MODULE.H'),
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
      expect(result).not_to include(UserInclude.new('PARTIAL_MODULE.H'))
    end
  end

  ###
  ### remap_types_header_includes()
  ###

  context "#remap_types_header_includes" do
    # Nothing replaces this module's own header here. The types header cannot include itself, so
    # its own entry is simply dropped.
    it "drops the module's own header without substituting anything" do
      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('module.h'), UserInclude.new('foundation.h')],
        partials: {}
      )

      expect( result ).to eq([UserInclude.new('foundation.h')])
    end

    it "keeps every other include in its original relative order" do
      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('first.h'), UserInclude.new('module.h'), UserInclude.new('last.h')],
        partials: {}
      )

      expect( result.map( &:filename ) ).to eq(['first.h', 'last.h'])
    end

    # Another partialized module's real header would reintroduce exactly the content that
    # module's own Partial replaced, so a mocked one is redirected to its generated interface
    # header and an unmocked one is dropped.
    it "redirects a mocked partialized dependency to its interface header" do
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('other')
        .and_return('ceedling_partial_other_interface.h')

      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('module.h'), UserInclude.new('other.h')],
        partials: { 'other' => make_partial_config(mocks_type: :public) }
      )

      expect( result.map( &:filename ) ).to eq(['ceedling_partial_other_interface.h'])
    end

    it "drops a partialized dependency that is not mocked" do
      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('module.h'), UserInclude.new('other.h')],
        partials: { 'other' => make_partial_config(tests_type: :public) }
      )

      expect( result ).to be_empty
    end

    # Comparing a module name to an include means comparing names, and GH #1266 was that going
    # wrong. A header whose basename merely extends the module's is a different file.
    it "leaves a header whose name only extends a partialized module's name" do
      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('module.h'), UserInclude.new('other_extra.h'), UserInclude.new('other.h')],
        partials: { 'other' => make_partial_config(tests_type: :public) }
      )

      expect( result.map( &:filename ) ).to eq(['other_extra.h'])
    end

    # The interface header includes the types header, so carrying it back into the types header
    # would fold that file's function declarations into this one. wondrous_forest's
    # ForestMonitor is tested and mocked at once, which is the shape that makes this matter.
    it "never carries this module's own interface header, even when it is also mocked" do
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .and_return('ceedling_partial_module_interface.h')

      result = @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('module.h'), UserInclude.new('foundation.h')],
        partials: { 'module' => make_partial_config(tests_type: :public, mocks_type: :private) }
      )

      expect( result.map( &:filename ) ).to eq(['foundation.h'])
    end

    it "logs the carried list under its own noun when a test is named" do
      expect(@loginator).to receive(:log_list).with(
        anything,
        'Dependency includes to carry into the shared types header for Partial a_test::module:',
        Verbosity::OBNOXIOUS
      )

      @partializer.remap_types_header_includes(
        name: 'module',
        includes: [UserInclude.new('foundation.h')],
        partials: {},
        test: 'a_test'
      )
    end
  end

  ###
  ### extract_module_contents()
  ###

  context "#extract_module_contents" do
    before(:each) do
      @name = 'TestModule'

      # associate_function_line_numbers is called for every file processed; stub by default
      allow(@partializer_helper).to receive(:associate_function_line_numbers)
      # Each file's raw directives-only copy is absent unless an example provides it
      allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath) { |path, _test| "raw/#{path}" }
      allow(@file_wrapper).to receive(:exist?).and_return(false)
      # static var extraction/promotion called for every file processed; stub by default
      allow(@partializer_helper).to receive(:extract_function_scope_static_vars).and_return([])
    end

    it "returns empty CModule when both directives_only_filepaths are nil" do
      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', directives_only_filepath: nil)
      )

      expect(@c_extractor).not_to receive(:from_file)
      expect(@partializer_helper).not_to receive(:associate_function_line_numbers)
      expect(@partializer_helper).not_to receive(:extract_function_scope_static_vars)

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.function_definitions).to eq([])
      expect(result.variable_declarations).to eq([])
    end

    it "extracts contents from header preprocessed file only" do
      header_funcs = [
        CExtractorTypes::CFunctionDefinition.new(name: 'func1', signature: 'void func1(void)'),
        CExtractorTypes::CFunctionDefinition.new(name: 'func2', signature: 'int func2(int x)')
      ]
      header_contents = CExtractorTypes::CModule.new(function_definitions: header_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', directives_only_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil)
      )

      expect(@c_extractor).to receive(:from_file).with('/build/preproc/header.i').and_return(header_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: header_funcs, filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.function_definitions).to eq(header_funcs)
      expect(result.variable_declarations).to eq([])
    end

    it "extracts contents from source preprocessed file only" do
      source_funcs = [
        CExtractorTypes::CFunctionDefinition.new(name: 'func1', signature: 'static void func1(void)'),
        CExtractorTypes::CFunctionDefinition.new(name: 'func2', signature: 'static int func2(int x)')
      ]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', directives_only_filepath: '/build/preproc/source.i')
      )

      expect(@c_extractor).to receive(:from_file).with('/build/preproc/source.i').and_return(source_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/path/to/source.c', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.function_definitions).to eq(source_funcs)
      expect(result.variable_declarations).to eq([])
    end

    it "extracts and merges contents from both source and header preprocessed files" do
      source_funcs = [
        CExtractorTypes::CFunctionDefinition.new(name: 'func1', signature: 'static void func1(void)'),
        CExtractorTypes::CFunctionDefinition.new(name: 'func2', signature: 'static int func2(int x)')
      ]
      header_funcs = [
        CExtractorTypes::CFunctionDefinition.new(name: 'func3', signature: 'void func3(void)'),
        CExtractorTypes::CFunctionDefinition.new(name: 'func4', signature: 'int func4(int x)')
      ]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [CExtractorTypes::CVariableDeclaration.new(name: 'var1')])
      header_contents = CExtractorTypes::CModule.new(function_definitions: header_funcs, variable_declarations: [CExtractorTypes::CVariableDeclaration.new(name: 'var2')])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', directives_only_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', directives_only_filepath: '/build/preproc/source.i')
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/source.i').and_return(source_contents)
      allow(@c_extractor).to receive(:from_file).with('/build/preproc/header.i').and_return(header_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/path/to/source.c', fallback: false
      )
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: header_funcs, filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.function_definitions).to eq(header_funcs + source_funcs)
      expect(result.variable_declarations).to eq(header_contents.variable_declarations + source_contents.variable_declarations)
    end

    it "calls associate_function_line_numbers with the preprocessed expansion filepath, not the preprocessed filepath" do
      source_funcs = [CExtractorTypes::CFunctionDefinition.new(name: 'func1')]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', directives_only_filepath: '/build/preproc/module1.i')
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)

      # associate_function_line_numbers must receive the original filepath, not the preprocessed one
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/src/module1.c', fallback: false
      )

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    it "passes extraction name through to associate_function_line_numbers" do
      source_funcs = [CExtractorTypes::CFunctionDefinition.new(name: 'func1')]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', directives_only_filepath: '/build/preproc/module1.i')
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)

      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: 'SpecificTestName', funcs: source_funcs, filepath: '/src/module1.c', fallback: false
      )

      @partializer.extract_module_contents('SpecificTestName', config, fallback: false)
    end

    it "returns empty CModule when a preprocessed file has no contents" do
      empty_contents = CExtractorTypes::CModule.new(function_definitions: [], variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', directives_only_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil)
      )

      expect(@c_extractor).to receive(:from_file).and_return(empty_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: [], filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.function_definitions).to eq([])
      expect(result.variable_declarations).to eq([])
    end

    it "appends promoted function-scope static variables to element_sequence" do
      promoted_var1 = CExtractorTypes::CVariableDeclaration.new(text: 'static int counter = 0;', type: 'int', name: 'counter')
      promoted_var2 = CExtractorTypes::CVariableDeclaration.new(text: 'static bool flag = false;', type: 'bool', name: 'flag')

      source_contents = CExtractorTypes::CModule.new(function_definitions: [], variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', directives_only_filepath: '/build/preproc/module1.i')
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)
      allow(@partializer_helper).to receive(:extract_function_scope_static_vars).and_return([promoted_var1, promoted_var2])

      result = @partializer.extract_module_contents(@name, config, fallback: false)

      expect(result.element_sequence).to eq([promoted_var1, promoted_var2])
      expect(result.element_sequence[0]).to equal(promoted_var1)
      expect(result.element_sequence[1]).to equal(promoted_var2)
    end

    it "calls update_signatures_from_full_expansion when full_expansion_filepath is set on source" do
      source_funcs    = [CExtractorTypes::CFunctionDefinition.new(name: 'func1')]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(
          filepath:               '/src/module1.c',
          directives_only_filepath: '/build/preproc/module1.i',
          full_expansion_filepath:  '/build/preproc/full_expansion/module1.c'
        )
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/module1.i').and_return(source_contents)
      allow(@partializer_helper).to receive(:associate_function_line_numbers)

      expect(@partializer_helper).to receive(:update_signatures_from_full_expansion).with(
        funcs:                   source_funcs,
        decls:                   [],
        full_expansion_filepath: '/build/preproc/full_expansion/module1.c',
        name:                    @name,
        module_name:             'module1',
        file_type:               'source'
      )

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    it "calls update_signatures_from_full_expansion when full_expansion_filepath is set on header" do
      header_funcs    = [CExtractorTypes::CFunctionDefinition.new(name: 'func1')]
      header_contents = CExtractorTypes::CModule.new(function_definitions: header_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(
          filepath:               '/path/to/header.h',
          directives_only_filepath: '/build/preproc/header.h',
          full_expansion_filepath:  '/build/preproc/full_expansion/header.h'
        ),
        source: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil)
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/header.h').and_return(header_contents)
      allow(@partializer_helper).to receive(:associate_function_line_numbers)

      expect(@partializer_helper).to receive(:update_signatures_from_full_expansion).with(
        funcs:                   header_funcs,
        decls:                   [],
        full_expansion_filepath: '/build/preproc/full_expansion/header.h',
        name:                    @name,
        module_name:             'module1',
        file_type:               'header'
      )

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    it "does not call update_signatures_from_full_expansion when full_expansion_filepath is nil" do
      source_funcs    = [CExtractorTypes::CFunctionDefinition.new(name: 'func1')]
      source_contents = CExtractorTypes::CModule.new(function_definitions: source_funcs, variable_declarations: [])

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(
          filepath:               '/src/module1.c',
          directives_only_filepath: '/build/preproc/module1.i',
          full_expansion_filepath:  nil
        )
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/module1.i').and_return(source_contents)
      allow(@partializer_helper).to receive(:associate_function_line_numbers)

      expect(@partializer_helper).not_to receive(:update_signatures_from_full_expansion)

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    it "passes each file's declarations to update_signatures_from_full_expansion" do
      decls           = [CExtractorTypes::CFunctionDeclaration.new(name: 'tick', signature: 'int tick(void);')]
      source_contents = CExtractorTypes::CModule.new(function_declarations: decls)

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
        source: Partials::ConfigFileInfo.new(
          filepath:                 '/src/module1.c',
          directives_only_filepath: '/build/preproc/module1.i',
          full_expansion_filepath:  '/build/preproc/full_expansion/module1.c'
        )
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)

      expect(@partializer_helper).to receive(:update_signatures_from_full_expansion).with(
        hash_including( decls: decls )
      )

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    # Locating declarations costs a search of the file's text each, so only carried ones are located
    it "leaves declarations unlocated during extraction" do
      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/src/module1.h', directives_only_filepath: '/build/preproc/module1.h'),
        source: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil)
      )
      decls = [CExtractorTypes::CFunctionDeclaration.new(name: 'tick', signature: 'int tick(void);')]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: decls))

      expect(@partializer_helper).not_to receive(:associate_declaration_line_numbers)
      expect(@file_wrapper).not_to receive(:read)

      @partializer.extract_module_contents(@name, config, fallback: false)
    end

    context "marking functions an included header defines inline" do
      let(:config) do
        PartializerConfig::Config.new(
          module: 'engine',
          header: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil),
          source: Partials::ConfigFileInfo.new(filepath: 'src/engine.c', directives_only_filepath: '/build/preproc/engine.c')
        )
      end
      let(:twice) { CExtractorTypes::CFunctionDeclaration.new( name: 'engine_get_twice', signature: 'int engine_get_twice(void);' ) }
      let(:both_files) do
        PartializerConfig::Config.new(
          module: 'engine',
          header: Partials::ConfigFileInfo.new(filepath: 'src/engine.h', directives_only_filepath: '/build/preproc/engine.h'),
          source: Partials::ConfigFileInfo.new(filepath: 'src/engine.c', directives_only_filepath: '/build/preproc/engine.c')
        )
      end

      # The raw copy holds every header the file includes, so the inline body is found there.
      # The scan needs only bytes, so the copy is never transcoded.
      it "marks a source declaration against the source's raw copy, read as bytes" do
        allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [twice]))
        allow(@file_wrapper).to receive(:exist?).with('raw/src/engine.c').and_return(true)
        allow(@file_wrapper).to receive(:read_binary).with('raw/src/engine.c').and_return('raw bytes')

        expect(@partializer_helper).to receive(:mark_inline_elsewhere).with( decls: [twice], text: 'raw bytes' )
        expect(@file_wrapper).not_to receive(:read)
        expect(@file_path_utils).not_to receive(:form_preprocessed_file_raw_directives_only_filepath).with(nil, anything)

        @partializer.extract_module_contents(@name, config, fallback: false)
      end

      # A module mocked from its header alone has no source, and every declaration is the header's
      it "marks a header-only Partial's declarations against the header's raw copy" do
        header_only = PartializerConfig::Config.new(
          module: 'engine',
          header: Partials::ConfigFileInfo.new(filepath: 'src/engine.h', directives_only_filepath: '/build/preproc/engine.h'),
          source: Partials::ConfigFileInfo.new(filepath: nil, directives_only_filepath: nil)
        )
        allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [twice]))
        allow(@file_wrapper).to receive(:exist?).with('raw/src/engine.h').and_return(true)
        allow(@file_wrapper).to receive(:read_binary).with('raw/src/engine.h').and_return('header bytes')

        expect(@partializer_helper).to receive(:mark_inline_elsewhere).with( decls: [twice], text: 'header bytes' )
        expect(@file_path_utils).not_to receive(:form_preprocessed_file_raw_directives_only_filepath).with(nil, anything)

        @partializer.extract_module_contents(@name, header_only, fallback: false)
      end

      # Each file's raw copy holds the headers that file includes, so each is searched for its own
      it "marks each file's declarations against that file's own raw copy" do
        tick = CExtractorTypes::CFunctionDeclaration.new( name: 'board_tick', signature: 'int board_tick(void);' )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.h').and_return(
          CExtractorTypes::CModule.new(function_declarations: [tick])
        )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.c').and_return(
          CExtractorTypes::CModule.new(function_declarations: [twice])
        )
        allow(@file_wrapper).to receive(:exist?).and_return(true)
        allow(@file_wrapper).to receive(:read_binary).with('raw/src/engine.h').and_return('header bytes')
        allow(@file_wrapper).to receive(:read_binary).with('raw/src/engine.c').and_return('source bytes')

        expect(@partializer_helper).to receive(:mark_inline_elsewhere).with( decls: [tick], text: 'header bytes' )
        expect(@partializer_helper).to receive(:mark_inline_elsewhere).with( decls: [twice], text: 'source bytes' )

        @partializer.extract_module_contents(@name, both_files, fallback: false)
      end

      # Only a function the module has no body for can be defined inline elsewhere
      it "marks only the header declarations whose function has no body in the module" do
        get  = CExtractorTypes::CFunctionDeclaration.new( name: 'engine_get', signature: 'int engine_get(void);' )
        tick = CExtractorTypes::CFunctionDeclaration.new( name: 'board_tick', signature: 'int board_tick(void);' )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.h').and_return(
          CExtractorTypes::CModule.new(function_declarations: [get, tick])
        )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.c').and_return(
          CExtractorTypes::CModule.new(function_definitions: [CExtractorTypes::CFunctionDefinition.new(name: 'engine_get')])
        )
        allow(@file_wrapper).to receive(:exist?).and_return(true)
        allow(@file_wrapper).to receive(:read_binary).with('raw/src/engine.h').and_return('header bytes')

        expect(@partializer_helper).to receive(:mark_inline_elsewhere).with( decls: [tick], text: 'header bytes' ).once

        @partializer.extract_module_contents(@name, both_files, fallback: false)
      end

      it "reads no file when every declaration's function has a body in the module" do
        get = CExtractorTypes::CFunctionDeclaration.new( name: 'engine_get', signature: 'int engine_get(void);' )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.h').and_return(
          CExtractorTypes::CModule.new(function_declarations: [get])
        )
        allow(@c_extractor).to receive(:from_file).with('/build/preproc/engine.c').and_return(
          CExtractorTypes::CModule.new(function_definitions: [CExtractorTypes::CFunctionDefinition.new(name: 'engine_get')])
        )

        expect(@file_wrapper).not_to receive(:exist?)
        expect(@file_wrapper).not_to receive(:read_binary)
        expect(@partializer_helper).not_to receive(:mark_inline_elsewhere)

        @partializer.extract_module_contents(@name, both_files, fallback: false)
      end

      it "reads no file and marks nothing without a raw copy" do
        allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [twice]))

        expect(@file_wrapper).not_to receive(:read_binary)
        expect(@partializer_helper).not_to receive(:mark_inline_elsewhere)

        @partializer.extract_module_contents(@name, config, fallback: false)
      end

      # Fallback writes no raw copy, so any copy on disk is stale
      it "marks nothing under fallback preprocessing, even when a raw copy remains" do
        allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [twice]))
        allow(@file_wrapper).to receive(:exist?).and_return(true)

        expect(@file_wrapper).not_to receive(:read_binary)
        expect(@partializer_helper).not_to receive(:mark_inline_elsewhere)

        @partializer.extract_module_contents(@name, config, fallback: true)
      end

      it "reads no file when the file declares no function" do
        allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new)

        expect(@file_wrapper).not_to receive(:exist?)

        @partializer.extract_module_contents(@name, config, fallback: false)
      end
    end

    it "stamps every function with the role of the file it came from" do
      header_def  = CExtractorTypes::CFunctionDefinition.new(name: 'clamp')
      header_decl = CExtractorTypes::CFunctionDeclaration.new(name: 'tick')
      source_def  = CExtractorTypes::CFunctionDefinition.new(name: 'get')
      source_decl = CExtractorTypes::CFunctionDeclaration.new(name: 'twice')

      config = PartializerConfig::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/src/module1.h', directives_only_filepath: '/build/preproc/module1.h'),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', directives_only_filepath: '/build/preproc/module1.c')
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/module1.h').and_return(
        CExtractorTypes::CModule.new(function_definitions: [header_def], function_declarations: [header_decl])
      )
      allow(@c_extractor).to receive(:from_file).with('/build/preproc/module1.c').and_return(
        CExtractorTypes::CModule.new(function_definitions: [source_def], function_declarations: [source_decl])
      )

      @partializer.extract_module_contents(@name, config, fallback: false)

      expect([header_def, header_decl].map(&:origin)).to all(eq(:header))
      expect([source_def, source_decl].map(&:origin)).to all(eq(:source))
    end
  end

  ###
  ### extract_implementation_functions()
  ###

  def make_pf(type: nil, additions: [], subtractions: [])
    OpenStruct.new(type: type, additions: additions, subtractions: subtractions)
  end

  def make_config(tests: make_pf, mocks: make_pf)
    OpenStruct.new(tests: tests, mocks: mocks)
  end

  context "#extract_implementation_functions" do
    it "returns nil when config tests type is nil" do
      defs = []
      pf   = make_pf

      expect(@partializer_helper).not_to receive(:find_and_transform_func)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, nil, :impl).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to be_nil
    end

    it "delegates initial list to filter_and_transform_funcs for PUBLIC type" do
      defs     = [double('func1', name: 'pub')]
      filtered = [double('impl_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates initial list to filter_and_transform_funcs for PRIVATE type" do
      defs     = [double('func1', name: 'priv')]
      filtered = [double('impl_func')]
      pf       = make_pf(type: Partials::PRIVATE)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PRIVATE, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "fills list from additions only for ACCUMULATE type" do
      defs  = [double('func1', name: 'named')]
      found = double('impl_func', name: 'named')
      pf    = make_pf(type: Partials::ACCUMULATE, additions: ['named'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::ACCUMULATE, :impl).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'named', primary_funcs: defs, secondary_funcs: [], output_type: :impl)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq([found])
    end

    it "adds cross-visibility function from additions to initial list" do
      pub_func  = double('pub',  name: 'pub')
      priv_func = double('priv', name: 'priv')
      defs      = [pub_func, priv_func]
      filtered  = [double('impl_pub', name: 'pub')]
      added     = double('impl_priv', name: 'priv')
      pf        = make_pf(type: Partials::PUBLIC, additions: ['priv'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'priv', primary_funcs: defs, secondary_funcs: [], output_type: :impl)
        .and_return(added)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [filtered[0], added], names: []).and_return([filtered[0], added])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to include(filtered[0], added)
    end

    it "skips addition when function already in initial list (dedup)" do
      func     = double('impl_pub', name: 'pub')
      defs     = [double('def', name: 'pub')]
      filtered = [func]
      pf       = make_pf(type: Partials::PUBLIC, additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).not_to receive(:find_and_transform_func)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates subtractions to subtract_funcs" do
      defs     = [double('func', name: 'pub')]
      filtered = [double('impl_pub', name: 'pub')]
      pf       = make_pf(type: Partials::PUBLIC, subtractions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq([])
    end

    it "subtracts mocks.additions from the impl result" do
      defs     = [double('func', name: 'pub')]
      filtered = [double('impl_pub', name: 'pub')]
      test_pf  = make_pf(type: Partials::PUBLIC)
      mock_pf  = make_pf(additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs,
        config: make_config(tests: test_pf, mocks: mock_pf)
      )
      expect(result).to eq([])
    end
  end

  ###
  ### extract_interface_functions()
  ###

  context "#extract_interface_functions" do
    it "returns nil when config mocks type is nil" do
      defs  = []
      decls = []
      pf    = make_pf

      expect(@partializer_helper).not_to receive(:find_and_transform_func)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, nil, :interface).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to be_nil
    end

    it "delegates initial list to filter_and_transform_funcs for PUBLIC type" do
      defs     = [double('func1', name: 'pub')]
      decls    = []
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates initial list to filter_and_transform_funcs for PRIVATE type" do
      defs     = [double('func1', name: 'priv')]
      decls    = []
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PRIVATE)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PRIVATE, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "merges declaration-only functions into the DEDUCT candidate pool" do
      defn     = double('inline_func', name: 'inline_fn')
      decl     = double('proto_func', name: 'proto_fn', decorators: [], inline_elsewhere: false)
      defs     = [defn]
      decls    = [decl]
      filtered = [double('iface_inline'), double('iface_proto')]
      pf       = make_pf(type: Partials::DEDUCT)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with([defn, decl], Partials::DEDUCT, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "merges declaration-only functions into the PUBLIC candidate pool too" do
      defn     = double('def_func', name: 'pub_def')
      decl     = double('decl_func', name: 'pub_decl', decorators: [], inline_elsewhere: false)
      defs     = [defn]
      decls    = [decl]
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with([defn, decl], Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    # Its body lives in a header the module includes, so a mock could never replace it. Mocking
    # it would only define the function twice.
    [Partials::DEDUCT, Partials::PRIVATE].each do |type|
      it "keeps a declaration-only inline function out of the #{type} candidate pool" do
        defn     = double('def_func', name: 'engine_get')
        foreign  = double('extern_inline', name: 'engine_get_twice', decorators: ['extern', 'inline'])
        filtered = [double('iface_func')]
        pf       = make_pf(type: type)

        expect(@partializer_helper).to receive(:filter_and_transform_funcs)
          .with([defn], type, :interface).and_return(filtered)
        allow(@partializer_helper).to receive(:subtract_funcs).and_return(filtered)

        @partializer.extract_interface_functions(
          test: 'test_mod', partial: 'mod',
          definitions: [defn], declarations: [foreign], config: make_config(mocks: pf)
        )
      end
    end

    # Declared without `inline`, it is still a function whose body another header holds
    it "keeps a declaration of a function another header defines inline out of the PUBLIC candidate pool" do
      defn     = double('def_func', name: 'engine_get')
      foreign  = CExtractorTypes::CFunctionDeclaration.new(
        name: 'engine_get_twice', signature: 'int engine_get_twice(void);', inline_elsewhere: true
      )
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with([defn], Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs).and_return(filtered)

      @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: [defn], declarations: [foreign], config: make_config(mocks: pf)
      )
    end

    it "lists a declaration-only inline function it keeps out, at debug verbosity" do
      foreign = double('extern_inline', name: 'engine_get_twice', decorators: ['extern', 'inline'])
      pf      = make_pf(type: Partials::DEDUCT)
      allow(@partializer_helper).to receive(:filter_and_transform_funcs).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs).and_return([])

      expect(@loginator).to receive(:log_list).with(
        ['`engine_get_twice`'],
        'Not mockable for Partial test_mod::mod (inline, body outside module):',
        Verbosity::DEBUG
      )

      @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: [], declarations: [foreign], config: make_config(mocks: pf)
      )
    end

    it "excludes a declaration already present as a definition with the same name (dedup)" do
      defn     = double('def_func', name: 'shared')
      decl     = double('decl_func', name: 'shared', decorators: [], inline_elsewhere: false) # e.g. header prototype for the same function
      defs     = [defn]
      decls    = [decl]
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::DEDUCT)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with([defn], Partials::DEDUCT, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "fills list from additions only for ACCUMULATE type" do
      defs   = [double('def', name: 'named')]
      decls  = []
      found  = double('iface_func', name: 'named')
      pf     = make_pf(type: Partials::ACCUMULATE, additions: ['named'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::ACCUMULATE, :interface).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'named', primary_funcs: defs, secondary_funcs: decls, output_type: :interface)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq([found])
    end

    it "searches definitions then declarations for additions" do
      defs  = []
      decls = [double('decl', name: 'decl_only', decorators: [], inline_elsewhere: false)]
      found = double('iface_func', name: 'decl_only')
      pf    = make_pf(type: Partials::ACCUMULATE, additions: ['decl_only'])

      # candidates = definitions + declarations (ACCUMULATE ignores this list regardless --
      # it always starts empty -- but it's still built before the type check discards it).
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(decls, Partials::ACCUMULATE, :interface).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'decl_only', primary_funcs: defs, secondary_funcs: decls, output_type: :interface)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to include(found)
    end

    it "skips addition when function already in initial list (dedup)" do
      func     = double('iface_pub', name: 'pub')
      defs     = [double('def', name: 'pub')]
      decls    = []
      filtered = [func]
      pf       = make_pf(type: Partials::PUBLIC, additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      expect(@partializer_helper).not_to receive(:find_and_transform_func)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates subtractions to subtract_funcs" do
      defs     = [double('func', name: 'pub')]
      decls    = []
      filtered = [double('iface_pub', name: 'pub')]
      pf       = make_pf(type: Partials::PUBLIC, subtractions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq([])
    end

    it "subtracts tests.additions from the interface result" do
      defs     = [double('func', name: 'pub')]
      decls    = []
      filtered = [double('iface_pub', name: 'pub')]
      mock_pf  = make_pf(type: Partials::PUBLIC)
      test_pf  = make_pf(additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls,
        config: make_config(tests: test_pf, mocks: mock_pf)
      )
      expect(result).to eq([])
    end
  end


  # A module named with a backslash separator still names a directory. Elsewhere this
  # codebase treats either separator as a separator, and the qualifier validation already
  # rejects a backslash-rooted absolute path, so detection has to agree.
  describe 'a module named with a backslash separator' do
    it 'is treated as naming a directory' do
      expect( @partializer.send(:_names_directory?, 'drivers\\uart/config') ).to be true
    end

    it 'is treated as naming a directory when backslash is the only separator' do
      expect( @partializer.send(:_names_directory?, 'drivers\\config') ).to be true
    end

    it 'leaves a bare module name naming none' do
      expect( @partializer.send(:_names_directory?, 'config') ).to be false
    end
  end
end