# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'tmpdir'
require 'yaml'

##
## Shortened Build Roots Through Real Builds (GH #1387)
## =====================================================
##
## A vendor include root far outside the project and a source root nested deep inside it
## each add their whole location to every build path below them. A build places those files
## below each root's short marker instead, finds every source from its object, rebuilds
## nothing when nothing changed, and lists the markers in build/build_roots.yml.
##

SHORT_ROOTS_TEST_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "short_roots"

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  # The project, a vendor SDK in `far`, and a configuration naming both long roots
  def short_roots_project(far)
    sdk = File.join( File.realpath( far ), 'deep', 'sdk', 'inc' )
    write( File.join( sdk, 'os', 'vendor_os.h' ), "#define VENDOR_OS_TICKS 3\n" )

    write( 'lib/vendor/acme/hal/hal.h', "int hal_value(void);\n" )
    write( 'lib/vendor/acme/hal/hal.c', "#include \"hal.h\"\n#include \"os/vendor_os.h\"\nint hal_value(void) { return VENDOR_OS_TICKS; }\n" )
    write( 'src/main.c', "#include \"hal.h\"\nint main(void) { return hal_value() - 3; }\n" )
    write( 'test/test_hal.c', SHORT_ROOTS_TEST_PREAMBLE + "#include \"hal.h\"\nvoid test_value(void) { TEST_ASSERT_EQUAL_INT(3, hal_value()); }\n" )

    @c.merge_project_yml_for_test( {
      :project => { :release_build => true },
      :paths   => { :source => ['src/**', 'lib/vendor/acme/hal/**'], :include => ['lib/vendor/acme/hal/**', sdk] }
    } )

    return sdk
  end

  it "places build files below each long root's marker, and rebuilds nothing when nothing changed" do
    Dir.mktmpdir do |far|
      in_project do
        short_roots_project( far )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+1/)

        roots = YAML.safe_load( File.read( 'build/build_roots.yml' ) )
        expect(roots.values).to include( 'lib/vendor/acme/hal', end_with( 'deep/sdk/inc' ) )

        hal_marker = roots.key( 'lib/vendor/acme/hal' )
        expect(Dir.glob( "build/test/out/test/test_hal/#{hal_marker}/hal.o" )).to_not be_empty

        rebuild = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), rebuild
        expect(rebuild).to_not match(/^Compiling /)
        expect(rebuild).to_not match(/^Linking /)
      end
    end
  end

  it "places a release build's objects below each long root's marker" do
    Dir.mktmpdir do |far|
      in_project do
        short_roots_project( far )

        output = @c.ceedling_build_exec( "release" )
        expect(@c.last_exit_status).to eq(0), output

        hal_marker = YAML.safe_load( File.read( 'build/build_roots.yml' ) ).key( 'lib/vendor/acme/hal' )
        expect(File.exist?( "build/release/out/#{hal_marker}/hal.o" )).to be( true )
        expect(File.exist?( 'build/release/out/src/main.o' )).to be( true )
      end
    end
  end
end
