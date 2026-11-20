# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Each toolchain family's wording, the gating and the prescription's shape. Real compilers'
# output is in spec/integration/build_step_doctor_spec.rb.

require 'spec_helper'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/partial_name_specialist'
require 'ceedling/test_invoker/test_invoker_types'

describe PartialNameSpecialist do
  before(:each) do
    @configurator = double( 'configurator', project_use_partials: true )
    @file_wrapper = double( 'file_wrapper', directory_listing: [] )
    @loginator    = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    nobody = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: nobody, missing_symbol_specialist: nobody, duplicate_symbol_specialist: nobody,
      partial_name_specialist: described_class.new( configurator: @configurator, file_wrapper: @file_wrapper ),
      include_depth_specialist: nobody
    ).tap( &:setup )

    @testable = TestInvokerTypes::Testable.new( name: 'test_ticker', filepath: 'test/test_ticker.c', paths: { partials: 'build/test/partials/test_ticker' } )
  end

  def prescriptions(output, source: 'test/test_ticker.c', step: :compile)
    @doctor.diagnose( step: step, output: output, inputs: { testable: @testable, source: source } )
  end

  GCC_LOCAL = "test/test_ticker.c:9:5: error: 'partial_tick_cnt' undeclared (first use in this function)\n"
  GCC_TYPE  = "test/test_ticker.c:9:5: error: unknown type name 'ceedling_partial_ticker_ctx_t'\n"

  {
    'GCC'                         => GCC_LOCAL,
    'Clang'                       => "test/test_ticker.c:9:5: error: use of undeclared identifier 'partial_tick_cnt'\n",
    'MSVC'                        => "test\\test_ticker.c(9): error C2065: 'partial_tick_cnt': undeclared identifier\n",
    'EDG (IAR)'                   => "Error[Pe020]: identifier \"partial_tick_cnt\" is undefined\n",
    'EDG (TI, Arm, Green Hills)'  => "\"test/test_ticker.c\", line 9: error #20: identifier \"partial_tick_cnt\" is undefined\n",
    'SDCC'                        => "test/test_ticker.c:9: error 20: Undefined identifier 'partial_tick_cnt'\n",
    'other compilers, generically' => "test_ticker.c 9: partial_tick_cnt not declared\n"
  }.each do |family, output|
    it "recognizes #{family} reporting a promoted variable's name" do
      expect( prescriptions( output ).size ).to eq( 1 )
    end
  end

  {
    'GCC and Clang' => GCC_TYPE,
    'MSVC'          => "test\\test_ticker.c(9): error C2061: syntax error: identifier 'ceedling_partial_ticker_ctx_t'\n",
    'EDG'           => "Error[Pe020]: identifier \"ceedling_partial_ticker_ctx_t\" is undefined\n"
  }.each do |family, output|
    it "recognizes #{family} reporting a Partial type's name" do
      expect( prescriptions( output ).first ).to include( 'PARTIAL_TYPE()' )
    end
  end

  # A compiler reports the name the macro built, and often the macro on a note of its own
  it 'recognizes the macro a note names when the name itself reads otherwise' do
    output = "test/test_ticker.c:9:5: error: use of undeclared identifier 'partial_tick_cnt'\n" \
             "test/test_ticker.c:3:30: note: expanded from macro 'PARTIAL_LOCAL_VAR'\n"

    expect( prescriptions( output ).size ).to eq( 1 )
  end

  it 'prescribes nothing for a name no Partials macro builds' do
    expect( prescriptions( "test/test_ticker.c:9:5: error: 'count' undeclared (first use in this function)\n" ) ).to eq( [] )
  end

  it 'prescribes nothing for a file other than the test file' do
    expect( prescriptions( GCC_LOCAL, source: 'build/test/partials/test_ticker/ceedling_partial_ticker_impl.c' ) ).to eq( [] )
  end

  it 'prescribes nothing without Partials' do
    allow( @configurator ).to receive( :project_use_partials ).and_return( false )

    expect( prescriptions( GCC_LOCAL ) ).to eq( [] )
  end

  it 'covers only compiling' do
    expect( prescriptions( GCC_LOCAL, step: :link ) ).to eq( [] )
  end

  it 'opens tentatively and explains the macro, the C rules and the corrections, left-justified' do
    notice = prescriptions( GCC_LOCAL ).first

    expect( notice ).to start_with( "The compiler output appears to report a name that PARTIAL_LOCAL_VAR() builds and nothing declares. If so," )
    expect( notice ).to include(
      "\n\nHOW THIS HAPPENS:\n• PARTIAL_LOCAL_VAR(function, variable) pastes its arguments into one name, partial_<function>_<variable>, as the test compiles.\n",
      "\n\nOPTIONS:\n1. Check each argument against the function and its static variable in the module's source.\n"
    )
    expect( notice.lines.grep( /\A\s/ ) ).to eq( ["\n", "\n"] )
  end

  it 'explains how a type name is built from a module named with characters C cannot hold' do
    expect( prescriptions( GCC_TYPE ).first ).to include( 'as in my_sensor for my-sensor' )
  end

  # Generation wrote the test's real names into its generated headers. The prescription lists
  # them, whatever file holds them, and names no file.
  context "with this test's Partials generated" do
    before(:each) do
      headers = ['build/test/partials/test_ticker/ceedling_partial_ticker_impl.h', 'build/test/partials/test_ticker/ceedling_partial_ticker_types.h']
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'build/test/partials/test_ticker/**/*.h' ).and_return( headers )
      allow( @file_wrapper ).to receive( :read ).with( headers[0] ).and_return(
        "#include \"ceedling_partial_ticker_types.h\"\nextern int partial_tick_count;\nextern ceedling_partial_ticker_tick_st_t partial_tick_st;\n"
      )
      allow( @file_wrapper ).to receive( :read ).with( headers[1] ).and_return( "typedef struct { int n; } ceedling_partial_ticker_tick_st_t;\n" )
    end

    it 'lists the promoted variables the test can name' do
      notice = prescriptions( GCC_LOCAL ).first

      expect( notice ).to include( "4. Promoted variables this test's Partials provide: partial_tick_count, partial_tick_st\n" )
      expect( notice ).not_to include( '_impl.h', '_types.h' )
    end

    it 'lists the type names the test can name' do
      expect( prescriptions( GCC_TYPE ).first ).to include( "4. Type names this test's Partials provide: ceedling_partial_ticker_tick_st_t\n" )
    end
  end


  LOCAL_VAR_LEAD = "The compiler output appears to report a name that PARTIAL_LOCAL_VAR() builds and nothing declares. " \
                   "If so, the macro's arguments may not match a static variable inside one of the module's functions.\n\n"

  LOCAL_VAR_TEXT = <<~TEXT
    HOW THIS HAPPENS:
    • PARTIAL_LOCAL_VAR(function, variable) pastes its arguments into one name, partial_<function>_<variable>, as the test compiles.
    • Each argument must match the module's source exactly, case included. A misspelling builds a name nothing declares.
    • Only a variable declared static inside a function is promoted. A variable at file scope keeps its own name.
    • The macro builds a name the compiler reads. It can't take a string or a runtime value.
    • A test reaches promoted variables through a TEST_PARTIAL_*_MODULE() macro. A MOCK_PARTIAL_*_MODULE() macro provides none.

    OPTIONS:
    1. Check each argument against the function and its static variable in the module's source.
    2. Name a variable at file scope directly, without the macro.
    3. Include the module with a TEST_PARTIAL_*_MODULE() macro.
  TEXT

  TYPE_LEAD = "The compiler output appears to report a type that PARTIAL_TYPE() or PARTIAL_LOCAL_TYPE() names and nothing declares. " \
              "If so, the macro's arguments may not match a variable declared together with its type.\n\n"

  TYPE_TEXT = <<~TEXT
    HOW THIS HAPPENS:
    • A Partial names the type of a variable declared together with its type, as in `static struct { int count; } s_ctx;`.
    • PARTIAL_TYPE(module, variable) and PARTIAL_LOCAL_TYPE(module, function, variable) paste their arguments into that name as the test compiles.
    • The module argument is the module's name alone, without a directory. A character a C identifier can't hold is written as `_`, as in my_sensor for my-sensor.
    • Variables declared in one statement share one type, named for the first of them.
    • A variable whose type is named elsewhere, as in `static struct ctx s_ctx;`, uses that name, here `struct ctx`.

    OPTIONS:
    1. Check each argument against the module's name and its declaration, case included.
    2. Use PARTIAL_LOCAL_TYPE() for a static declared inside a function, with the function's name.
    3. Write a type named elsewhere by its own name.
  TEXT

  it 'gives the exact text of a promoted variable diagnosis with no names to list' do
    expect( prescriptions( GCC_LOCAL ).first ).to eq( LOCAL_VAR_LEAD + LOCAL_VAR_TEXT )
  end

  it 'gives the exact text of a Partial type diagnosis with no names to list' do
    expect( prescriptions( GCC_TYPE ).first ).to eq( TYPE_LEAD + TYPE_TEXT )
  end

  context "with this test's Partials generated, for exact text" do
    before(:each) do
      headers = ['build/test/partials/test_ticker/ceedling_partial_ticker_impl.h']
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'build/test/partials/test_ticker/**/*.h' ).and_return( headers )
      allow( @file_wrapper ).to receive( :read ).with( headers[0] ).and_return(
        "extern int partial_tick_count;\nextern ceedling_partial_ticker_tick_st_t partial_tick_st;\n"
      )
    end

    it 'gives the exact text of a promoted variable diagnosis with its names as a fourth option' do
      expect( prescriptions( GCC_LOCAL ).first ).to eq(
        LOCAL_VAR_LEAD + LOCAL_VAR_TEXT + "4. Promoted variables this test's Partials provide: partial_tick_count, partial_tick_st\n"
      )
    end

    it 'gives the exact text of a Partial type diagnosis with its names as a fourth option' do
      expect( prescriptions( GCC_TYPE ).first ).to eq(
        TYPE_LEAD + TYPE_TEXT + "4. Type names this test's Partials provide: ceedling_partial_ticker_tick_st_t\n"
      )
    end
  end

  it 'truncates a long list of names after twelve, with an ellipsis' do
    names   = (1..14).map { |n| format( 'partial_v%02d', n ) }
    headers = ['build/test/partials/test_ticker/ceedling_partial_ticker_impl.h']
    allow( @file_wrapper ).to receive( :directory_listing ).with( 'build/test/partials/test_ticker/**/*.h' ).and_return( headers )
    allow( @file_wrapper ).to receive( :read ).with( headers[0] ).and_return( names.map { |name| "extern int #{name};\n" }.join )

    expect( prescriptions( GCC_LOCAL ).first ).to end_with(
      "3. Include the module with a TEST_PARTIAL_*_MODULE() macro.\n" \
      "4. Promoted variables this test's Partials provide: #{names.first( 12 ).join( ', ' )}, …\n"
    )
  end
end
