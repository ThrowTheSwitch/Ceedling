# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'app_cfg'

describe CeedlingAppConfig do
  before(:each) do
    @app_cfg = described_class.new
  end

  describe 'initialization' do
    it 'derives ceedling_root_path from this file\'s own location' do
      expected_root = File.expand_path( File.join( File.dirname( __FILE__ ), '../../../bin', '..' ) )

      expect(@app_cfg[:ceedling_root_path]).to eq( expected_root )
    end

    it 'sets default_tasks to test:all' do
      expect(@app_cfg[:default_tasks]).to eq( ['test:all'] )
    end

    it 'defaults force_test_rerun to false' do
      expect(@app_cfg[:force_test_rerun]).to eq( false )
    end
  end

  describe '#set_paths' do
    it 'derives every dependent path from the given root path' do
      @app_cfg.set_paths( '/tmp/some/root' )

      root = File.expand_path( '/tmp/some/root' )
      expect(@app_cfg[:ceedling_root_path]).to eq( root )
      expect(@app_cfg[:ceedling_lib_base_path]).to eq( File.join( root, 'lib' ) )
      expect(@app_cfg[:ceedling_lib_path]).to eq( File.join( root, 'lib', 'ceedling' ) )
      expect(@app_cfg[:ceedling_vendor_path]).to eq( File.join( root, 'vendor' ) )
      expect(@app_cfg[:ceedling_plugins_path]).to eq( File.join( root, 'plugins' ) )
      expect(@app_cfg[:ceedling_examples_path]).to eq( File.join( root, 'examples' ) )
      expect(@app_cfg[:ceedling_rakefile_filepath]).to eq( File.join( root, 'lib', 'ceedling', 'rakefile.rb' ) )
    end
  end

  describe 'simple setters' do
    it '#set_project_config updates :project_config' do
      @app_cfg.set_project_config( {:project => {}} )
      expect(@app_cfg[:project_config]).to eq( {:project => {}} )
    end

    it '#set_logging_path updates :logging_path' do
      @app_cfg.set_logging_path( 'build/logs' )
      expect(@app_cfg[:logging_path]).to eq( 'build/logs' )
    end

    it '#set_log_filepath updates :log_filepath' do
      @app_cfg.set_log_filepath( 'build/logs/ceedling.log' )
      expect(@app_cfg[:log_filepath]).to eq( 'build/logs/ceedling.log' )
    end

    it '#set_include_test_case updates :include_test_case' do
      @app_cfg.set_include_test_case( 'configure' )
      expect(@app_cfg[:include_test_case]).to eq( 'configure' )
    end

    it '#set_exclude_test_case updates :exclude_test_case' do
      @app_cfg.set_exclude_test_case( 'configure' )
      expect(@app_cfg[:exclude_test_case]).to eq( 'configure' )
    end

    it '#set_force_test_rerun updates :force_test_rerun' do
      @app_cfg.set_force_test_rerun( true )
      expect(@app_cfg[:force_test_rerun]).to eq( true )
    end

    it '#set_build_tasks updates :build_tasks? and #build_tasks?' do
      @app_cfg.set_build_tasks( true )
      expect(@app_cfg[:build_tasks?]).to eq( true )
      expect(@app_cfg.build_tasks?).to eq( true )
    end

    it '#set_tests_graceful_fail updates :tests_graceful_fail? and #tests_graceful_fail?' do
      @app_cfg.set_tests_graceful_fail( true )
      expect(@app_cfg[:tests_graceful_fail?]).to eq( true )
      expect(@app_cfg.tests_graceful_fail?).to eq( true )
    end
  end
end
