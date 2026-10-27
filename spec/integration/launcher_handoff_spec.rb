# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# GH #1365: a launcher ran another installation's application inside its own process,
# so the application ran on a mix of both installations' code. Each command must now
# run whole in the installation it selects.
#
# The second installation is real: `new --local` vendors this repository into a
# project, and the copy gains the assets and examples a vendored copy leaves out, so
# it can also run `new` and `examples`. Two markers make it distinguishable from the
# launcher:
#  - Its lib/version.rb reports 9.9.9.
#  - Its bin/ceedling reports, on exit, how many of the launcher's own files its
#    process loaded. A whole hand-off loads none.
#
# Every command here stops short of compiling, so no toolchain is needed.

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'yaml'
require 'ceedling/installation'

describe 'Launcher hand-off' do
  REPO_ROOT = File.expand_path( '../..', __dir__ )
  LAUNCHER_VERSION = Installation.new( REPO_ROOT ).version

  # Registered as the copy's launcher starts, so it reports on every exit, failures
  # included. It prints to stderr, so `dumpconfig --stdout` output stays pure YAML.
  MARKER = <<~RUBY
    at_exit {
      launcher_files = $LOADED_FEATURES.count { |f| f.start_with?( '%<lib>s' ) or f.start_with?( '%<bin>s' ) }
      $stderr.puts( "LAUNCHER FILES LOADED: \#{launcher_files}" )
    }
  RUBY

  def ceedling(*args, env: {}, dir: @project)
    stdout, stderr, status = Open3.capture3(
      {'CEEDLING_DECORATORS' => 'false'}.merge( env ),
      RbConfig.ruby, File.join( REPO_ROOT, 'bin', 'ceedling' ), *args,
      chdir: dir
    )
    return stdout, stderr, status
  end

  # The copy ran its own command, loading none of the launcher's files
  def expect_copy_ran(stderr)
    expect(stderr).to include( 'LAUNCHER FILES LOADED: 0' )
  end

  before(:all) do
    @tmp = Dir.mktmpdir( 'handoff' )
    _, stderr, status = ceedling( 'new', '--local', 'proj', dir: @tmp )
    raise "Could not create a vendored project:\n#{stderr}" unless status.success?

    @project = File.join( @tmp, 'proj' )
    @copy = File.join( @project, 'vendor', 'ceedling' )

    version_rb = File.join( @copy, 'lib', 'version.rb' )
    File.write( version_rb, File.read( version_rb ).sub( /BASE = '[^']+'/, "BASE = '9.9.9'" ) )
    marker = format( MARKER, lib: File.join( REPO_ROOT, 'lib', 'ceedling' ), bin: File.join( REPO_ROOT, 'bin' ) )
    launcher = File.join( @copy, 'bin', 'ceedling' )
    shebang, rest = File.read( launcher ).split( "\n", 2 )
    File.write( launcher, [shebang, marker, rest].join( "\n" ) )

    ['assets', 'examples'].each { |dir| FileUtils.cp_r( File.join( REPO_ROOT, dir ), @copy ) }

    @copy_version = Installation.new( @copy ).version
  end

  after(:all) do
    FileUtils.rm_rf( @tmp )
  end

  it 'gives the copy a distinct version' do
    expect(@copy_version).to eq( '9.9.9.dev' )
    expect(@copy_version).to_not eq( LAUNCHER_VERSION )
  end

  describe '`version`' do
    it 'reports both installations for a project whose :which_ceedling selects the copy' do
      stdout, _, status = ceedling( 'version' )

      expect(status.exitstatus).to eq( 0 )
      expect(stdout).to include( "Ceedling Launcher => #{LAUNCHER_VERSION}" )
      expect(stdout).to include( "Ceedling App => #{@copy_version}" )
    end

    it 'reports the copy that WHICH_CEEDLING selects, with no project' do
      stdout, _, _ = ceedling( 'version', env: {'WHICH_CEEDLING' => @copy}, dir: @tmp )

      expect(stdout).to include( "Ceedling App => #{@copy_version}" )
    end

    it 'reports the copy that a project named with --project selects, from elsewhere' do
      Dir.mktmpdir do |elsewhere|
        # :which_ceedling resolves against the working directory, so name the copy absolutely
        mixin = File.join( elsewhere, 'which.yml' )
        File.write( mixin, {:project => {:which_ceedling => @copy}}.to_yaml )

        stdout, _, _ = ceedling( 'version', '--project', File.join( @project, 'project.yml' ), '--mixin', mixin, dir: elsewhere )

        expect(stdout).to include( "Ceedling App => #{@copy_version}" )
      end
    end

    it 'never hands off' do
      _, stderr, _ = ceedling( 'version' )

      expect(stderr).to_not include( 'LAUNCHER FILES LOADED' )
    end
  end

  describe 'project commands' do
    it '`check` runs in the copy, with notices from both sides naming both versions' do
      stdout, stderr, status = ceedling( 'check' )

      expect(status.exitstatus).to eq( 0 ), stdout + stderr
      expect_copy_ran( stderr )
      expect(stdout).to include( "Ceedling launcher #{LAUNCHER_VERSION} at #{REPO_ROOT}/ is handing off to Ceedling #{@copy_version} at #{File.realpath( @copy )}/" ).or(
        include( "Ceedling launcher #{LAUNCHER_VERSION} at #{REPO_ROOT}/ is handing off to Ceedling #{@copy_version} at #{@copy}/" )
      )
      expect(stdout).to match( /Ceedling #{Regexp.escape( @copy_version )} at .+ is now running, launched from Ceedling #{Regexp.escape( LAUNCHER_VERSION )} at #{Regexp.escape( REPO_ROOT )}\// )
    end

    ['environment', 'help', '-T'].each do |command|
      it "`#{command}` runs in the copy" do
        stdout, stderr, status = ceedling( command )

        expect(status.exitstatus).to eq( 0 ), stdout + stderr
        expect_copy_ran( stderr )
      end
    end

    it '`help` shows the copy\'s version in its footer' do
      stdout, _, _ = ceedling( 'help' )

      expect(stdout).to include( "Ceedling Packet User Manual (v#{@copy_version})" )
    end

    it '`dumpconfig --stdout` runs in the copy and writes nothing but YAML to stdout' do
      stdout, stderr, status = ceedling( 'dumpconfig', '--stdout' )

      expect(status.exitstatus).to eq( 0 ), stdout + stderr
      expect_copy_ran( stderr )
      expect(YAML.safe_load( stdout, permitted_classes: [Symbol] )).to include( :project )
    end

    it '`dumpconfig --no-app` runs in the copy' do
      _, stderr, status = ceedling( 'dumpconfig', '--no-app', File.join( @tmp, 'dump.yml' ) )

      expect(status.exitstatus).to eq( 0 ), stderr
      expect_copy_ran( stderr )
    end

    it 'exits with the copy\'s failing status' do
      Dir.mktmpdir do |mixins|
        bad = File.join( mixins, 'bad.yml' )
        File.write( bad, {:plugins => {:enabled => ['no_such_plugin']}}.to_yaml )

        _, stderr, status = ceedling( 'check', '--mixin', bad )

        expect(status.exitstatus).to eq( 1 )
        expect_copy_ran( stderr )
      end
    end
  end

  describe 'commands without a project' do
    it '`new` runs in the copy WHICH_CEEDLING selects, which vendors itself' do
      Dir.mktmpdir do |dir|
        _, stderr, status = ceedling( 'new', '--local', 'other', env: {'WHICH_CEEDLING' => @copy}, dir: dir )

        expect(status.exitstatus).to eq( 0 ), stderr
        expect_copy_ran( stderr )
        expect(Installation.new( File.join( dir, 'other', 'vendor', 'ceedling' ) ).version).to eq( @copy_version )
        expect(File.read( File.join( dir, 'other', 'project.yml' ) )).to include( ":ceedling_version: #{@copy_version}" )
      end
    end

    ['examples', 'docs'].each do |command|
      it "`#{command}` runs in the copy WHICH_CEEDLING selects" do
        Dir.mktmpdir do |dir|
          _, stderr, _ = ceedling( command, env: {'WHICH_CEEDLING' => @copy}, dir: dir )

          expect_copy_ran( stderr )
        end
      end
    end
  end

  describe '`upgrade`' do
    it 'refuses to re-vendor a project from its own vendored copy' do
      stdout, stderr, status = ceedling( 'upgrade', '.', env: {'WHICH_CEEDLING' => 'vendor/ceedling'} )

      expect(status.exitstatus).to eq( 1 )
      expect(stdout + stderr).to include( 'from itself' )
      expect(File.directory?( @copy )).to be( true )
    end
  end

  # A launcher before 1.2.2 loads the application into its own process. The application
  # finishes the hand-off itself.
  describe 'an application loaded into an older launcher\'s process' do
    # Stands in for every 1.x launcher before 1.2.2: it builds its bin/ objects before
    # Thor consumes ARGV, hands them over in CEEDLING_HANDOFF_OBJECTS, and requires the
    # application's rakefile. Docker runs the real 1.0.0 through 1.2.1 launchers.
    OLD_LAUNCHER = <<~RUBY
      repo, app = ARGV.shift( 2 )
      $LOAD_PATH.unshift( File.join( repo, 'bin' ) )
      require 'app_cfg'
      CEEDLING_APPCFG = CeedlingAppConfig.new
      lib = CEEDLING_APPCFG[:ceedling_lib_path]
      $LOAD_PATH.unshift( CEEDLING_APPCFG[:ceedling_lib_base_path], lib, File.join( lib, 'config' ), File.join( lib, 'rake_app' ),
                          File.join( CEEDLING_APPCFG[:ceedling_vendor_path], 'diy', 'lib' ) )
      require 'constructor'
      require 'ceedling/constants'
      require 'diy'
      objects = DIY::Context.from_yaml( File.read( File.join( repo, 'bin', 'objects.yml' ) ) )
      objects.build_everything
      CEEDLING_HANDOFF_OBJECTS = [:rake_task_registry, :reportinator, :loginator, :file_wrapper, :yaml_wrapper,
                                  :ruby_expandinator, :config_walkinator, :system_wrapper, :verbosinator].to_h { |n| [n, objects[n]] }
      def boom_handler(_loginator, exception) = $stderr.puts( exception.message )
      objects[:cli_helper].set_verbosity( Verbosity::NORMAL )
      CEEDLING_APPCFG.set_paths( app )
      require CEEDLING_APPCFG[:ceedling_rakefile_filepath]
    RUBY

    it 'restarts in its own process, with the original command line, saying so on both sides' do
      script = File.join( @tmp, 'old_launcher.rb' )
      File.write( script, OLD_LAUNCHER )

      stdout, stderr, status = Open3.capture3(
        {'CEEDLING_DECORATORS' => 'false'}, RbConfig.ruby, script, REPO_ROOT, @copy, 'check', chdir: @project
      )

      expect(status.exitstatus).to eq( 0 ), stdout + stderr
      expect_copy_ran( stderr )
      expect(stdout).to include( "Ceedling launcher #{LAUNCHER_VERSION} at #{REPO_ROOT}/ loaded Ceedling #{@copy_version}" )
      expect(stdout).to include( "Restarting in Ceedling #{@copy_version}'s own process." )
      expect(stdout).to include( 'Project configuration processed.' )
    end

    it 'warns and continues in that process when a hand-off already brought it there' do
      stdout, stderr, status = ceedling(
        'check', env: {'CEEDLING_HANDOFF_LAUNCHER' => '/elsewhere', 'CEEDLING_HANDOFF_TARGET' => REPO_ROOT}
      )

      expect(status.exitstatus).to eq( 0 ), stdout + stderr
      expect(stderr).to_not include( 'LAUNCHER FILES LOADED' )
      expect(stdout).to include( "Ceedling #{LAUNCHER_VERSION} at #{REPO_ROOT}/ is now running, launched from Ceedling at /elsewhere/." )
      expect(stdout).to include( "loaded Ceedling #{@copy_version}" )
      expect(stdout).to include( "Continuing in the launcher's process" )
    end
  end

  describe 'the vendored copy' do
    it 'runs on its own, holding the built-in mixins its launcher validates' do
      stdout, stderr, status = Open3.capture3(
        {'CEEDLING_DECORATORS' => 'false'}, RbConfig.ruby, File.join( @copy, 'bin', 'ceedling' ), 'check', chdir: @project
      )

      expect(status.exitstatus).to eq( 0 ), stdout + stderr
      expect(File.directory?( File.join( @copy, Installation::BUILTIN_MIXINS_DIR ) )).to be( true )
    end
  end
end
