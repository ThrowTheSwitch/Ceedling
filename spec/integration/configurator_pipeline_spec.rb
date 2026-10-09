# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for the whole configuration pipeline.
#
# A project configuration written as YAML runs through the real Setupinator and the real
# configurator object graph inside a temp project directory. Each example checks what a
# build would then read: accessors, constants, build directories, vendored frameworks,
# file collections, and the environment. The unit specs beneath spec/units/config/ own
# each step's decisions through doubles.

require 'spec_helper'
require 'configurator_integration_helper'

describe 'Configurator pipeline (integration)' do
  include ConfiguratorIntegrationHelpers

  after(:each) { remove_tracked_constants }

  it 'builds accessors, constants, directories, vendored Unity, and collections for a minimal project' do
    in_temp_project( minimal_project_files ) do
      configurator = configure( minimal_project_yaml )[:configurator]

      expect(configurator.project_build_root).to eq('build')
      expect(configurator.project_use_mocks).to be true
      expect(configurator.collection_all_tests).to eq(['test/test_adder.c'])
      expect(configurator.collection_all_source).to eq(['src/adder.c'])
      expect(configurator.collection_all_headers).to include('src/adder.h')
      expect(Object.const_get( :PROJECT_TEST_BUILD_OUTPUT_PATH )).to eq('build/test/out')
      expect(File.directory?( 'build/test/out' )).to be true
      expect(File.exist?( 'build/vendor/unity/src/unity.c' )).to be true
    end
  end

  it 'adds and removes files through :files' do
    files = minimal_project_files.merge( 'extra/adder_extra.c' => "\n", 'src/generated.c' => "\n" )

    in_temp_project( files ) do
      configurator = configure( minimal_project_yaml + ":files:\n  :source:\n    - +:extra/adder_extra.c\n    - -:src/generated.c\n" )[:configurator]

      expect(configurator.collection_all_source).to match_array(['src/adder.c', 'extra/adder_extra.c'])
    end
  end

  it 'vendors CMock and creates mock directories only when mocks are in use' do
    in_temp_project( minimal_project_files ) do
      configurator = configure( minimal_project_yaml )[:configurator]

      expect(configurator.cmock_mock_path).to eq('build/test/mocks')
      expect(File.directory?( 'build/test/mocks' )).to be true
      expect(File.exist?( 'build/vendor/cmock/src/cmock.c' )).to be true
    end

    in_temp_project( minimal_project_files ) do
      configure( minimal_project_yaml.sub( "  :build_root: build\n", "  :build_root: build\n  :use_mocks: false\n" ) )

      expect(File.exist?( 'build/test/mocks' )).to be false
      expect(File.exist?( 'build/vendor/cmock' )).to be false
    end
  end

  it 'turns on mocks and full preprocessing for Partials' do
    in_temp_project( minimal_project_files ) do
      configurator = configure( minimal_project_yaml.sub( "  :build_root: build\n", "  :build_root: build\n  :use_partials: true\n" ) )[:configurator]

      expect(configurator.project_use_mocks).to be true
      expect(configurator.project_use_test_preprocessor).to eq(:all)
      expect(File.exist?( 'build/vendor/ceedling/ceedling.h' )).to be true
    end
  end

  it 'resolves :auto thread counts against the real processor count' do
    in_temp_project( minimal_project_files ) do
      yaml = minimal_project_yaml.sub( "  :build_root: build\n", "  :build_root: build\n  :compile_threads: :auto\n  :test_threads: 2\n" )
      configurator = configure( yaml )[:configurator]

      expect(configurator.project_compile_threads).to eq( Etc.nprocessors + 4 )
      expect(configurator.project_test_threads).to eq(2)
    end
  end

  it 'refuses a configuration missing a required section' do
    in_temp_project( minimal_project_files ) do
      expect { configure( ":project:\n  :build_root: build\n" ) }.to raise_error(CeedlingException, /failed validation/)
      expect(logged).to include('Required config file entry :paths does not exist.')
    end
  end

  it 'refuses a path that does not exist' do
    in_temp_project( minimal_project_files ) do
      expect { configure( minimal_project_yaml + "  :support: [test/support]\n" ) }.to raise_error(CeedlingException, /failed validation/)
      expect(logged.join).to include("Config path :paths ↳ :support => 'test/support' does not exist in the filesystem.")
    end
  end

  describe ':environment' do
    around(:each) do |example|
      saved = ENV.to_h
      example.run
    ensure
      ENV.replace( saved )
    end

    it 'sets each variable, joining a :path list with the platform separator' do
      in_temp_project( minimal_project_files ) do
        path = ENV['PATH']
        configure( minimal_project_yaml + ":environment:\n  - :path: [/opt/a, '#{path}']\n  - :ceedling_spec_flags: [-O2, -g]\n" )

        expect(ENV['PATH']).to eq("/opt/a#{File::PATH_SEPARATOR}#{path}")
        expect(ENV['CEEDLING_SPEC_FLAGS']).to eq('-O2 -g')
      end
    end
  end
end
