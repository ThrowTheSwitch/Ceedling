# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# Covers CLI surface area with no prior system-test coverage: the naked-task
# backwards-compatibility retry, the bare -T/-v/--version ARGV hacks in
# bin/ceedling, and several commands/flags exercised nowhere else.
ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("cli_surface") }

  describe "Fresh project" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    it "runs build tasks with no `build` keyword (PermissiveCLI retry)" do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.cp test_asset_path("example_file.h"), 'src/'
          FileUtils.cp test_asset_path("example_file.c"), 'src/'
          FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

          # No leading `build` -- Thor raises Thor::UndefinedCommandError for
          # `test:all`, and bin/ceedling retries with `build` unshifted on.
          output = @c.ceedling_appcmd_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+\d/)
          expect(output).to match(/PASSED:\s+\d/)
        end
      end
    end

    it "lists build tasks with bare -T, without `build` or `help`" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_appcmd_exec("-T")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/ceedling test:all/i)
        end
      end
    end

    it "processes configuration with `check` and runs no build tasks" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_appcmd_exec("check")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/Project configuration processed/i)
          # Configuration validation vendors Unity/CMock sources into build/ as
          # scaffolding, but `check` compiles nothing and runs no tests -- no
          # generated test runners or results, unlike an actual build.
          expect(Dir.glob('build/test/runners/*')).to be_empty
          expect(Dir.glob('build/artifacts/**/*').select { |path| File.file?(path) }).to be_empty
        end
      end
    end

    it "loads a project file from a non-default path via --project" do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.mv('project.yml', 'custom_project.yml')

          output = @c.ceedling_appcmd_exec("check --project=custom_project.yml")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/Project configuration processed/i)
        end
      end
    end

    it "surfaces obnoxious-verbosity diagnostics only when --debug is given" do
      @c.with_context do
        Dir.chdir @proj_name do
          quiet_output = @c.ceedling_appcmd_exec("check")
          expect(quiet_output).to_not match(/Launching Ceedling from/)

          debug_output = @c.ceedling_appcmd_exec("check --debug")
          expect(debug_output).to match(/Launching Ceedling from/)
        end
      end
    end

    it "writes to the explicit --logfile path" do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.cp test_asset_path("example_file.h"), 'src/'
          FileUtils.cp test_asset_path("example_file.c"), 'src/'
          FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

          @c.ceedling_build_exec("test:all --logfile=custom.log")

          expect(@c.last_exit_status).to eq(0)
          expect(File.exist?('custom.log')).to eq(true)
        end
      end
    end

    it "writes to the default log path under --log" do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.cp test_asset_path("example_file.h"), 'src/'
          FileUtils.cp test_asset_path("example_file.c"), 'src/'
          FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

          @c.ceedling_build_exec("test:all --log")

          expect(@c.last_exit_status).to eq(0)
          expect(Dir.glob('**/ceedling.log')).to_not be_empty
        end
      end
    end

    it "forces a success exit code under --graceful-fail even when tests fail" do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.cp test_asset_path("example_file.h"), 'src/'
          FileUtils.cp test_asset_path("example_file.c"), 'src/'
          FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

          output = @c.ceedling_build_exec("test:all --graceful-fail")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/FAILED:\s+[1-9]/)
        end
      end
    end

    it "refuses to overwrite an existing project without --force" do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("new #{@proj_name}")

        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/already exists/i)
      end
    end

    it "destroys and recreates the project with --force" do
      @c.with_context do
        Dir.chdir(@proj_name) { File.write('marker.txt', 'should be wiped by --force') }

        output = @c.ceedling_appcmd_exec("new #{@proj_name} --force")

        expect(@c.last_exit_status).to eq(0)
        expect(File.exist?(File.join(@proj_name, 'marker.txt'))).to eq(false)
      end
    end

    # #1250 -- `--ceedling-yml` names the generated starter file ceedling.yml
    # instead of project.yml; the default (no flag, exercised by every other
    # example in this block via the outer `before`) is unchanged.
    it "generates ceedling.yml instead of project.yml under --ceedling-yml" do
      @c.with_context do
        alt_proj_name = "#{@proj_name}_ceedling_yml"
        output = @c.ceedling_appcmd_exec("new #{alt_proj_name} --ceedling-yml")

        expect(@c.last_exit_status).to eq(0)
        Dir.chdir alt_proj_name do
          expect(File.exist?("ceedling.yml")).to eq true
          expect(File.exist?("project.yml")).to eq false
        end
      end
    end
  end

  describe "No project required" do
    it "reports version via bare -v, without the `version` keyword" do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("-v")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Welcome to Ceedling!/)
        expect(output).to match(/Ceedling => \d\.\d\.\d/)
      end
    end

    it "reports version via bare --version, without the `version` keyword" do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("--version")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Welcome to Ceedling!/)
      end
    end

    it "exports documentation with `docs`" do
      @c.with_context do
        @c.ceedling_appcmd_exec("docs docs_dest")

        expect(@c.last_exit_status).to eq(0)
        expect(Dir.exist?('docs_dest/unity')).to eq(true)
        expect(Dir.exist?('docs_dest/cmock')).to eq(true)
        expect(Dir.exist?('docs_dest/c_exception')).to eq(true)
      end
    end

    it "shows detailed help content specific to a named command" do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("help build")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/force-test-rerun/i)
      end
    end
  end
end
