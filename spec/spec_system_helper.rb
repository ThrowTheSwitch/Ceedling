require 'fileutils'
require 'tmpdir'
require 'ceedling/yaml_wrapper'
require 'spec_helper'

if Gem.ruby_version >= Gem::Version.new("2.5.0")
  Modulegenerator = Struct.new(:project_root, :source_root, :inc_root, :test_root, keyword_init: true) do
    def initialize(project_root: "./", source_root: "src/", inc_root: "src/", test_root: "test/")
      super
    end
  end
else
  Modulegenerator = Struct.new(:project_root, :source_root, :inc_root, :test_root) do
    def initialize(project_root: "./", source_root: "src/", inc_root: "src/", test_root: "test/")
      super(project_root, source_root, inc_root, test_root)
    end
  end
end

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

def add_project_settings(project_file_path, settings)
  yaml_wrapper = YamlWrapper.new
  project_hash = yaml_wrapper.load(project_file_path)
  project_hash.deep_merge(settings)
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
  class VerificationFailed < Exception; end
  class InvalidBackupEnv < Exception; end

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
                              %Q{gem "ceedling", :path => '#{git_repo.to_s}'}
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
      expect(output).to match(/upgraded!/i)
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
      expect(output).to match(/rescue in upgrade/i)
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
                     :defines => { :test_example_file_unity_printf => [ "TEST" ] }
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

  def can_test_projects_with_enabled_preprocessor_directives_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_preprocessor_directives => true },
                     :unity => { :use_param_tests => true }
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

  def can_test_projects_with_test_name_replaced_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("tests_with_defines/src/"), 'src/'
        FileUtils.cp_r test_asset_path("tests_with_defines/test/."), 'test/'
        settings = { :defines => { :test => [ "STANDARD_CONFIG" ],
                                   :test_adc_hardware_special => [ "TEST", "SPECIFIC_CONFIG" ]
                                 }
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
        expect(output).to match(/ERROR: Ceedling Failed/)
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
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def uses_raw_output_report_plugin
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
        expect(File.exist?("build/artifacts/test/test_example_file_verbose.log")).to eq true
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
        expect(output).to match(/ceedling logging/i)
        expect(output).to match(/ceedling module:create/i)
        expect(output).to match(/ceedling module:destroy/i)
        expect(output).to match(/ceedling summary/i)
        expect(output).to match(/ceedling test:\*/i)
        expect(output).to match(/ceedling test:all/i)
        expect(output).to match(/ceedling test:delta/i)
        expect(output).to match(/ceedling version/i)
      end
    end
  end

  def can_use_the_module_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling module:create[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        output = `bundle exec ruby -S ceedling test:all`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Need to Implement ponies/)
        output = `bundle exec ruby -S ceedling module:destroy[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)

        self.can_use_the_module_plugin_path_extension
        self.can_use_the_module_plugin_with_include_path
      end
    end
  end

  def can_use_the_module_plugin_path_extension
    @c.with_context do
      Dir.chdir @proj_name do
        # Module creation
        output = `bundle exec ruby -S ceedling module:create[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        expect(File.exist?("myPonies/src/ponies.c")).to eq true
        expect(File.exist?("myPonies/src/ponies.h")).to eq true
        expect(File.exist?("myPonies/test/test_ponies.c")).to eq true

        # add module path to project file
        settings = { :paths => { :test => [ "myPonies/test" ],
                                 :source => [ "myPonies/src" ]
                               }
                   }
        add_project_settings("project.yml", settings)

        # See if ceedling finds the test in the subdir
        output = `bundle exec ruby -S ceedling test:all`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Need to Implement ponies/)

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exist?("myPonies/src/ponies.c")).to eq false
        expect(File.exist?("myPonies/src/ponies.h")).to eq false
        expect(File.exist?("myPonies/test/test_ponies.c")).to eq false
      end
    end
  end

  def can_use_the_module_plugin_with_include_path
    @c.with_context do
      Dir.chdir @proj_name do
        # add include path to module generator
        mod_gen = Modulegenerator.new(inc_root: "inc/")
        settings = { :module_generator => { :project_root => mod_gen.project_root,
                                            :source_root => mod_gen.source_root,
                                            :inc_root => mod_gen.inc_root,
                                            :test_root => mod_gen.test_root
                                          }
                   }
        add_project_settings("project.yml", settings)

        # module creation
        output = `bundle exec ruby -S ceedling module:create[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        expect(File.exist?("myPonies/src/ponies.c")).to eq true
        expect(File.exist?("myPonies/inc/ponies.h")).to eq true
        expect(File.exist?("myPonies/test/test_ponies.c")).to eq true

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exist?("myPonies/src/ponies.c")).to eq false
        expect(File.exist?("myPonies/inc/ponies.h")).to eq false
        expect(File.exist?("myPonies/test/test_ponies.c")).to eq false
      end
    end
  end

  def can_use_the_module_plugin_with_non_default_paths
    @c.with_context do
      Dir.chdir @proj_name do
        # add paths to module generator
        mod_gen = Modulegenerator.new(source_root: "foo/", inc_root: "bar/", test_root: "barz/")
        settings = { :module_generator => { :project_root => mod_gen.project_root,
                                            :source_root => mod_gen.source_root,
                                            :inc_root => mod_gen.inc_root,
                                            :test_root => mod_gen.test_root
                                          }
                   }
        add_project_settings("project.yml", settings)

        # module creation
        output = `bundle exec ruby -S ceedling module:create[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        expect(File.exist?("foo/ponies.c")).to eq true
        expect(File.exist?("bar/ponies.h")).to eq true
        expect(File.exist?("barz/test_ponies.c")).to eq true

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exist?("foo/ponies.c")).to eq false
        expect(File.exist?("bar/ponies.h")).to eq false
        expect(File.exist?("barz/test_ponies.c")).to eq false
      end
    end
  end

  def handles_creating_the_same_module_twice_using_the_module_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling module:create[unicorns]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)

        output = `bundle exec ruby -S ceedling module:create[unicorns] 2>&1`
        expect($?.exitstatus).to match(1)
        expect(output).to match(/ERROR: Ceedling Failed/)

        self.handles_creating_the_same_module_twice_using_the_module_plugin_path_extension
      end
    end
  end

  def handles_creating_the_same_module_twice_using_the_module_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling module:create[myUnicorn:unicorns]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)

        output = `bundle exec ruby -S ceedling module:create[myUnicorn:unicorns] 2>&1`
        expect($?.exitstatus).to match(1)
        expect(output).to match(/ERROR: Ceedling Failed/)
      end
    end
  end

  def handles_destroying_a_module_that_does_not_exist_using_the_module_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling module:destroy[unknown]`
        expect($?.exitstatus).to match(0)

        expect(output).to match(/File src\/unknown\.c does not exist so cannot be removed\./)
        expect(output).to match(/File src\/unknown\.h does not exist so cannot be removed\./)
        expect(output).to match(/File test\/test_unknown\.c does not exist so cannot be removed\./)
        expect(output).to match(/Destroy Complete/)

        self.handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension
      end
    end
  end

  def handles_destroying_a_module_that_does_not_exist_using_the_module_plugin_path_extension
    @c.with_context do
      Dir.chdir @proj_name do
        output = `bundle exec ruby -S ceedling module:destroy[myUnknownModule:unknown]`
        expect($?.exitstatus).to match(0)

        expect(output).to match(/File myUnknownModule\/src\/unknown\.c does not exist so cannot be removed\./)
        expect(output).to match(/File myUnknownModule\/src\/unknown\.h does not exist so cannot be removed\./)
        expect(output).to match(/File myUnknownModule\/test\/test_unknown\.c does not exist so cannot be removed\./)
        expect(output).to match(/Destroy Complete/)
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
        expect(output).to match(/Segmentation fault \(core dumped\)/)
        expect(output).to match(/No tests executed./)
        expect(!File.exists?('./build/test/results/test_add.fail'))
      end
    end
  end

  def test_run_of_projects_fail_because_of_sigsegv_with_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_sigsegv.c"), 'test/'

        add_line = false
        updated_prj_yml = []
        File.read('project.yml').split("\n").each do |line|
          if line =~ /\:project\:/
            add_line = true
            updated_prj_yml.append(line)
          else
            if add_line
              updated_prj_yml.append('  :use_backtrace_gdb_reporter: TRUE')
              add_line = false
            end
            updated_prj_yml.append(line)
          end
        end

        File.write('project.yml', updated_prj_yml.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail as sigsegv is called
        expect(output).to match(/Program received signal SIGSEGV, Segmentation fault./)
        expect(output).to match(/Unit test failures./)
        expect(File.exists?('./build/test/results/test_example_file_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_sigsegv.c\:14/ )
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
