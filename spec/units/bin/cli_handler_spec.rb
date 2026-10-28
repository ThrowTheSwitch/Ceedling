# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

# bin/versionator.rb (pulled in transitively by cli_handler.rb) uses bare `require`
# statements that only resolve when lib/ceedling/ and lib/ are directly on the load
# path -- true in the real bin/ceedling bootstrap but not in this spec harness's
# load path setup. Add the same directories here so `require 'cli_handler'` succeeds.
here = File.dirname(__FILE__)
$: << File.join(here, '../../../lib/ceedling')
$: << File.join(here, '../../../lib')

# cli_handler.rb requires 'mixins' before 'ceedling/constants', but bin/mixins.rb
# references UNITY_ROOT_PATH, a constant only defined by ceedling/constants. The
# real bin/ceedling bootstrap always loads ceedling/constants first, so this load
# order only ever bites a spec harness requiring cli_handler.rb directly.
require 'ceedling/constants'
require 'version' # The launcher's own version, which #version reports for this repository
require 'cli_handler'
require 'app_cfg'
require 'path_validator'
require 'cli_helper'
require 'ceedling/ruby_expandinator'
require 'ceedling/rake_app/rake_task_registry'

# Most of CliHandler's public methods (build, dumpconfig, check, environment,
# new_project, upgrade_project, create_example, list_rake_tasks) are thin
# orchestration wiring together many already-independently-tested collaborators
# in sequence. Unit testing those would mean mocking most of the collaborator
# chain just to reach the one interesting line, producing brittle tests that
# mirror the implementation rather than guard behavior -- they're exercised
# end-to-end by system tests instead. Coverage here is scoped to methods with
# real, self-contained branching logic: #inspect, #validate_string_param,
# #version, #list_examples, and the private #standardize_project_and_mixins
# helper (real collaborators, not doubles, since testing it meaningfully means
# exercising the real filtering/standardizing behavior it coordinates).
describe CliHandler do
  before(:each) do
    @loginator     = double('loginator').as_null_object
    @helper        = double('cli_helper').as_null_object
    @composinator  = double('composinator').as_null_object
    @projectinator = double('projectinator').as_null_object
    @path_validator = double('path_validator').as_null_object
    @actionator    = double('actionator').as_null_object
    @launchinator  = double('launchinator').as_null_object

    @cli_handler = described_class.new({
      :composinator       => @composinator,
      :projectinator      => @projectinator,
      :cli_helper         => @helper,
      :path_validator     => @path_validator,
      :rake_task_registry => double('rake_task_registry').as_null_object,
      :actionator         => @actionator,
      :launchinator       => @launchinator,
      :loginator          => @loginator,
    })
  end

  describe '#inspect' do
    it 'returns the class name instead of dumping instance variables' do
      expect(@cli_handler.inspect).to eq('CliHandler')
    end
  end

  describe '#validate_string_param' do
    it 'raises a Thor::Error when the param equals the missing sentinel' do
      expect {
        @cli_handler.validate_string_param( 'MISSING', 'MISSING', '--project is missing a required filename parameter' )
      }.to raise_error( Thor::Error, '--project is missing a required filename parameter' )
    end

    it 'does nothing when the param is a real value' do
      expect {
        @cli_handler.validate_string_param( 'project.yml', 'MISSING', 'unused message' )
      }.to_not raise_error
    end
  end

  describe '#version' do
    before(:each) do
      @app_cfg = CeedlingAppConfig.new
      # No project file unless an example says otherwise
      allow(@projectinator).to receive(:config_available?).and_return( false )
      allow(@path_validator).to receive(:standardize_paths) { |*paths| paths }
    end

    def fake_application_version(install_path)
      double('application_versionator',
        :ceedling_install_path => install_path,
        :ceedling_build        => '1.2.0',
        :cmock_tag             => '2.7.0',
        :unity_tag             => '2.7.1',
        :cexception_tag        => '1.3.4',
      )
    end

    it 'renders a single Ceedling block when launcher and application share an install path' do
      allow(@helper).to receive(:manufacture_app_version).and_return(
        fake_application_version( @app_cfg[:ceedling_root_path] )
      )

      expect(@loginator).to receive(:console) do |message, _label|
        expect(message).to include( 'Ceedling => 1.2.0' )
        expect(message).to_not include( 'Ceedling Launcher' )
        expect(message).to_not include( 'Ceedling App' )
      end

      @cli_handler.version( {}, @app_cfg )
    end

    it 'renders separate launcher and application blocks when their install paths differ' do
      allow(@helper).to receive(:manufacture_app_version).and_return(
        fake_application_version( '/somewhere/else/entirely' )
      )

      expect(@loginator).to receive(:console) do |message, _label|
        # The launcher reports the version of the Ceedling running this spec
        expect(message).to include( "Ceedling Launcher => #{Ceedling::Version::GEM}" )
        expect(message).to include( 'Ceedling App => 1.2.0' )
      end

      @cli_handler.version( {}, @app_cfg )
    end

    # GH #1365: `version` reported the launcher for a project selecting another installation
    context 'with a project' do
      before(:each) do
        allow(@helper).to receive(:manufacture_app_version).and_return( fake_application_version( '/elsewhere' ) )
        allow(@helper).to receive(:process_mixin_filepaths) { |mixins| mixins }
      end

      it 'resolves which Ceedling from an explicit --project and its mixins, loading silently' do
        config = {:project => {:which_ceedling => '/elsewhere'}}
        expect(@composinator).to receive(:loadinate).with(
          hash_including( filepath: 'other/project.yml', mixins: ['ci.yml'], silent: true )
        ).and_return( ['other/project.yml', config] )
        expect(@launchinator).to receive(:resolve).with( env: {}, app_cfg: @app_cfg, config: config )

        @cli_handler.version( {}, @app_cfg, {:project => 'other/project.yml', :mixin => ['ci.yml']} )
      end

      it 'raises when an explicit --project cannot be loaded' do
        allow(@composinator).to receive(:loadinate).and_raise( 'Could not find project filepath' )

        expect {
          @cli_handler.version( {}, @app_cfg, {:project => 'missing.yml', :mixin => []} )
        }.to raise_error( /Could not find project filepath/ )
      end

      it 'raises when an explicit --mixin cannot be loaded with the default project file' do
        allow(@composinator).to receive(:loadinate).and_raise( 'Command line failed validation' )

        expect {
          @cli_handler.version( {}, @app_cfg, {:project => nil, :mixin => ['missing.yml']} )
        }.to raise_error( /Command line failed validation/ )
      end

      it 'reads the default project file when one is available' do
        config = {:project => {:which_ceedling => 'vendor/ceedling'}}
        allow(@projectinator).to receive(:config_available?).and_return( true )
        allow(@composinator).to receive(:loadinate).and_return( ['project.yml', config] )
        expect(@launchinator).to receive(:resolve).with( env: {}, app_cfg: @app_cfg, config: config )

        @cli_handler.version( {}, @app_cfg )
      end

      it 'falls back to resolving without a project when the default project file cannot be loaded' do
        allow(@projectinator).to receive(:config_available?).and_return( true )
        allow(@composinator).to receive(:loadinate).and_raise( 'Project configuration file section :mixins failed validation' )
        expect(@launchinator).to receive(:resolve).with( env: {}, app_cfg: @app_cfg, config: {} )

        expect { @cli_handler.version( {}, @app_cfg ) }.to_not raise_error
      end

      it 'resolves without a project when no project file is available' do
        expect(@composinator).to_not receive(:loadinate)
        expect(@launchinator).to receive(:resolve).with( env: {}, app_cfg: @app_cfg, config: {} )

        @cli_handler.version( {}, @app_cfg )
      end

      it 'never hands off, since it reports on both installations' do
        @cli_handler.version( {}, @app_cfg )

        expect(@launchinator).to_not have_received(:launch)
      end

      it 'reports the launcher from where it runs, even after resolution moves the application paths' do
        allow(@launchinator).to receive(:resolve) { |app_cfg:, **| app_cfg.set_paths( '/elsewhere' ) }

        expect(@loginator).to receive(:console) do |message, _label|
          expect(message).to include( "Ceedling Launcher => #{Ceedling::Version::GEM}" )
          expect(message).to include( "#{@app_cfg[:launcher_root_path]}/" )
        end

        @cli_handler.version( {}, @app_cfg )
      end
    end
  end

  # GH #1365: every command but `version` runs in the installation it selects. An exec
  # never returns, so a raise stands in for it: nothing after the hand-off may run.
  describe 'hand-off' do
    HandedOff = Class.new( StandardError )

    before(:each) do
      @app_cfg = CeedlingAppConfig.new
      @config  = {:project => {:which_ceedling => 'vendor/ceedling'}}
      allow(@path_validator).to receive(:standardize_paths) { |*paths| paths }
      allow(@helper).to receive(:process_mixin_filepaths) { |mixins| mixins }
      allow(@composinator).to receive(:loadinate).and_return( ['project.yml', @config] )
    end

    def expect_no_work_done
      [:log_project_name, :console_project_name, :load_ceedling, :run_rake_tasks, :dump_yaml,
       :project_exists?, :vendor_tools, :copy_docs, :lookup_example_projects, :help_footer].each do |work|
        expect(@helper).to_not have_received( work )
      end
      expect(@actionator).to_not have_received(:make_directory)
      expect(@actionator).to_not have_received(:remove_directory)
      expect(@loginator).to_not have_received(:console)
    end

    {
      'build'                    => ->(h, cfg) { h.build( env: {}, app_cfg: cfg, options: {:project => nil, :mixin => []}, tasks: ['test:all'] ) },
      'check'                    => ->(h, cfg) { h.check( {}, cfg, {:project => nil, :mixin => []} ) },
      'environment'              => ->(h, cfg) { h.environment( {}, cfg, {:project => nil, :mixin => []} ) },
      'dumpconfig'               => ->(h, cfg) { h.dumpconfig( {}, cfg, {:project => nil, :mixin => [], :app => true}, 'out.yml', [] ) },
      'dumpconfig --no-app'      => ->(h, cfg) { h.dumpconfig( {}, cfg, {:project => nil, :mixin => [], :app => false}, 'out.yml', [] ) },
      '-T'                       => ->(h, cfg) { h.rake_help( env: {}, app_cfg: cfg ) },
    }.each do |name, command|
      it "#{name} hands off with the project's configuration before doing anything else" do
        expect(@launchinator).to receive(:launch).with( env: {}, app_cfg: @app_cfg, config: @config ).and_raise( HandedOff )

        expect { command.call( @cli_handler, @app_cfg ) }.to raise_error( HandedOff )
        expect_no_work_done()
      end
    end

    it 'help hands off with the project\'s configuration before printing any help' do
      allow(@projectinator).to receive(:config_available?).and_return( true )
      expect(@launchinator).to receive(:launch).with( env: {}, app_cfg: @app_cfg, config: @config ).and_raise( HandedOff )
      printed = false

      expect { @cli_handler.app_help( {}, @app_cfg, {:project => nil, :mixin => []}, nil ) { printed = true } }.to raise_error( HandedOff )
      expect(printed).to be( false )
      expect_no_work_done()
    end

    it 'help for one command hands off without the project when the project fails to load' do
      allow(@projectinator).to receive(:config_available?).and_return( true )
      allow(@composinator).to receive(:loadinate).and_raise( 'Project configuration file section :mixins failed validation' )
      expect(@launchinator).to receive(:launch).with( env: {}, app_cfg: @app_cfg, config: {} ).and_raise( HandedOff )

      expect { @cli_handler.app_help( {}, @app_cfg, {:project => nil, :mixin => []}, 'build' ) { } }.to raise_error( HandedOff )
    end

    it 'help for every command still fails when the project fails to load' do
      allow(@projectinator).to receive(:config_available?).and_return( true )
      allow(@composinator).to receive(:loadinate).and_raise( 'Project configuration file section :mixins failed validation' )

      expect {
        @cli_handler.app_help( {}, @app_cfg, {:project => nil, :mixin => []}, nil ) { }
      }.to raise_error( /failed validation/ )
      expect(@launchinator).to_not have_received(:launch)
    end

    it 'help without a project hands off by environment and vendor detection alone' do
      allow(@projectinator).to receive(:config_available?).and_return( false )
      expect(@launchinator).to receive(:launch).with( env: {}, app_cfg: @app_cfg, config: {} ).and_raise( HandedOff )

      expect { @cli_handler.app_help( {}, @app_cfg, {:project => nil, :mixin => []}, 'build' ) { } }.to raise_error( HandedOff )
      expect(@composinator).to_not have_received(:loadinate)
    end

    {
      'new'      => ->(h, cfg) { h.new_project( {}, cfg, '1.2.2', {:local => true, :configs => true}, 'proj' ) },
      'examples' => ->(h, cfg) { h.list_examples( {}, cfg, {} ) },
      'example'  => ->(h, cfg) { h.create_example( {}, cfg, {:local => true}, 'temp_sensor', nil ) },
    }.each do |name, command|
      it "#{name} hands off by environment and vendor detection before doing anything else" do
        expect(@launchinator).to receive(:launch).with( env: {}, app_cfg: @app_cfg ).and_raise( HandedOff )

        expect { command.call( @cli_handler, @app_cfg ) }.to raise_error( HandedOff )
        expect_no_work_done()
      end
    end

    # GH #1365: a `--local` copy carries no documentation bundle, so it would export only licenses
    describe 'docs' do
      before(:each) do
        @launcher = Installation.new( @app_cfg[:launcher_root_path] )
        @copy = Installation.new( 'vendor/ceedling' )
        allow(@launchinator).to receive(:resolve) { |app_cfg:, **| app_cfg.set_paths( @copy.root ); @copy }
      end

      it 'hands off to the selected installation when it holds a documentation bundle' do
        allow(@helper).to receive(:docs_bundle?).with( @copy.root ).and_return( true )
        expect(@launchinator).to receive(:proceed).with( target: @copy, app_cfg: @app_cfg ).and_raise( HandedOff )

        expect { @cli_handler.docs( {}, @app_cfg, 'out' ) }.to raise_error( HandedOff )
        expect_no_work_done()
      end

      it 'exports the launcher\'s documentation, saying so, when the selected installation has none' do
        allow(@helper).to receive(:docs_bundle?).with( @copy.root ).and_return( false )

        expect(@loginator).to receive(:console).with(
          "#{@copy.describe} holds no documentation bundle to export. " +
          "Exporting the documentation of #{@launcher.describe( 'Ceedling launcher' )} instead.",
          LogLabels::NOTICE
        ).ordered
        expect(@helper).to receive(:copy_docs).with( @launcher.root, 'out' ).ordered

        @cli_handler.docs( {}, @app_cfg, 'out' )

        expect(@launchinator).to_not have_received(:proceed)
        expect(@app_cfg[:ceedling_root_path]).to eq( @launcher.root )
      end

      it 'exports the launcher\'s own documentation with no notice when it is selected' do
        allow(@launchinator).to receive(:resolve).and_return( @launcher )

        expect(@helper).to receive(:copy_docs).with( @launcher.root, 'out' )

        @cli_handler.docs( {}, @app_cfg, 'out' )

        expect(@loginator).to_not have_received(:console)
      end
    end

  it 'upgrade hands off by environment alone, never to a vendor/ceedling it detects' do
    source = Installation.new( 'elsewhere/ceedling' )
    expect(@launchinator).to receive(:resolve).with( env: {}, app_cfg: @app_cfg, detect_vendor: false ).and_return( source )
    expect(@launchinator).to receive(:proceed).with( target: source, app_cfg: @app_cfg ).and_raise( HandedOff )

    expect { @cli_handler.upgrade_project( {}, @app_cfg, {:project => 'project.yml'}, 'proj' ) }.to raise_error( HandedOff )
    expect_no_work_done()
  end

  # GH #1365: WHICH_CEEDLING naming the project's own copy would hand off to it, and a copy
  # before 1.2.2 deletes itself as its own source
  it 'upgrade refuses to re-vendor a project from its own vendored copy, before handing off to it' do
    allow(@launchinator).to receive(:resolve) { |app_cfg:, **| app_cfg.set_paths( 'proj/vendor/ceedling' ); Installation.new( 'proj/vendor/ceedling' ) }

    expect {
      @cli_handler.upgrade_project( {'WHICH_CEEDLING' => 'proj/vendor/ceedling'}, @app_cfg, {:project => 'project.yml'}, 'proj' )
    }.to raise_error( CeedlingException, /Cannot upgrade #{Regexp.escape( File.expand_path( 'proj/vendor/ceedling' ) )}\/ from itself/ )
    expect(@launchinator).to_not have_received(:proceed)
    expect_no_work_done()
  end
end

  describe '#list_examples' do
    it 'raises when no example projects are found' do
      allow(@helper).to receive(:lookup_example_projects).and_return( [] )

      expect {
        @cli_handler.list_examples( {}, CeedlingAppConfig.new, {} )
      }.to raise_error( 'No examples projects found' )
    end

    it 'lists each example project found' do
      allow(@helper).to receive(:lookup_example_projects).and_return( ['blinky', 'temp_sensor'] )

      # #list_examples logs the listing and a separate documentation pointer --
      # collect every console call rather than assume a single message.
      messages = []
      allow(@loginator).to receive(:console) {|message, _label| messages << message }

      @cli_handler.list_examples( {}, CeedlingAppConfig.new, {} )

      listing = messages.join
      expect(listing).to include( 'blinky' )
      expect(listing).to include( 'temp_sensor' )
    end
  end

  describe '#standardize_project_and_mixins (private)' do
    before(:each) do
      real_path_validator = PathValidator.new({
        :file_wrapper => double('file_wrapper').as_null_object,
        :loginator    => double('loginator').as_null_object,
      })
      real_cli_helper = CliHelper.new({
        :file_wrapper       => double('file_wrapper').as_null_object,
        :actionator         => double('actionator').as_null_object,
        :config_walkinator  => double('config_walkinator').as_null_object,
        :path_validator     => real_path_validator,
        :rake_task_registry => double('rake_task_registry').as_null_object,
        :loginator          => double('loginator').as_null_object,
        :reportinator       => double('reportinator').as_null_object,
        :system_wrapper     => double('system_wrapper').as_null_object,
        :ruby_expandinator  => RubyExpandinator.new,
      })

      @cli_handler_real = described_class.new({
        :composinator       => double('composinator').as_null_object,
        :projectinator      => double('projectinator').as_null_object,
        :cli_helper         => real_cli_helper,
        :path_validator     => real_path_validator,
        :rake_task_registry => double('rake_task_registry').as_null_object,
        :actionator         => double('actionator').as_null_object,
        :launchinator       => double('launchinator').as_null_object,
        :loginator          => double('loginator').as_null_object,
      })
    end

    def standardize(project, mixins)
      @cli_handler_real.send( :standardize_project_and_mixins, project, mixins )
    end

    it 'standardizes backslashes in the project path' do
      project, _mixins = standardize( 'some\\project.yml', [] )

      expect(project).to eq( 'some/project.yml' )
    end

    it 'standardizes filepath/name mixin entries but leaves inline YAML entries untouched' do
      inline_yaml = "=:project:\n  :build_root: some\\path"

      _project, mixins = standardize( nil, ['mixin\\dir\\clang.yml', inline_yaml] )

      expect(mixins).to eq( ['mixin/dir/clang.yml', inline_yaml] )
    end

    it 'standardizes each occurrence of a repeated mixin value independently' do
      _project, mixins = standardize( nil, ['dup\\path.yml', 'other\\path.yml', 'dup\\path.yml'] )

      expect(mixins).to eq( ['dup/path.yml', 'other/path.yml', 'dup/path.yml'] )
    end

    it 'passes a nil project through unchanged' do
      project, _mixins = standardize( nil, [] )

      expect(project).to be_nil
    end
  end
end
