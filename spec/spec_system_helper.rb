require 'fileutils'
require 'tmpdir'
require 'ceedling/yaml_wrapper'
require 'spec_helper'

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

def add_project_settings(project_file_path, settings, show_final=false)
  yaml_wrapper = YamlWrapper.new
  project_hash = yaml_wrapper.load(project_file_path)
  project_hash.deep_merge!(settings)
  puts "\n\n#{project_hash.to_yaml}\n\n" if show_final
  yaml_wrapper.dump(project_file_path, project_hash)
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
    git_repo = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    bundler_gem_file_data = [ %Q{source "http://rubygems.org/"},
                              %Q{gem "rake"},
                              %Q{gem "constructor"},
                              %Q{gem "diy"},
                              %Q{gem "thor"},
                              %Q{gem "deep_merge"},
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

        yield
      end
    end
  end

  def backup_env
    # Force a deep clone. Hacktacular, but works.

    yaml_wrapper = YamlWrapper.new
    @_env = yaml_wrapper.load_string(ENV.to_hash.to_yaml)
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

  def modify_project_yml_for_test(prefix, key, new_value)
    add_line = nil
    updated = false
    updated_yml = []
    File.read('project.yml').split("\n").each_with_index do |line, i|
      m = line.match /\:#{key.to_s}\:\s*(.*)/
      unless m.nil?
        line = line.gsub(m[1], new_value)
        updated = true
      end

      m = line.match /(\s*)\:#{prefix.to_s}\:/
      unless m.nil?
        add_line = [i+1, m[1]+'  ']
      end

      updated_yml.append(line)
    end
    unless updated
      if add_line.nil?
        updated_yml.insert(updated_yml.length - 1, ":#{prefix.to_s}:\n  :#{key.to_s}: #{new_value}")
      else
        updated_yml.insert(add_line[0], "#{add_line[1]}:#{key}: #{new_value}")
      end
    end

    File.write('project.yml', updated_yml.join("\n"), mode: 'w')
  end
end

module CeedlingTestCases
  def can_create_projects
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        expect(File.exist?("test/support")).to eq true
        expect(File.exist?("test/support/.gitkeep")).to eq true
      end
    end
  end

  def has_an_ignore
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?(".gitignore")).to eq true
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

  def can_upgrade_projects_even_if_test_support_folder_does_not_exists
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

  def can_test_projects_with_unity_exec_time
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_EXEC_TIME" ] } }
        add_project_settings("project.yml", settings)

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
        add_project_settings("project.yml", settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_enabled_auto_link_deep_deependency_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("auto_link_deep_dependencies/src/"), 'src/'
        FileUtils.cp_r test_asset_path("auto_link_deep_dependencies/test/."), 'test/'
        settings = { :project => { :auto_link_deep_dependencies => true } }
        add_project_settings("project.yml", settings)

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
        add_project_settings("project.yml", settings)

        output = `bundle exec ruby -S ceedling 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either passes or is ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
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
        #expect(output).to match(/ceedling test:delta/i) #feature temporarily removed
        expect(output).to match(/ceedling version/i)
      end
    end
  end

  def can_run_single_test_with_full_test_case_name_from_test_file_with_success_cmdline_args_are_enabled
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        enable_unity_extra_args = "\n:test_runner:\n"\
                                  "  :cmdline_args: true\n"
        fake_prj_yml= File.read('project.yml').split("\n")
        fake_prj_yml.insert(fake_prj_yml.length() -1, enable_unity_extra_args)
        File.write('project.yml', fake_prj_yml.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=test_add_numbers_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_run_single_test_with_partiall_test_case_name_from_test_file_with_enabled_cmdline_args_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        enable_unity_extra_args = "\n:test_runner:\n"\
                                  "  :cmdline_args: true\n"
        fake_prj_yml= File.read('project.yml').split("\n")
        fake_prj_yml.insert(fake_prj_yml.length() -1, enable_unity_extra_args)
        File.write('project.yml', fake_prj_yml.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file_and_cmdline_args_are_enabled
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        enable_unity_extra_args = "\n:test_runner:\n"\
                                  "  :cmdline_args: true\n"
        fake_prj_yml= File.read('project.yml').split("\n")
        fake_prj_yml.insert(fake_prj_yml.length() -1, enable_unity_extra_args)
        File.write('project.yml', fake_prj_yml.join("\n"), mode: 'w')

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
        enable_unity_extra_args = "\n:test_runner:\n"\
                                  "  :cmdline_args: true\n"
        fake_prj_yml= File.read('project.yml').split("\n")
        fake_prj_yml.insert(fake_prj_yml.length() -1, enable_unity_extra_args)
        File.write('project.yml', fake_prj_yml.join("\n"), mode: 'w')

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
        expect(output).not_to match(/please add `:cmdline_args` under :test_runner option/)
      end
    end
  end

  def exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        enable_unity_extra_args = "\n:test_runner:\n"\
                                  "  :cmdline_args: true\n"
        fake_prj_yml= File.read('project.yml').split("\n")
        fake_prj_yml.insert(fake_prj_yml.length() -1, enable_unity_extra_args)
        File.write('project.yml', fake_prj_yml.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling test:all --exclude_test_case=test_add_numbers_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
      end
    end
  end

  def run_all_test_when_test_case_name_is_passed_but_cmdline_args_are_disabled_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:test_example_file_success --test_case=_adds_numbers 2>&1`

        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
        expect(output).to match(/please add `:cmdline_args` under :test_runner option/)
      end
    end
  end


  def test_run_of_projects_fail_because_of_sigsegv_without_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Segmentation Fault/i)
        expect(output).to match(/Unit test failures./)
        expect(!File.exist?('./build/test/results/test_add.fail'))
      end
    end
  end

  def test_run_of_projects_fail_because_of_sigsegv_with_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        @c.modify_project_yml_for_test(:project, :use_backtrace, 'TRUE')

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Segmentation Fault/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_sigsegv.c\:14/ )
      end
    end
  end

  def execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue_when_cmd_args_set_to_true
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        @c.modify_project_yml_for_test(:project, :use_backtrace, 'TRUE')
        @c.modify_project_yml_for_test(:test_runner, :cmdline_args, 'TRUE')

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Segmentation fault/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_sigsegv.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug_and_cmd_args_set_to_true
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        @c.modify_project_yml_for_test(:project, :use_backtrace, 'TRUE')
        @c.modify_project_yml_for_test(:test_runner, :cmdline_args, 'TRUE')

        output = `bundle exec ruby -S ceedling test:all --test_case=test_add_numbers_will_fail 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Segmentation fault/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_sigsegv.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug_and_cmd_args_set_to_true
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        @c.modify_project_yml_for_test(:project, :use_backtrace, 'TRUE')
        @c.modify_project_yml_for_test(:test_runner, :cmdline_args, 'TRUE')

        output = `bundle exec ruby -S ceedling test:all --exclude_test_case=add_numbers_adds_numbers 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Segmentation fault/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_sigsegv.c\:14/ )
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
