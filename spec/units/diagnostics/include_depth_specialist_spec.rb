# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/include_depth_specialist'

describe IncludeDepthSpecialist do
  FORWARDING = 'vendor/esp32/include/freertos/timers.h'
  KERNEL     = 'vendor/kernel/include/timers.h'

  before(:each) do
    # Files by path, each with its text
    @files = { FORWARDING => "#include <timers.h>\n", KERNEL => "int xTimerStart(int t);\n" }

    @file_wrapper = double( 'file_wrapper' )
    allow( @file_wrapper ).to receive( :exist? ) { |path| @files.key?( path ) }
    allow( @file_wrapper ).to receive( :read ) { |path| @files.fetch( path ) }

    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    nobody = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: nobody, missing_symbol_specialist: nobody,
      duplicate_symbol_specialist: nobody, partial_name_specialist: nobody,
      include_depth_specialist: described_class.new( file_wrapper: @file_wrapper )
    ).tap( &:setup )
  end

  def prescriptions(output, search_paths: ['vendor/esp32/include/freertos', 'vendor/kernel/include'], step: :compile)
    @doctor.diagnose( step: step, output: output, inputs: { search_paths: search_paths } )
  end

  GCC_NESTING = "In file included from #{FORWARDING}:1,\n                 from src/halGpio.h:3,\n" \
                "#{FORWARDING}:1:20: error: #include nested depth 200 exceeds maximum of 200 " \
                "(use -fmax-include-depth=DEPTH to increase the maximum)\n"
  CLANG_NESTING = "In file included from src/halGpio.c:1:\nIn file included from #{FORWARDING}:1:\n" \
                  "#{FORWARDING}:1:10: error: #include nested too deeply\n"

  {
    'GCC 10 and later'          => GCC_NESTING,
    'Clang and older GCC'       => CLANG_NESTING,
    'MSVC'                      => "#{FORWARDING}(1): fatal error C1014: too many include files : depth = 1024\n",
    'EDG front ends'            => "\"#{FORWARDING}\", line 1: catastrophic error: #include file \"#{FORWARDING}\" includes itself\n",
    'other compilers, generically' => "#{FORWARDING}:1: error: include depth limit reached\n"
  }.each do |family, output|
    it "recognizes #{family} and names the header that includes itself" do
      notice = prescriptions( output ).first

      expect( notice ).to start_with( 'The compiler output appears to report #include directives nested too deeply' )
      expect( notice ).to include( "'#{FORWARDING}' includes <timers.h>, and the search paths find that name in the header's own directory first " \
                                   "('vendor/esp32/include/freertos'), so it includes itself. '#{KERNEL}' is later in the search paths." )
    end
  end

  it 'prescribes nothing for an unrelated error, even one naming a directory called nested' do
    expect( prescriptions( "In file included from vendor/nested/a.h:1:\nsrc/a.c:2:3: error: expected ';'\n" ) ).to be_empty
  end

  it 'diagnoses preprocessing as well as compilation, and nothing at linking' do
    expect( prescriptions( GCC_NESTING, step: :preprocess ).size ).to eq( 1 )
    expect( prescriptions( GCC_NESTING, step: :link ) ).to be_empty
  end

  it 'leaves out the intended header when no later search path holds one' do
    notice = prescriptions( GCC_NESTING, search_paths: ['vendor/esp32/include/freertos'] ).first

    expect( notice ).to include( "so it includes itself.\n\nHOW THIS HAPPENS:" )
  end

  it 'explains that a quoted self-include loops whatever the search path order' do
    @files[FORWARDING] = "#include \"timers.h\"\n"
    notice = prescriptions( GCC_NESTING, search_paths: ['vendor/kernel/include', 'vendor/esp32/include/freertos'] ).first

    expect( notice ).to include(
      "'#{FORWARDING}' includes \"timers.h\". A quoted #include searches the header's own directory before any search path, " \
      "so it includes itself whatever their order. '#{KERNEL}' is in the search paths, and #include <timers.h> would let their order reach it."
    )
    expect( notice ).not_to include( 'is later in the search paths' )
  end

  it 'names the header by its search path, not by the spelling the compiler output uses' do
    spelled = 'vendor/esp32/include/./freertos/timers.h'
    @files[spelled] = @files[FORWARDING]
    notice = prescriptions( "#{spelled}:1:10: error: #include nested too deeply\n" ).first

    expect( notice ).to include( "'#{FORWARDING}' includes <timers.h>" )
  end

  it 'reads a header holding bytes invalid in its encoding' do
    @files[FORWARDING] = (+"/* \xFF */\n#include <timers.h>\n").force_encoding( Encoding::UTF_8 )

    expect( prescriptions( GCC_NESTING ).first ).to include( "'#{FORWARDING}' includes <timers.h>" )
  end

  it 'gives the general guidance alone when the search paths reach the intended header first' do
    notice = prescriptions( GCC_NESTING, search_paths: ['vendor/kernel/include', 'vendor/esp32/include/freertos'] ).first

    expect( notice ).to include( "which usually means a header includes itself.\n\nHOW THIS HAPPENS:" )
  end

  it 'gives the general guidance alone for headers that include each other' do
    @files['inc/a.h'] = "#include \"b.h\"\n"
    @files['inc/b.h'] = "#include \"a.h\"\n"
    notice = prescriptions( "inc/b.h:1:10: error: #include nested too deeply\n", search_paths: ['inc'] ).first

    expect( notice ).to include( "which usually means a header includes itself.\n\nHOW THIS HAPPENS:", '3. Give headers that include each other include guards' )
  end

  it 'gives the general guidance alone when the header named cannot be read' do
    @files.delete( FORWARDING )

    expect( prescriptions( GCC_NESTING ).first ).to include( "includes itself.\n\nHOW THIS HAPPENS:" )
  end

  it 'reads the header the error line names after its wording, not one the line before names' do
    @files['inc/other.h'] = "#include <timers.h>\n"
    output = "In file included from inc/other.h:4,\ntoo many include files, giving up in #{FORWARDING}\n"

    expect( prescriptions( output, search_paths: ['inc', 'vendor/esp32/include/freertos', 'vendor/kernel/include'] ).first ).to include( "'#{FORWARDING}' includes <timers.h>" )
  end

  it 'reads the header the error line names, not one the include chain names first' do
    output = "In file included from inc/other.h:4,\n#{FORWARDING}:1:20: error: #include nested depth 200 exceeds maximum of 200\n"

    expect( prescriptions( output ).first ).to include( "'#{FORWARDING}' includes <timers.h>" )
  end
end
