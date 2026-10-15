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
require 'stringio'
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

  DEPENDENCIES_FIXTURES = File.join( DEPENDENCIES_PLUGIN_ROOT, 'example' )

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
    @project_config ||= Hash.new { |hash, key| hash[key] = (key == :files ? {} : []) }
  end

  # Invokes the plugin's rake tasks, in order, in a fresh Rake application
  def run_tasks(deps, *tasks)
    define_constants( deps )
    objects = configurator_objects( quiet_loginator )
    objects[:configurator] = double( 'configurator', project_config_hash: project_config )
    objects[:dependencies] = Dependencies.new( objects, 'dependencies', DEPENDENCIES_PLUGIN_ROOT )

    previous = Rake.application
    main     = DEPENDENCIES_TOPLEVEL_MAIN
    ceedling = main.instance_variable_get( :@ceedling )
    Rake.application = Rake::Application.new
    main.instance_variable_set( :@ceedling, objects )
    begin
      Rake::Task.define_task( :directories )
      load File.join( DEPENDENCIES_PLUGIN_ROOT, 'dependencies.rake' )
      tasks.each { |task| Rake::Task[task].invoke }
      yield if block_given?
    ensure
      Rake.application = previous
      main.instance_variable_set( :@ceedling, ceedling )
    end
  end

  DEPENDENCIES_TOPLEVEL_MAIN = TOPLEVEL_BINDING.receiver

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

  def git_commit(repo, message)
    git( repo, 'add', '.' )
    git( repo, '-c', 'user.name=Spec', '-c', 'user.email=spec@example.com', 'commit', '-q', '-m', message )
  end

  # A local repository holding a build script, so cloning needs no network. Its path
  # serves as the clone source on every platform, where a file:// URL would not.
  def git_repository(root)
    repo = File.join( root, 'upstream' )
    write_build_script( repo, 'build/libcloned.a' )
    git( repo, 'init', '-q' )
    git_commit( repo, 'first' )
    return repo
  end

  def git_head(repo)
    return IO.popen( ['git', '-C', repo, 'rev-parse', 'HEAD'], &:read ).strip
  end

  # A local subversion repository holding one file in trunk, at revision 1
  def svn_repository(root)
    repo   = File.join( root, 'svnrepo' )
    import = File.join( root, 'import' )
    FileUtils.mkdir_p( import )
    File.write( File.join( import, 'first.txt' ), 'first' )
    system( 'svnadmin', 'create', repo, out: File::NULL ) or raise 'svnadmin create failed'
    url = "file://#{repo.start_with?( '/' ) ? '' : '/'}#{repo}/trunk"
    system( 'svn', 'import', '-q', '-m', 'first', import, url, out: File::NULL ) or raise 'svn import failed'
    return url
  end

  # Ceedling reads Plugin#environment when it loads a plugin, so nothing may shadow it
  it 'keeps the environment Ceedling reads from every plugin' do
    define_constants( [dependency( 'local', environment: ['A=1'] )] )
    plugin = Dependencies.new( configurator_objects( quiet_loginator ), 'dependencies', DEPENDENCIES_PLUGIN_ROOT )

    expect(plugin.environment).to eq( [] )
  end

  describe 'tools' do
    # Optional tools are left to the plugin, which checks each one only where it is used
    # GNU tar reads a path beginning `D:` as a remote host named D, so the archive arrives
    # on standard input, where its path never reaches tar. Windows CI's absolute paths
    # exercise this through the gzipped tar fetch below.
    it 'hands tar its archive on standard input' do
      expect(default_tools[:deps_targzip][:arguments]).to include( '-xvzf -', '< "${1}"' )
    end

    it 'marks the build_lib compiler and archiver optional' do
      expect(default_tools.values_at( :deps_compiler, :deps_linker ).map { |tool| tool[:optional] }).to all( be true )
    end

    it 'fails only the fetch that needs it' do
      in_project do
        write_build_script( 'deps/local', 'build/liblocal.a' )
        zipped = dependency( 'zipped', fetch: { method: :zip, source: 'a.zip' } )
        default_tools[:deps_zip] = default_tools[:deps_zip].merge( executable: 'no-such-unzip-tool' )

        run_tasks( [dependency( 'local' ), zipped], 'dependencies:make:local' )
        expect(File.exist?( 'deps/local/build/liblocal.a' )).to be true

        expect { run_tasks( [dependency( 'local' ), zipped], 'dependencies:fetch:zipped' ) }
          .to raise_error( CeedlingException, /no-such-unzip-tool/ )
      end
    end
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

  describe 'a dependency that provides only headers' do
    it 'builds when its include directory is missing' do
      in_project do
        write_build_script( 'deps/headers', 'include/api.h' )
        deps = [dependency( 'headers', paths: { source: 'deps/headers', artifact: 'deps/headers' },
                                       artifacts: { includes: ['include'] } )]
        run_tasks( deps, 'dependencies:make' )

        expect(File.exist?( 'deps/headers/include/api.h' )).to be true
      end
    end
  end

  describe 'dependencies:fetch' do
    it 'unpacks a zip archive', skip: (UNZIP ? false : 'unzip is not installed') do
      in_project do
        deps = [dependency( 'bees', fetch: { method: :zip, source: File.join( DEPENDENCIES_FIXTURES, 'workerbees.zip' ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect(File.exist?( 'deps/bees/src/worker.c' )).to be true
      end
    end

    it 'unpacks a gzipped tar archive' do
      in_project do
        deps = [dependency( 'version', fetch: { method: :tar_gzip, source: File.join( DEPENDENCIES_FIXTURES, 'version.tar.gzip' ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        # Exactly the archive's files, none of the metadata entries some archivers add
        expect(Dir.children( 'deps/version' ).sort).to eq( ['version.c', 'version.h'] )
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

    it 'clones a git branch', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        repo = git_repository( root )
        git( repo, 'checkout', '-q', '-b', 'dev' )
        File.write( File.join( repo, 'dev.txt' ), 'dev' )
        git_commit( repo, 'dev' )
        git( repo, 'checkout', '-q', '-' )

        run_tasks( [dependency( 'cloned', fetch: { method: :git, source: repo, branch: 'dev' } )], 'dependencies:fetch' )

        expect(File.read( 'deps/cloned/dev.txt' )).to eq( 'dev' )
      end
    end

    it 'clones a git tag', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        repo = git_repository( root )
        git( repo, 'tag', 'v1' )
        File.write( File.join( repo, 'later.txt' ), 'later' )
        git_commit( repo, 'later' )

        run_tasks( [dependency( 'cloned', fetch: { method: :git, source: repo, tag: 'v1' } )], 'dependencies:fetch' )

        expect(File.exist?( 'deps/cloned/build.rb' )).to be true
        expect(File.exist?( 'deps/cloned/later.txt' )).to be false
      end
    end

    it 'checks out a git commit hash', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        repo  = git_repository( root )
        first = git_head( repo )
        File.write( File.join( repo, 'later.txt' ), 'later' )
        git_commit( repo, 'later' )

        run_tasks( [dependency( 'cloned', fetch: { method: :git, source: repo, hash: first } )], 'dependencies:fetch' )

        expect(git_head( 'deps/cloned' )).to eq( first )
        expect(File.exist?( 'deps/cloned/later.txt' )).to be false
      end
    end

    it 'checks out a subversion repository at a revision', skip: (SVN ? false : 'svn is not installed') do
      in_project do |root|
        url = svn_repository( root )

        run_tasks( [dependency( 'svn', fetch: { method: :svn, source: url, revision: '1' } )], 'dependencies:fetch' )

        expect(File.read( 'deps/svn/first.txt' )).to eq( 'first' )
      end
    end

    it 'skips a git dependency already fetched', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        deps = [dependency( 'cloned', fetch: { method: :git, source: git_repository( root ) } )]
        run_tasks( deps, 'dependencies:fetch' )

        expect { run_tasks( deps, 'dependencies:fetch' ) }.not_to raise_error
      end
    end

    it 'builds a git dependency fetched beforehand', skip: (GIT ? false : 'git is not installed') do
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

  describe 'a build start' do
    # Ceedling runs its directories task as a build starts, ahead of any fetch, and a
    # build path inside the fetch path must not make an unfetched dependency look fetched
    it 'fetches and builds a git dependency whose build path lies inside its fetch path', skip: (GIT ? false : 'git is not installed') do
      in_project do |root|
        deps = [dependency( 'cloned', fetch: { method: :git, source: git_repository( root ) },
                                      paths: { fetch: 'deps/cloned', build: 'deps/cloned/build', artifact: 'deps/cloned/build' },
                                      artifacts: { static_libraries: ['libcloned.a'], dynamic_libraries: [], includes: [] } )]
        run_tasks( deps, 'directories', 'dependencies:make' )

        expect(File.exist?( 'deps/cloned/build/libcloned.a' )).to be true
      end
    end
  end

  describe 'a dependency that builds executables' do
    let(:tools) do
      dependency( 'tools', paths: { source: 'deps/tools', build: 'deps/tools/build', deploy: 'out/bin' },
                           artifacts: { executables: ['tool'] } )
    end

    it 'builds its executables, then deploys them to its deploy path' do
      in_project do
        write_build_script( 'deps/tools', 'build/tool' )
        run_tasks( [tools], 'dependencies:make', 'dependencies:deploy' )

        expect(File.read( 'out/bin/tool' )).to start_with( 'built:' )
      end
    end

    it 'deploys an executable that stays executable', skip: (Gem.win_platform? ? 'Windows has no execute permission bit' : false) do
      in_project do
        write_build_script( 'deps/tools', 'build/tool' )
        File.write( 'deps/tools/build.rb', File.read( 'deps/tools/build.rb' ) + "File.chmod( 0o755, 'build/tool' )\n" )
        run_tasks( [tools], 'dependencies:deploy' )

        expect(File.executable?( 'out/bin/tool' )).to be true
      end
    end

    it 'explains an executable its build did not produce' do
      in_project do
        write_build_script( 'deps/tools', 'build/other' )

        expect { run_tasks( [tools], 'dependencies:deploy' ) }.to raise_error( CeedlingException, /did not produce.*:build.*:artifacts/ )
      end
    end

    # A release may ship a tool, but no test build links one
    it 'makes its executables a prerequisite of release but not of test builds' do
      in_project do
        run_tasks( [tools] ) do
          expect(Rake::Task[RELEASE_SYM.to_s].prerequisites).to include( 'deps/tools/build/tool' )
          expect(Rake::Task['prepare'].prerequisites).not_to include( 'deps/tools/build/tool' )
        end
      end
    end

    it 'lists its executables among the dependency files' do
      in_project do
        output = StringIO.new
        $stdout, previous = output, $stdout
        begin
          run_tasks( [tools], 'files:dependencies' )
        ensure
          $stdout = previous
        end

        expect(output.string).to include( 'deps/tools/build/tool' )
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
