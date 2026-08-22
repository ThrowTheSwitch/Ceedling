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
    @loginator = double('loginator').as_null_object
    @helper    = double('cli_helper').as_null_object

    @cli_handler = described_class.new({
      :composinator       => double('composinator').as_null_object,
      :projectinator      => double('projectinator').as_null_object,
      :cli_helper         => @helper,
      :path_validator     => double('path_validator').as_null_object,
      :rake_task_registry => double('rake_task_registry').as_null_object,
      :actions_wrapper    => double('actions_wrapper').as_null_object,
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
        expect(message).to include( 'Ceedling Launcher => 1.2.0' )
        expect(message).to include( 'Ceedling App => 1.2.0' )
      end

      @cli_handler.version( {}, @app_cfg )
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
        :actions_wrapper    => double('actions_wrapper').as_null_object,
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
        :actions_wrapper    => double('actions_wrapper').as_null_object,
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
