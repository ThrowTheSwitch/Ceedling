# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# The Command Hooks plugin through a real test build. Every test build hook runs a script
# that records the hook's name and arguments, which shows each hook fires with the
# argument its documentation promises. This is the one place the contract between
# Ceedling's build steps and the plugin's argument handling is exercised end to end.
ceedling_system_tests do
  describe 'Command Hooks' do

    # Appends a line naming the hook and each argument it received
    COMMAND_HOOKS_SYSTEM_RECORDER = "File.open( 'hooks.log', 'a' ) { |log| log.puts ARGV.join( ' | ' ) }\n".freeze

    COMMAND_HOOKS_SYSTEM_HOOKS = %i[
      pre_mock_preprocess post_mock_preprocess pre_test_preprocess post_test_preprocess
      pre_mock_generate post_mock_generate pre_runner_generate post_runner_generate
      pre_compile_execute post_compile_execute pre_link_execute post_link_execute
      pre_test_fixture_execute post_test_fixture_execute pre_test post_test
      pre_test_build post_test_build pre_build post_build
    ].freeze

    # The first argument each hook should record
    COMMAND_HOOKS_SYSTEM_EXPECTED = {
      pre_mock_preprocess:       %r{\Asrc/example_file\.h\z},
      post_mock_preprocess:      %r{\Asrc/example_file\.h\z},
      pre_test_preprocess:       %r{\Atest/test_example_file_with_mock\.c\z},
      post_test_preprocess:      %r{\Atest/test_example_file_with_mock\.c\z},
      pre_mock_generate:         %r{example_file\.h\z},
      post_mock_generate:        %r{example_file\.h\z},
      pre_runner_generate:       %r{\Atest/test_example_file_with_mock\.c\z},
      post_runner_generate:      %r{test_example_file_with_mock_runner\.c\z},
      pre_compile_execute:       /\.c\z/,
      post_compile_execute:      /\.c\z/,
      pre_link_execute:          /test_example_file_with_mock\.out\z/,
      post_link_execute:         /test_example_file_with_mock\.out\z/,
      pre_test_fixture_execute:  /test_example_file_with_mock\.out\z/,
      post_test_fixture_execute: /test_example_file_with_mock\.out\z/,
      pre_test:                  %r{\Atest/test_example_file_with_mock\.c\z},
      post_test:                 %r{\Atest/test_example_file_with_mock\.c\z},
      pre_test_build:            /\Atest\z/,
      post_test_build:           /\Atest\z/,
      pre_build:                 /\A\d+(\.\d+)?\z/,
      post_build:                /\A\d+(\.\d+)?\z/
    }.freeze

    before :all do
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = unique_proj_name( 'command_hooks' ) }

    def recording_hook(hook)
      arguments = ['record.rb', hook.to_s, '"${1}"']
      arguments << '"${2}"' if %i[pre_compile_execute post_compile_execute].include?( hook )
      return { executable: 'ruby', arguments: arguments }
    end

    def prep_project
      FileUtils.cp feature_asset_path( 'project.yml' ), 'project.yml'
      @c.uncomment_project_yml_option_for_test( '- command_hooks' )
      @c.merge_project_yml_for_test(
        project:       { use_test_preprocessor: :all },
        command_hooks: COMMAND_HOOKS_SYSTEM_HOOKS.to_h { |hook| [hook, recording_hook( hook )] }
      )
      File.write( 'record.rb', COMMAND_HOOKS_SYSTEM_RECORDER )
      FileUtils.cp test_asset_path( 'example_file.h' ), 'src/'
      FileUtils.cp test_asset_path( 'example_file.c' ), 'src/'
      FileUtils.cp test_asset_path( 'example_file_call.h' ), 'src/'
      FileUtils.cp test_asset_path( 'example_file_call.c' ), 'src/'
      FileUtils.cp test_asset_path( 'test_example_file_with_mock.c' ), 'test/'
    end

    # Each hook's recorded calls, as lists of the arguments it received
    def recorded
      return File.readlines( 'hooks.log', chomp: true ).map { |line| line.split( ' | ', -1 ) }
                 .group_by( &:first ).transform_values { |calls| calls.map { |call| call.drop( 1 ) } }
    end

    it 'runs every test build hook with its documented argument, and no build hook for clobber' do
      @c.with_context do
        @c.ceedling_appcmd_exec( "new --local #{@proj_name}" )

        Dir.chdir @proj_name do
          prep_project
          output = @c.ceedling_build_exec( 'test:all' )
          expect(@c.last_exit_status).to eq( 0 ), output

          calls = recorded
          COMMAND_HOOKS_SYSTEM_HOOKS.each do |hook|
            expect(calls).to have_key( hook.to_s ), "expected :#{hook} to run"
            expect(calls[hook.to_s].map( &:first )).to all( match( COMMAND_HOOKS_SYSTEM_EXPECTED[hook] ) ), ":#{hook} received #{calls[hook.to_s].inspect}"
          end

          # Compile hooks also receive the object file
          expect(calls['post_compile_execute'].map( &:last )).to all( match( /\.o\z/ ) )

          # Build hooks fire only for build tasks (#194)
          File.delete( 'hooks.log' )
          @c.ceedling_build_exec( 'clobber' )
          expect(File.exist?( 'hooks.log' )).to be false
        end
      end
    end

  end
end
