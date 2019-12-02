require 'fileutils'
require 'tmpdir'
require 'yaml'

Modulegenerator = Struct.new(:project_root, :source_root, :inc_root, :test_root) do
  def initialize(project_root: "./", source_root: "src/", inc_root: "src/", test_root: "test/")
    super(project_root, source_root, inc_root, test_root)
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

def _add_path_in_section(project_file_path, path, section)
  project_file_contents = File.readlines(project_file_path)
  paths_index = project_file_contents.index(":paths:\n")

  if paths_index.nil?
    # Something wrong with project.yml file, no paths?
    return
  end

  section_index =  paths_index + project_file_contents[paths_index..-1].index("  :#{section}:\n")

  project_file_contents.insert(section_index + 1, "    - #{path}\n")

  File.open(project_file_path, "w+") do |f|
    f.puts(project_file_contents)
  end
end

def _add_define_in_section(project_file_path, define, section)
  project_file_contents = File.readlines(project_file_path)
  defines_index = project_file_contents.index(":defines:\n")

  if defines_index.nil?
    # Something wrong with project.yml file, no defines?
    return
  end

  section_index =  defines_index + project_file_contents[defines_index..-1].index("  :#{section}:\n")

  project_file_contents.insert(section_index + 1, "    - #{define}\n")

  File.open(project_file_path, "w+") do |f|
    f.puts(project_file_contents)
  end
end

def add_source_path(path)
  _add_path_in_section("project.yml", path, "source")
end

def add_test_path(path)
  _add_path_in_section("project.yml", path, "test")
end

def add_test_define(define)
  _add_define_in_section("project.yml", define, "test")
end

def add_module_generator_section(project_file_path, mod_gen)
  project_file_contents = File.readlines(project_file_path)
  module_gen_index = project_file_contents.index(":module_generator:\n")

  unless module_gen_index.nil?
    # already a module_generator in project file, delete it
    module_gen_end_index = project_file_contents[module_gen_index..-1].index("\n")
    project_file_contents.slice[module_gen_index..module_gen_end_index]
  end

  project_file_contents.insert(-2, "\n")
  project_file_contents.insert(-2, ":module_generator:\n")
  project_file_contents.insert(-2, "  :project_root: #{mod_gen.project_root}\n")
  project_file_contents.insert(-2, "  :source_root: #{mod_gen.source_root}\n")
  project_file_contents.insert(-2, "  :inc_root: #{mod_gen.inc_root}\n")
  project_file_contents.insert(-2, "  :test_root: #{mod_gen.test_root}\n")
  project_file_contents.insert(-2, "\n")

  File.open(project_file_path, "w+") do |f|
    f.puts(project_file_contents)
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
        `bundle install --path #{@gem.install_dir}`
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
    @_env = YAML.load(ENV.to_hash.to_yaml)
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
        expect(File.exists?("project.yml")).to eq true
        expect(File.exists?("src")).to eq true
        expect(File.exists?("test")).to eq true
        expect(File.exists?("test/support")).to eq true
        expect(File.exists?("test/support/.gitkeep")).to eq true
      end
    end
  end

  def has_an_ignore
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exists?(".gitignore")).to eq true
      end
    end
  end

  def can_upgrade_projects
    @c.with_context do
      output = `bundle exec ruby -S ceedling upgrade #{@proj_name} 2>&1`
      expect($?.exitstatus).to match(0)
      expect(output).to match(/upgraded!/i)
      Dir.chdir @proj_name do
        expect(File.exists?("project.yml")).to eq true
        expect(File.exists?("src")).to eq true
        expect(File.exists?("test")).to eq true
        all_docs = Dir["vendor/ceedling/docs/*.pdf"].length + Dir["vendor/ceedling/docs/*.md"].length
      end
    end
  end

  def contains_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exists?("vendor/ceedling")).to eq true
      end
    end
  end

  def does_not_contain_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exists?("vendor/ceedling")).to eq false
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
        expect(File.exists?("vendor/ceedling/docs")).to eq false
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
        add_test_define("UNITY_INCLUDE_EXEC_TIME")

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
        expect(File.exists?("build/artifacts/test/test_example_file_verbose.log")).to eq true
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
        expect(File.exists?("myPonies/src/ponies.c")).to eq true
        expect(File.exists?("myPonies/src/ponies.h")).to eq true
        expect(File.exists?("myPonies/test/test_ponies.c")).to eq true

        # add module path to project file
        add_test_path("myPonies/test")
        add_source_path("myPonies/src")

        # See if ceedling finds the test in the subdir
        output = `bundle exec ruby -S ceedling test:all`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Need to Implement ponies/)

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exists?("myPonies/src/ponies.c")).to eq false
        expect(File.exists?("myPonies/src/ponies.h")).to eq false
        expect(File.exists?("myPonies/test/test_ponies.c")).to eq false
      end
    end
  end

  def can_use_the_module_plugin_with_include_path
    @c.with_context do
      Dir.chdir @proj_name do
        # add include path to module generator
        mod_gen = Modulegenerator.new(inc_root: "inc/")
        add_module_generator_section("project.yml", mod_gen)

        # module creation
        output = `bundle exec ruby -S ceedling module:create[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        expect(File.exists?("myPonies/src/ponies.c")).to eq true
        expect(File.exists?("myPonies/inc/ponies.h")).to eq true
        expect(File.exists?("myPonies/test/test_ponies.c")).to eq true

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[myPonies:ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exists?("myPonies/src/ponies.c")).to eq false
        expect(File.exists?("myPonies/inc/ponies.h")).to eq false
        expect(File.exists?("myPonies/test/test_ponies.c")).to eq false
      end
    end
  end

  def can_use_the_module_plugin_with_non_default_paths
    @c.with_context do
      Dir.chdir @proj_name do
        # add paths to module generator
        mod_gen = Modulegenerator.new({source_root: "foo/", inc_root: "bar/", test_root: "barz/"})
        add_module_generator_section("project.yml", mod_gen)

        # module creation
        output = `bundle exec ruby -S ceedling module:create[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Generate Complete/i)
        expect(File.exists?("foo/ponies.c")).to eq true
        expect(File.exists?("bar/ponies.h")).to eq true
        expect(File.exists?("barz/test_ponies.c")).to eq true

        # Module destruction
        output = `bundle exec ruby -S ceedling module:destroy[ponies]`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/Destroy Complete/i)
        expect(File.exists?("foo/ponies.c")).to eq false
        expect(File.exists?("bar/ponies.h")).to eq false
        expect(File.exists?("barz/test_ponies.c")).to eq false
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

end
