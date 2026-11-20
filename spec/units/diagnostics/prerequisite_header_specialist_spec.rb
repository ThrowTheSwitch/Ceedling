# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/prerequisite_header_specialist'

describe PrerequisiteHeaderSpecialist do
  GUARDED_HEADER = 'rtos/include/task.h'
  GUARD_MESSAGE  = 'include FreeRTOS.h must appear in source files before include task.h'
  MOCKS_DIR      = 'build/test/mocks'
  MOCK_SOURCE    = "#{MOCKS_DIR}/mock_task.c"

  before(:each) do
    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    @configurator = double( 'configurator', cmock_mock_prefix: 'mock_' )
    nobody        = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: nobody, missing_symbol_specialist: nobody,
      duplicate_symbol_specialist: nobody, partial_name_specialist: nobody, include_depth_specialist: nobody,
      prerequisite_header_specialist: described_class.new( configurator: @configurator )
    ).tap( &:setup )

    @testable = TestInvokerTypes::Testable.new( name: 'test_task', paths: { mocks: MOCKS_DIR } )
  end

  # The output of a real GCC run, which writes `#error` into its message, and of a real Clang run,
  # which writes only the message and echoes the `#error` line beneath it
  def gcc_output(message = GUARD_MESSAGE, file: GUARDED_HEADER, quoted: true, chain: '')
    text = quoted ? "\"#{message}\"" : message
    return "#{chain}#{file}:5:6: error: #error #{text}\n    5 |     #error #{text}\n      |      ^~~~~\n"
  end

  # Apple Clang echoes the line without the line-number gutter that Clang 18 writes
  def clang_output(message = GUARD_MESSAGE, file: GUARDED_HEADER, quoted: true, chain: '', gutter: true)
    text = quoted ? "\"#{message}\"" : message
    echo = gutter ? "    5 |     #error #{text}\n      |      ^\n" : "    #error #{text}\n     ^\n"
    return "#{chain}#{file}:5:6: error: #{text}\n#{echo}1 error generated.\n"
  end

  def preprocess(output, role: :mock, source: GUARDED_HEADER)
    return @doctor.diagnose( step: :preprocess, output: output, inputs: { role: role, source: source } )
  end

  def compile(output, source: MOCK_SOURCE, testable: @testable)
    return @doctor.diagnose( step: :compile, output: output, inputs: { source: source, testable: testable } )
  end

  # The approved texts, word for word, with the prerequisite header interpolated
  def preprocess_guidance(header: "'FreeRTOS.h'", flag: '`-include FreeRTOS.h`')
    return <<~GUIDANCE
      The preprocessor output appears to report an #error directive in 'rtos/include/task.h', which may guard it against being included before #{header}.

      HOW THIS HAPPENS:
      • Some headers refuse to be included on their own. An #error directive fires unless a prerequisite header was included first.
      • With mock preprocessing on (:project ↳ :use_test_preprocessor), Ceedling preprocesses each header to be mocked by itself.
      • Neither that preprocessing nor the compilation of the generated mock sees the test file's #include directives, so including #{header} in the test doesn't help.

      NOTE: The build needs both options below.

      OPTIONS:
      1. Add #{flag} to :flags ↳ :test ↳ :preprocess, so the header's preprocessing sees #{header} first.
      2. Add #{header} to :cmock ↳ :includes_h_pre_orig_header, so the generated mock includes it before the header.
    GUIDANCE
  end

  # With no prerequisite named, the options say what to fill in
  def general_preprocess_guidance()
    return preprocess_guidance( header: 'a prerequisite header' ).sub( /^1\. .*\n2\. .*\n/, <<~OPTIONS )
      1. Add `-include` and the prerequisite header's name to :flags ↳ :test ↳ :preprocess, so the header's preprocessing sees the prerequisite first.
      2. Add the prerequisite header's name to :cmock ↳ :includes_h_pre_orig_header, so the generated mock includes it before the header.
    OPTIONS
  end

  def general_compile_guidance()
    return compile_guidance( header: 'a prerequisite header' ).sub(
      /^Add a prerequisite header to .*\n/,
      "Add the prerequisite header's name to :cmock ↳ :includes_h_pre_orig_header, so the generated mock includes it before the header.\n"
    )
  end

  def compile_guidance(header: "'FreeRTOS.h'")
    return <<~GUIDANCE
      The compiler output appears to report an #error directive in 'rtos/include/task.h' while compiling the generated mock 'mock_task.c'. The directive may guard the header against being included before #{header}.

      HOW THIS HAPPENS:
      • Some headers refuse to be included on their own. An #error directive fires unless a prerequisite header was included first.
      • A generated mock includes its header directly, without the test file's #include directives.

      NOTE: Macros the prerequisite defines and the header's declarations use may also need listing in :cmock ↳ :strippables.

      Add #{header} to :cmock ↳ :includes_h_pre_orig_header, so the generated mock includes it before the header.
    GUIDANCE
  end

  context 'when preprocessing a header to be mocked' do
    {
      'GCC'                    => -> (spec) { spec.gcc_output },
      'Clang'                  => -> (spec) { spec.clang_output },
      'GCC, unquoted text'     => -> (spec) { spec.gcc_output( 'include FreeRTOS.h first', quoted: false ) },
      'Clang, unquoted text'   => -> (spec) { spec.clang_output( 'include FreeRTOS.h first', quoted: false ) },
      'Apple Clang'            => -> (spec) { spec.clang_output( gutter: false ) },
      'Apple Clang, unquoted'  => -> (spec) { spec.clang_output( 'include FreeRTOS.h first', quoted: false, gutter: false ) }
    }.each do |wording, output|
      it "prescribes both settings for #{wording}" do
        expect( preprocess( output.call( self ) ) ).to eq( [preprocess_guidance] )
      end
    end

    it 'logs the guidance as a notice' do
      preprocess( gcc_output )

      expect( @loginator ).to have_received( :log ).with( preprocess_guidance, Verbosity::ERRORS, LogLabels::NOTICE )
    end

    it 'names the header the error is in when the header being preprocessed includes it' do
      chain = "In file included from rtos/include/queue.h:3:\n"

      expect( preprocess( gcc_output( chain: chain ), source: 'rtos/include/queue.h' ) ).to eq( [preprocess_guidance] )
      expect( preprocess( clang_output( chain: chain ), source: 'rtos/include/queue.h' ) ).to eq( [preprocess_guidance] )
    end

    it 'prescribes nothing for an error in a header the one being preprocessed does not reach' do
      expect( preprocess( gcc_output, source: 'rtos/include/queue.h' ) ).to be_empty
    end

    it 'ignores the expansion of a test file' do
      expect( preprocess( gcc_output, role: :test ) ).to be_empty
      expect( preprocess( clang_output, role: :test ) ).to be_empty
    end

    it 'ignores a step that gave no role' do
      expect( @doctor.diagnose( step: :preprocess, output: gcc_output, inputs: { source: GUARDED_HEADER } ) ).to be_empty
    end

    it 'ignores an error that is no #error directive' do
      expect( preprocess( "#{GUARDED_HEADER}:5:6: error: expected ';' before 'int'\n    5 | int x\n      |      ^\n" ) ).to be_empty
      expect( preprocess( "#{GUARDED_HEADER}:5:6: error: expected ';'\n    5 |     int x\n      |      ^\n1 error generated.\n" ) ).to be_empty
    end

    it 'ignores a warning directive' do
      expect( preprocess( "#{GUARDED_HEADER}:5:6: warning: #warning #{GUARD_MESSAGE}\n" ) ).to be_empty
    end
  end

  context 'when reading the prerequisite from the message' do
    {
      'must appear before'     => ['include FreeRTOS.h must appear in source files before include task.h', 'FreeRTOS.h'],
      'must be included before' => ['FreeRTOS.h must be included before task.h', 'FreeRTOS.h'],
      'include first'          => ['Please include config.h first', 'config.h'],
      'a path'                 => ['include kernel/FreeRTOS.h first', 'kernel/FreeRTOS.h'],
      'a C++ header'           => ['include FreeRTOS.hpp first', 'FreeRTOS.hpp'],
      'the guarded header first' => ['task.h needs FreeRTOS.h to come first', 'FreeRTOS.h'],
      'a name that only starts like a header' => ['task.h needs config.html and then os_cfg.h first', 'os_cfg.h']
    }.each do |phrasing, (message, prerequisite)|
      it "extracts #{prerequisite} from a message that says #{phrasing}" do
        expect( preprocess( gcc_output( message ) ) ).to eq( [preprocess_guidance( header: "'#{prerequisite}'", flag: "`-include #{prerequisite}`" )] )
        expect( preprocess( clang_output( message ) ) ).to eq( [preprocess_guidance( header: "'#{prerequisite}'", flag: "`-include #{prerequisite}`" )] )
      end
    end

    [
      'do not include this header directly',
      'task.h must not be included directly'
    ].each do |message|
      it "keeps the guidance general for '#{message}'" do
        general = general_preprocess_guidance()

        expect( preprocess( gcc_output( message ) ) ).to eq( [general] )
        expect( preprocess( clang_output( message ) ) ).to eq( [general] )
      end
    end
  end

  context 'when compiling a source' do
    {
      'GCC'   => -> (spec) { spec.gcc_output( chain: "In file included from #{MOCKS_DIR}/mock_task.h:7,\n                 from #{MOCK_SOURCE}:6:\n" ) },
      'Clang' => -> (spec) { spec.clang_output( chain: "In file included from #{MOCK_SOURCE}:6:\nIn file included from #{MOCKS_DIR}/mock_task.h:7:\n" ) },
      'Apple Clang' => -> (spec) { spec.clang_output( chain: "In file included from #{MOCK_SOURCE}:6:\nIn file included from #{MOCKS_DIR}/mock_task.h:7:\n", gutter: false ) }
    }.each do |compiler, output|
      it "prescribes the :includes_h_pre_orig_header setting alone for a generated mock, from #{compiler}" do
        expect( compile( output.call( self ) ) ).to eq( [compile_guidance] )
      end
    end

    it 'keeps the guidance general when the message names no prerequisite' do
      expect( compile( gcc_output( 'do not include this header directly' ) ) ).to eq( [general_compile_guidance] )
    end

    it 'ignores the compilation of a test file' do
      expect( compile( gcc_output, source: 'test/test_task.c' ) ).to be_empty
    end

    it 'ignores a source beside the mocks that does not start with the mock prefix' do
      expect( compile( gcc_output, source: "#{MOCKS_DIR}/task_helper.c" ) ).to be_empty
    end

    it 'ignores a source with the mock prefix outside the mocks directory' do
      expect( compile( gcc_output, source: 'src/mock_task.c' ) ).to be_empty
      expect( compile( gcc_output, source: "#{MOCKS_DIR}_other/mock_task.c" ) ).to be_empty
    end

    it 'finds a mock in a subdirectory of the mocks directory' do
      expect( compile( gcc_output, source: "#{MOCKS_DIR}/rtos/mock_task.c" ) ).to eq( [compile_guidance] )
    end

    it 'ignores a compilation with no testable or no mocks directory' do
      expect( compile( gcc_output, testable: nil ) ).to be_empty
      expect( compile( gcc_output, testable: TestInvokerTypes::Testable.new( name: 'test_task', paths: {} ) ) ).to be_empty
    end

    it 'ignores an #error in the mock itself' do
      expect( compile( gcc_output( file: MOCK_SOURCE ) ) ).to be_empty
    end

    it 'ignores an error that is no #error directive' do
      expect( compile( "#{GUARDED_HEADER}:5:6: error: unknown type name 'foo_t'\n    5 |     foo_t x;\n      |     ^~~~~\n" ) ).to be_empty
    end
  end

  it 'prescribes nothing at linking' do
    expect( @doctor.diagnose( step: :link, output: gcc_output, inputs: { source: MOCK_SOURCE, testable: @testable } ) ).to be_empty
  end
end
