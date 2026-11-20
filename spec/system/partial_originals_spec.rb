# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/gcov_helpers'
require_relative 'support/partial_originals_fixtures'

##
## A Partial's Original Source Compiles Only for Coverage
## ======================================================
##
## A test that builds a module as a Partial links the Partial's generated source in place of
## the module's own source. Compiling the module's own source, its original, serves only a
## coverage report, which reads it. A plain test build skips that compile. A gcov build
## makes it with -w, since its object never links and any real warning shows in the Partial's
## own compile of the same code.
##
## The project is one where a header declares a mocked function `static`, so the original
## alone makes GCC say the function is used but never defined. The module's port, which
## defines that function, is included by a macro that a test build sets to an empty file.
##

# GCC words it one way, Clang another, and macOS's gcc is Clang
PARTIAL_ORIGINALS_NEVER_DEFINED = /used but never defined|has internal linkage but is not defined/

ceedling_system_tests do
  include GcovHelpers
  include PartialOriginalsFixtures
  include_context "a fresh ceedling gem project", "partial_originals"
  include_context "cannot be sanitized"

  before :all do
    determine_reports_to_test
  end

  # The project of a test that Partializes one module and mocks the static functions of another
  def stage_project
    write_partial_originals_project

    @c.uncomment_project_yml_option_for_test( '- gcov' )
    @c.uncomment_project_yml_option_for_test( '- report_build_warnings_log' )
    @c.comment_project_yml_option_for_test( '- gcovr' ) unless @gcov_reports.include?( :gcovr )
    @c.uncomment_project_yml_option_for_test( '- ReportGenerator' ) if @gcov_reports.include?( :reportgenerator )

    @c.merge_project_yml_for_test( partial_originals_project_settings.merge( :gcov => { :reports => ['Cobertura'] } ) )
  end

  def warnings_log(context)
    path = File.join( 'build', 'artifacts', context.to_s, 'warnings.log' )
    return File.exist?( path ) ? File.read( path ) : ''
  end

  describe "a plain test build" do
    it "compiles the Partial and leaves the original out" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "test:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+3/)
        expect(output).to match(/Compiling [^\n]*::ceedling_partial_sensor_manager/)
        expect(output).to_not match(/Compiling [^\n]*::sensor_manager\.c/)
        # A source with no Partial still compiles
        expect(output).to match(/Compiling [^\n]*::calc\.c/)
      end
    end

    it "leaves the original's object out of the build tree" do
      in_project do
        stage_project
        @c.ceedling_build_exec( "test:all" )

        objects = Dir.glob( File.join( 'build', 'test', 'out', '**', '*.o' ) )

        expect(objects.map { |path| File.basename( path ) }).to_not include( 'sensor_manager.o' )
        expect(objects.map { |path| File.basename( path ) }).to include( 'calc.o' )
      end
    end

    it "logs no warning of a function used but never defined" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "test:all" )

        expect(output).to_not match( PARTIAL_ORIGINALS_NEVER_DEFINED )
        expect(warnings_log( :test )).to_not match( PARTIAL_ORIGINALS_NEVER_DEFINED )
      end
    end

    it "compiles nothing on a second build, naming no original" do
      in_project do
        stage_project
        @c.ceedling_build_exec( "test:all" )

        output = @c.ceedling_build_exec( "test:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to_not match(/^Compiling /)
        expect(output).to_not match(/Compiling [^\n]*::sensor_manager\.c/)
        expect(output).to match(/PASSED:\s+3/)
      end
    end
  end

  describe "a coverage build" do
    it "compiles the original with coverage" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "gcov:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+3/)
        expect(output).to match(/Compiling with coverage [^\n]*::sensor_manager\.c/)
        expect(output).to match(/Compiling with coverage [^\n]*::ceedling_partial_sensor_manager/)
      end
    end

    it "compiles the original with -w and no other compile with it" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "gcov:all --verbosity=obnoxious" )

        commands = output.to_s.lines.select { |line| line.start_with?( '`' ) && line.include?( ' -c ' ) }
        original = commands.select { |line| line.match?( /-c "src[\\\/]sensor_manager\.c"/ ) }
        partial  = commands.select { |line| line.match?( /-c "[^"]*ceedling_partial_sensor_manager_impl\.c"/ ) }
        others   = commands.select { |line| line.match?( /-c "src[\\\/]calc\.c"/ ) }

        expect(original.length).to eq(1)
        expect(partial.length).to eq(1)
        expect(others.length).to eq(1)
        expect(original.first).to match(/\s-w\s/)
        expect(partial.first).to_not match(/\s-w\s/)
        expect(others.first).to_not match(/\s-w\s/)
      end
    end

    it "logs no warning of a function used but never defined" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "gcov:all" )

        expect(output).to_not match( PARTIAL_ORIGINALS_NEVER_DEFINED )
        expect(warnings_log( :gcov )).to_not match( PARTIAL_ORIGINALS_NEVER_DEFINED )
      end
    end

    it "reports the Partial's coverage against the original's lines" do
      in_project do
        stage_project

        output = @c.ceedling_build_exec( "gcov:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/Lines executed:/)
        expect(output).to match(/sensor_manager\.c/)
        expect(output).to_not match(/Found no coverage results for[^\n]*sensor_manager/)

        cobertura = File.read( File.join( 'build', 'artifacts', 'gcov', 'gcovr', 'GcovCoverageCobertura.xml' ) )
        lines = cobertura.scan( %r{<class [^>]*filename="src[\\/]sensor_manager\.c".*?</class>}m ).first.to_s
        hits  = lines.scan( /<line number="(\d+)" hits="(\d+)"/ ).to_h { |number, count| [number.to_i, count.to_i] }

        # `return 2 * sensor_inf_read();` is on source line 9
        expect(hits[9]).to be > 0
      end
    end

    it "compiles nothing on a second build" do
      in_project do
        stage_project
        @c.ceedling_build_exec( "gcov:all" )

        output = @c.ceedling_build_exec( "gcov:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to_not match(/^Compiling /)
      end
    end
  end
end
