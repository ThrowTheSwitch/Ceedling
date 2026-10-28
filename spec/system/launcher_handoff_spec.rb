# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Launcher Hand-off
## =================
##
## GH #1365: a launcher selecting another installation ran that installation's
## application inside its own process. The gem's launcher now hands a `--local`
## project's build to the vendored copy's own launcher, in its own process.
##
## spec/integration/launcher_handoff_spec.rb covers every command short of a build.
## These run a real build through a hand-off, on every platform, where Windows
## emulates the process replacement and must still carry the build's exit status.
##

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("handoff") }

  # A vendored copy reporting its own version, a test file with one failing test, and
  # the Windows executable extension the build expects
  def prepare_vendored_project
    version_rb = File.join( 'vendor', 'ceedling', 'lib', 'version.rb' )
    File.write( version_rb, File.read( version_rb ).sub( /BASE = '[^']+'/, "BASE = '9.9.9'" ) )

    FileUtils.cp test_asset_path("example_file.h"), 'src/'
    FileUtils.cp test_asset_path("example_file.c"), 'src/'
    FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

    @c.remove_project_yml_option_for_test( :extension, :executable ) if /mingw|win32/.match?( RUBY_PLATFORM.downcase )
  end

  def expect_build_in_vendored_copy(output)
    expect(@c.last_exit_status).to eq(1), output
    expect(output).to match(/is handing off to Ceedling 9\.9\.9\S* at /)
    expect(output).to match(/Ceedling 9\.9\.9\S* at .+ is now running, launched from Ceedling /)
    expect(output).to match(/TESTED:\s+2/)
    expect(output).to match(/PASSED:\s+1/)
    expect(output).to match(/FAILED:\s+1/)
  end

  describe "A `--local` project run by the gem" do
    before { @c.with_context { @c.ceedling_appcmd_exec("new --local #{@proj_name}") } }

    it "builds in the vendored copy its :which_ceedling selects and exits with the build's status" do
      @c.with_context do
        Dir.chdir @proj_name do
          prepare_vendored_project()

          expect_build_in_vendored_copy( @c.ceedling_build_exec("test:all") )
        end
      end
    end

    it "builds in the vendored copy WHICH_CEEDLING selects over the project's own setting" do
      @c.with_context do
        Dir.chdir @proj_name do
          prepare_vendored_project()
          @c.merge_project_yml_for_test( {:project => {:which_ceedling => 'gem'}} )
          ENV['WHICH_CEEDLING'] = 'vendor/ceedling'

          expect_build_in_vendored_copy( @c.ceedling_build_exec("test:all") )
        end
      end
    end
  end
end
