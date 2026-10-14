# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Dependencies plugin end to end, below the CLI: its rake tasks, the plugin, and
# Ceedling's real tool executor fetch and build dependencies in a temporary project with
# real archive, version control, and build tools.
#
# Build and custom fetch steps are small Ruby scripts, so they run wherever Ceedling does.
# An example needing a tool the host lacks (unzip, svn) is skipped with the reason.

require 'spec_helper'
require 'rake'
require 'tmpdir'
require 'yaml'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/rake_app/rake_wrapper'
require_relative '../support/integration/configurator_integration_helper'

DEPENDENCIES_PLUGIN_ROOT = File.expand_path( '../../plugins/dependencies', __dir__ )
$LOAD_PATH.unshift( File.join( DEPENDENCIES_PLUGIN_ROOT, 'lib' ) ) unless $LOAD_PATH.include?( File.join( DEPENDENCIES_PLUGIN_ROOT, 'lib' ) )

require 'dependencies'

describe 'Dependencies plugin (integration)' do
  include ConfiguratorIntegrationHelpers

  FIXTURES = File.join( DEPENDENCIES_PLUGIN_ROOT, 'example' )

  def self.tool?(command)
    system( command, out: File::NULL, err: File::NULL )
  rescue SystemCallError
    false
  end

  UNZIP = tool?( 'unzip -v' )
  GIT   = tool?( 'git --version' )
  SVN   = tool?( 'svn --version --quiet' ) && tool?( 'svnadmin --version --quiet' )

  # The plugin's default tools, as configuration hands them to it
  def default_tools
    @default_tools ||= YAML.safe_load_file( File.join( DEPENDENCIES_PLUGIN_ROOT, 'config', 'defaults.yml' ),
                                            permitted_classes: [Symbol], aliases: true )[:tools]
  end

  def define_constants(deps)
    stub_const( 'DEPENDENCIES_DEPS', deps )
    default_tools.each { |name, tool| stub_const( "TOOLS_#{name.to_s.upcase}", tool ) }
    stub_const( 'PROJECT_RELEASE_BUILD_TARGET', 'build/release/app.out' )
    stub_const( 'PATHS_LIBRARIES', [] )
    stub_const( 'LIBRARIES_SYSTEM', [] )
  end

  def project_config
    @project_config ||= Hash.new { |hash, key| hash[key] = [] }
  end

  # Invokes the plugin's rake tasks, in order, in a fresh Rake application
  def run_tasks(deps, *tasks)
    define_constants( deps )
    objects = configurator_objects( quiet_loginator )
    objects[:configurator] = double( 'configurator', project_config_hash: project_config )
    objects[:dependencies] = Dependencies.new( objects, 'dependencies', DEPENDENCIES_PLUGIN_ROOT )

    previous = Rake.application
    main     = TOOLBOX_MAIN
    ceedling = main.instance_variable_get( :@ceedling )
    Rake.application = Rake::Application.new
    main.instance_variable_set( :@ceedling, objects )
    begin
      load File.join( DEPENDENCIES_PLUGIN_ROOT, 'dependencies.rake' )
      tasks.each { |task| Rake::Task[task].invoke }
    ensure
      Rake.application = previous
      main.instance_variable_set( :@ceedling, ceedling )
    end
  end

  TOOLBOX_MAIN = TOPLEVEL_BINDING.receiver

  def in_project
    Dir.mktmpdir( 'dependencies' ) { |root| Dir.chdir( root ) { yield root } }
  end

  # A build step that writes its artifact, recording an environment variable in it
  def write_build_script(dir, artifact, env: 'DEPS_SPEC_VALUE')
    FileUtils.mkdir_p( dir )
    File.write( File.join( dir, 'build.rb' ), <<~RUBY )
      require 'fileutils'
      FileUtils.mkdir_p( File.dirname( #{artifact.inspect} ) )
      File.write( #{artifact.inspect}, "built:" + ENV.fetch( #{env.inspect}, '' ) + ":" + ARGV.join( '|' ) )
    RUBY
  end

  def dependency(name, **overrides)
    return {
      name:      name,
      paths:     { fetch: "deps/#{name}", source: "deps/#{name}", build: "deps/#{name}/build", artifact: "deps/#{name}/build" },
      fetch:     { method: :none },
      build:     ['ruby build.rb'],
      artifacts: { static_libraries: ["lib#{name}.a"], dynamic_libraries: [], includes: [] }
    }.merge( overrides )
  end

  def git(dir, *args)
    system( 'git', '-C', dir, *args, out: File::NULL, err: File::NULL ) or raise "git #{args.join( ' ' )} failed"
  end

  # A local repository holding a build script, so cloning needs no network
  def git_repository(root)
    repo = File.join( root, 'upstream' )
    write_build_script( repo, 'build/libcloned.a' )
    git( repo, 'init', '-q' )
    git( repo, 'add', '.' )
    git( repo, '-c', 'user.name=Spec', '-c', 'user.email=spec@example.com', 'commit', '-q', '-m', 'first' )
    return "file://#{repo}"
  end

  describe 'dependencies:make' do
    it 'builds a dependency already in place' do
      in_project do
        write_build_script( 'deps/local', 'build/liblocal.a' )
        run_tasks( [dependency( 'local' )], 'dependencies:make' )

        expect(File.read( 'deps/local/build/liblocal.a' )).to start_with( 'built:' )
      end
    end

    it 'sets a dependency environment variable for its build' do
      in_project do
        write_build_script( 'deps/local', 'build/liblocal.a' )
        run_tasks( [dependency( 'local', environment: ['DEPS_SPEC_VALUE=hello'] )], 'dependencies:make' )

        expect(File.read( 'deps/local/build/liblocal.a' )).to start_with( 'built:hello:' )
      end
    end

    it 'keeps one dependency environment from the next dependency build' do
      pending 'environment variables persist for the rest of the process'

      in_project do
        write_build_script( 'deps/first', 'build/libfirst.a' )
        write_build_script( 'deps/second', 'build/libsecond.a' )
        deps = [dependency( 'first', environment: ['DEPS_SPEC_VALUE=first'] ), dependency( 'second' )]
        run_tasks( deps, 'dependencies:make' )

        expect(File.read( 'deps/second/build/libsecond.a' )).to start_with( 'built::' )
      end
    ensure
      ENV.delete( 'DEPS_SPEC_VALUE' )
    end

    # Build steps run through a shell, which keeps quoted arguments together
    it 'passes a quoted build argument holding a space as one argument' do
      in_project do
        write_build_script( 'deps/local', 'build/liblocal.a' )
        run_tasks( [dependency( 'local', build: ['ruby build.rb "a b" c'] )], 'dependencies:make' )

        expect(File.read( 'deps/local/build/liblocal.a' )).to end_with( ':a b|c' )
      end
    end

    it 'accepts a dependency with no artifacts' do
      in_project do
        write_build_script( 'deps/tool', 'build/out.txt' )
        deps = [dependency( 'tool' ).tap { |dep| dep.delete( :artifacts ) }]

        expect { run_tasks( deps, 'dependencies:make' ) }.not_to raise_error
      end
    end
  end

  describe 'dependencies:fetch' do
    it 'unpacks a zip archive', skip: (UNZIP ? false : 'unzip is not installed') do
      in_project do
        deps = [dependency( 'bees', fetch: { method: :zip, source: File.join( FIXTURES, 'workerbees.zip' ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect(File.exist?( 'deps/bees/src/worker.c' )).to be true
      end
    end

    it 'unpacks a gzipped tar archive' do
      in_project do
        deps = [dependency( 'version', fetch: { method: :tar_gzip, source: File.join( FIXTURES, 'version.tar.gzip' ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect(File.exist?( 'deps/version/version.c' )).to be true
      end
    end

    it 'runs custom fetch commands in the fetch path' do
      in_project do |root|
        File.write( 'fetch.rb', "File.write( 'fetched.txt', 'custom' )\n" )
        deps = [dependency( 'custom', fetch: { method: :custom, executable: ["ruby #{File.join( root, 'fetch.rb' )}"] } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect(File.read( 'deps/custom/fetched.txt' )).to eq( 'custom' )
      end
    end

    it 'clones a git repository', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        deps = [dependency( 'cloned', fetch: { method: :git, source: git_repository( root ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect(File.exist?( 'deps/cloned/build.rb' )).to be true
      end
    end

    it 'skips a git dependency already fetched', skip: (GIT ? false : 'git is not installed') do
      pending 'a second fetch clones into the populated folder and fails (#1076)'

      in_project do |root|
        deps = [dependency( 'cloned', fetch: { method: :git, source: git_repository( root ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect { run_tasks( deps, 'dependencies:fetch' ) }.not_to raise_error
      end
    end

    it 'builds a git dependency fetched beforehand', skip: (GIT ? false : 'git is not installed') do
      pending 'make fetches again before building (#1076)'

      in_project do |root|
        deps = [dependency( 'cloned', fetch: { method: :git, source: git_repository( root ) },
                                      paths: { fetch: 'deps/cloned', build: 'deps/cloned/build', artifact: 'deps/cloned/build' },
                                      artifacts: { static_libraries: ['libcloned.a'], dynamic_libraries: [], includes: [] } )]
        run_tasks( deps, 'dependencies:fetch' )
        run_tasks( deps, 'dependencies:make' )

        expect(File.exist?( 'deps/cloned/build/libcloned.a' )).to be true
      end
    end
  end

  describe 'dependencies:clean' do
    it 'removes a fetched dependency' do
      in_project do |root|
        File.write( 'fetch.rb', "File.write( 'fetched.txt', 'custom' )\n" )
        deps = [dependency( 'custom', fetch: { method: :custom, executable: ["ruby #{File.join( root, 'fetch.rb' )}"] } )]
        run_tasks( deps, 'dependencies:fetch' )
        run_tasks( deps, 'dependencies:clean' )

        expect(Dir.exist?( 'deps/custom' )).to be false
      end
    end

    it 'removes only the artifacts of a dependency that is not fetched' do
      in_project do
        write_build_script( 'deps/local', 'build/liblocal.a' )
        run_tasks( [dependency( 'local' )], 'dependencies:make' )
        run_tasks( [dependency( 'local' )], 'dependencies:clean' )

        expect(File.exist?( 'deps/local/build.rb' )).to be true
        expect(Dir.exist?( 'deps/local/build' )).to be false
      end
    end
  end

  describe 'dependencies:deploy' do
    it 'copies every dynamic library from its artifact path beside the release build' do
      pending 'deploy copies the dependency name, not its libraries (#1110)'

      in_project do
        FileUtils.mkdir_p( %w[deps/shared/build build/release] )
        File.write( 'deps/shared/build/libone.so', 'one' )
        File.write( 'deps/shared/build/libtwo.so', 'two' )
        deps = [dependency( 'shared', build: [], artifacts: { static_libraries: [], dynamic_libraries: ['libone.so', 'libtwo.so'], includes: [] } )]
        run_tasks( deps, 'dependencies:deploy' )

        expect(Dir.children( 'build/release' ).sort).to eq( ['libone.so', 'libtwo.so'] )
      end
    end
  end

end
