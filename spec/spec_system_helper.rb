# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'ceedling/yaml_wrapper'
require 'spec_helper'
require 'deep_merge'

def test_asset_path(asset_file_name)
  File.join(File.dirname(__FILE__), '..', 'assets', asset_file_name)
end

def convert_slashes(path)
  if RUBY_PLATFORM.downcase.match(/mingw|win32/)
    path.gsub("/","\\")
  else
    path
  end
end

class GemDirLayout
  attr_reader :gem_dir_base_name

  def initialize(install_dir)
    @gem_dir_base_name = "gems"
    @d = File.join install_dir, @gem_dir_base_name
    FileUtils.mkdir_p @d
  end

  def install_dir; convert_slashes(@d)  end
  def bin;         File.join(@d, 'bin') end
  def lib;         File.join(@d, 'lib') end
end

class SystemContext
  class VerificationFailed < RuntimeError; end
  class InvalidBackupEnv < RuntimeError; end

  attr_reader :dir, :gem

  def initialize
    @dir = Dir.mktmpdir
    @gem = GemDirLayout.new(@dir)
  end

  def done!
    FileUtils.rm_rf(@dir)
  end

  def deploy_gem
    git_repo = File.expand_path( File.join( File.dirname( __FILE__ ), '..') )
    bundler_gem_file_data = [
      %Q{source "http://rubygems.org/"},
      %Q{gem "rake"},
      %Q{gem "constructor"},
      %Q{gem "diy"},
      %Q{gem "thor"},
      %Q{gem "deep_merge"},
      %Q{gem "unicode-display_width"},
      %Q{gem "ceedling", :path => '#{git_repo}'}
    ].join("\n")

    File.open(File.join(@dir, "Gemfile"), "w+") do |f|
      f.write(bundler_gem_file_data)
    end

    Dir.chdir @dir do
      with_constrained_env do
        `bundle config set --local path '#{@gem.install_dir}'`
        `bundle install`
        checks = ["bundle exec ruby -S ceedling 2>&1"]
        checks.each do |c|
          `#{c}`
          #raise VerificationFailed.new(c) unless $?.success?
        end
      end
    end

  end

  # Does a few things:
  #   - Configures the environment.
  #   - Runs the command from the temporary context directory.
  #   - Restores everything to where it was when finished.
  def context_exec(cmd, *args)
    with_context do
      `#{args.unshift(cmd).join(" ")}`
    end
  end

  def with_context
    Dir.chdir @dir do |current_dir|
      with_constrained_env do
        ENV['RUBYLIB'] = @gem.lib
        ENV['RUBYPATH'] = @gem.bin

        ENV['LANG'] = 'en_US.UTF-8'
        ENV['LANGUAGE'] = 'en_US.UTF-8'
        ENV['LC_ALL'] = 'en_US.UTF-8'

        yield
      end
    end
  end

  ############################################################
  # Functions for manipulating environment settings during tests:
  def backup_env
    @_env = ENV.to_hash
  end

  def reduce_env(destroy_keys=[])
    ENV.keys.each {|k| ENV.delete(k) if destroy_keys.include?(k) }
  end

  def constrain_env
    destroy_keys = %w{BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT}
    reduce_env(destroy_keys)
  end

  def restore_env
    if @_env
      # delete environment variables we've added since we started
      ENV.to_hash.each_pair {|k,v| ENV.delete(k) unless @_env.include?(k) }

      # restore environment variables we've modified since we started
      @_env.each_pair {|k,v| ENV[k] = v}
    else
      raise InvalidBackupEnv.new
    end
  end

  def with_constrained_env
    begin
      backup_env
      constrain_env
      yield
    ensure
      restore_env
    end
  end

  ############################################################
  # Functions for manipulating project.yml files during tests:
  def merge_project_yml_for_test(settings, show_final=false)
    yaml_wrapper = YamlWrapper.new
    project_hash = yaml_wrapper.load('project.yml')
    project_hash.deep_merge!(settings)
    puts "\n\n#{project_hash.to_yaml}\n\n" if show_final
    yaml_wrapper.dump('project.yml', project_hash)
  end

  def append_project_yml_for_test(new_args)
    fake_prj_yml= "#{File.read('project.yml')}\n#{new_args}"
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def uncomment_project_yml_option_for_test(option)
    fake_prj_yml= File.read('project.yml').gsub(/\##{option}/,option)
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def comment_project_yml_option_for_test(option)
    fake_prj_yml= File.read('project.yml').gsub(/#{option}/,"##{option}")
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end
  ############################################################
end

module CeedlingTestCases
  def can_report_version_no_git_commit_sha
    @c.with_context do
      # Version without Git commit short SHA file in project
      output = `bundle exec ruby -S ceedling version 2>&1`
      expect($?.exitstatus).to match(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d\n/)
    end
  end

  def can_report_version_with_git_commit_sha
    # Version with Git commit short SHA file in root of project
    # Creating the commit file before building + installing the gem simulates the CI process
    File.open('GIT_COMMIT_SHA', 'w') do |f|
      f << '---{-@'
    end

    @c.with_context do
      output = `bundle exec ruby -S ceedling version 2>&1`
      expect($?.exitstatus).to match(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d----{-@\n/)
    end
  end

  def can_create_projects
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        expect(File.exist?("test/support")).to eq true
      end
    end
  end

  def has_git_support
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?(".gitignore")).to eq true
        expect(File.exist?("test/support/.gitkeep")).to eq true
      end
    end
  end

  def can_upgrade_projects
    @c.with_context do
      output = `bundle exec ruby -S ceedling upgrade #{@proj_name} 2>&1`
      expect($?.exitstatus).to match(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        all_docs = Dir["vendor/ceedling/docs/*.pdf"].length + Dir["vendor/ceedling/docs/*.md"].length
      end
    end
  end

  def can_upgrade_projects_even_if_test_support_folder_does_not_exist
    @c.with_context do
      output = `bundle exec ruby -S ceedling upgrade #{@proj_name} 2>&1`
      FileUtils.rm_rf("#{@proj_name}/test/support")

      updated_prj_yml = []
      File.read("#{@proj_name}/project.yml").split("\n").each do |line|
        updated_prj_yml.append(line) unless line =~ /support/
      end
      File.write("#{@proj_name}/project.yml", updated_prj_yml.join("\n"), mode: 'w')

      expect($?.exitstatus).to match(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        all_docs = Dir["vendor/ceedling/docs/*.pdf"].length + Dir["vendor/ceedling/docs/*.md"].length
      end
    end
  end

  def cannot_upgrade_non_existing_project
    @c.with_context do
      output = `bundle exec ruby -S ceedling upgrade #{@proj_name} 2>&1`
      expect($?.exitstatus).to match(1)
      expect(output).to match(/Could not find an existing project/i)
    end
  end

  def contains_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq true
      end
    end
  end

  def does_not_contain_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq false
      end
    end
  end

  def contains_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        all_docs = Dir["docs/*.md"].length + Dir["vendor/ceedling/docs/*.md"].length
        expect(all_docs).to be >= 4
      end
    end
  end

  def does_not_contain_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling/docs")).to eq false
        expect(Dir["vendor/ceedling/**/*.pdf"].length).to eq 0
      end
    end
  end

  def can_test_projects_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_test_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_named_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling --verbosity=obnoxious 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match (/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_numerical_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling -v=4 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match (/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_unity_exec_time
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_EXEC_TIME" ] } }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_and_vendor_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_unity_printf.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_PRINT_FORMATTED" ] },
                     :defines => { :test => { :example_file_unity_printf => [ "TEST" ] } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_name_replaced_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("tests_with_defines/src/"), 'src/'
        FileUtils.cp_r test_asset_path("tests_with_defines/test/."), 'test/'
        settings = { :defines => { :test => { '*' => [ "TEST", "STANDARD_CONFIG" ],
                                   'test_adc_hardware_special.c' => [ "TEST", "SPECIFIC_CONFIG" ],
                                 } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either passes or is ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # Ceedling :use_test_preprocessor is disabled
  def can_test_projects_unity_parameterized_test_cases_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :none },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # NOTE: This is not supported in this release, therefore is not getting called.
  def can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :all, :use_deep_preprocessor => :mocks },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_undefined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # Rely on undefined symbols in our C files
        # 2 enabled intentionally failing test cases (no mocks generated)
        settings = { :project => { :use_test_preprocessor => :tests },
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling test:adc_hardwareA 2>&1`
        expect($?.exitstatus).to match(1) # Intentional test failure in successful build
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+2/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_defined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # 1 enabled passing test case with 1 mock used
        settings = { :project => { :use_test_preprocessor => :tests },
                     :defines => { :test => ['PREPROCESSING_TESTS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling test:adc_hardwareA 2>&1`
        expect($?.exitstatus).to match(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with 1 mocked function
        settings = { :project => { :use_test_preprocessor => :mocks },
                     :defines => { :test => ['PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling test:adc_hardwareB 2>&1`
        expect($?.exitstatus).to match(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with a missing mocked function
        settings = { :project => { :use_test_preprocessor => :mocks }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling test:adc_hardwareB 2>&1`
        expect($?.exitstatus).to match(1) # Failing build because of missing mock
        expect(output).to match(/(undeclared|undefined|implicit).+Adc_Reset/)
      end
    end
  end

  def can_test_projects_with_preprocessing_all
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareC.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorC.h"), 'src/'
        # 1 test case using 1 mock
        settings = { :project => { :use_test_preprocessor => :all },
                     :defines => { :test => ['PREPROCESSING_TESTS', 'PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = `bundle exec ruby -S ceedling test:adc_hardwareC 2>&1`
        expect($?.exitstatus).to match(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling test 2>&1`
        expect($?.exitstatus).to match(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test explodes, we return error here
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def can_test_projects_with_both_mock_and_real_header
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.h"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_with_mock.c"), 'test/'

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either passed or was ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def uses_report_tests_raw_output_log_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_verbose.c"), 'test/'

        @c.uncomment_project_yml_option_for_test('- report_tests_raw_output_log')

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
        expect(File.exist?("build/artifacts/test/test_example_file_verbose.raw.log")).to eq true
      end
    end
  end


  def can_fetch_non_project_help
    @c.with_context do
      #notice we don't change directory into the project
        output = `bundle exec ruby -S ceedling help`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling example/i)
        expect(output).to match(/ceedling new/i)
        expect(output).to match(/ceedling upgrade/i)
        expect(output).to match(/ceedling version/i)
    end
  end

  def can_fetch_project_help
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling help`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling clean/i)
        expect(output).to match(/ceedling clobber/i)
        expect(output).to match(/ceedling module:create/i)
        expect(output).to match(/ceedling module:destroy/i)
        expect(output).to match(/ceedling summary/i)
        expect(output).to match(/ceedling test:\*/i)
        expect(output).to match(/ceedling test:all/i)
        expect(output).to match(/ceedling version/i)
      end
    end
  end

  def can_run_single_test_with_full_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=test_add_numbers_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_run_single_test_with_partial_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=zumzum 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=_adds_numbers --exclude_test_case=_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def confirm_if_notification_for_cmdline_args_not_enabled_is_disabled
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
        expect(output).not_to match(/:cmdline_args/)
      end
    end
  end

  def exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all --exclude_test_case=test_add_numbers_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
      end
    end
  end

  def run_one_testcase_from_one_test_file_when_test_case_name_is_passed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end


  def test_run_of_projects_fail_because_of_crash_without_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(!File.exist?('./build/test/results/test_add.fail'))
      end
    end
  end

  def test_run_of_projects_fail_because_of_crash_with_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
      end
    end
  end

  def execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = `bundle exec ruby -S ceedling test:all --test_case=test_add_numbers_will_fail 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = `bundle exec ruby -S ceedling test:all --exclude_test_case=add_numbers_adds_numbers 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_test_projects_with_success_when_space_appears_between_hash_and_include
    # test case cover issue described in https://github.com/ThrowTheSwitch/Ceedling/issues/588
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path('test_example_file_success.c'), 'test/'

        add_line = false
        updated_test_file = []
        File.read(File.join('test','test_example_file_success.c')).split("\n").each do |line|
          if line =~ /#include "unity.h"/
            add_line = true
            updated_test_file.append(line)
          else
            if add_line
              updated_test_file.append('# include "unity.h"')
              add_line = false
            end
            updated_test_file.append(line)
          end
        end

        File.write(File.join('test','test_example_file_success.c'), updated_test_file.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end
end
