# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = 'temp_sensor' }

  # =========================================================================
  describe 'Inline Ruby string expansion :: disabled by default' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    # Confirms the feature is a no-op when unused -- a project with no `#{...}` anywhere
    # must build cleanly with no --ruby-replacement flag at all. Guards against the gate
    # accidentally interfering with the common case (most projects never touch this
    # feature).
    it 'builds successfully with no inline Ruby expansion in the project and no flag' do
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec('files:header')
        end
      end
      expect(@c.last_exit_status).to eq(0)
    end
  end

  # =========================================================================
  describe 'Inline Ruby string expansion :: :defines' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    # Core security behavior at the CLI boundary: a real `dumpconfig` invocation against
    # a project.yml containing `#{...}` in :defines, with the flag omitted, must fail
    # loudly rather than silently ignoring or mis-evaluating the expression. The exception
    # message itself must reach the console and explicitly point the user at the fix
    # (--ruby-replacement) and name the actual config section (:defines) -- not just a
    # generic failure -- confirming the "location" context RubyExpandinator threads through.
    it 'exits non-zero and names the flag and section when :defines expansion is blocked' do
      @c.with_context do
        Dir.chdir @proj_name do
          # Single-quoted so Ruby does not interpolate this literal `#{...}` text --
          # only Ceedling's own runtime expansion should ever evaluate it.
          @c.merge_project_yml_for_test({
            defines: { test: { ruby_replacement_test: ['RUBY_TEST_SYM_#{1+1}'] } }
          })

          dump_file = 'dump_defines_disabled.yml'
          @output = @c.ceedling_appcmd_exec("dumpconfig #{dump_file} defines")
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
      expect(@output).to match(/--ruby-replacement/i)
      expect(@output).to match(/:defines/i)
    end

    # Opting in via the flag must actually work end-to-end: dumpconfig succeeds and the
    # dumped YAML contains the truly-evaluated result ("RUBY_TEST_SYM_2"), not the literal
    # `#{1+1}` text and not some stale/unexpanded value.
    it 'expands a :defines Ruby expression into the dumped config when --ruby-replacement is passed' do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({
            defines: { test: { ruby_replacement_test: ['RUBY_TEST_SYM_#{1+1}'] } }
          })

          dump_file = 'dump_defines_enabled.yml'
          @c.ceedling_appcmd_exec("dumpconfig #{dump_file} defines --ruby-replacement")
          @dump_text = File.exist?(dump_file) ? File.read(dump_file) : ''
        end
      end
      expect(@c.last_exit_status).to eq(0)
      expect(@dump_text).to include('RUBY_TEST_SYM_2')
      expect(@dump_text).not_to include('#{1+1}')
    end
  end

  # =========================================================================
  describe 'Inline Ruby string expansion :: :environment' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    # Same disabled behavior as :defines, but for :environment -- a different code path
    # (Configurator#eval_environment_variables) -- giving this pass two independently
    # verified call sites instead of exercising :defines twice under different names.
    it 'exits non-zero and names the flag and section when :environment expansion is blocked' do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({
            environment: [ { ruby_replacement_test_var: 'RUBY_TEST_VALUE_#{1+1}' } ]
          })

          @output = @c.ceedling_appcmd_exec('environment')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
      expect(@output).to match(/--ruby-replacement/i)
      expect(@output).to match(/:environment/i)
    end

    # Verified through the real `ceedling environment` command's own variable listing,
    # rather than dumpconfig -- confirms expansion reaches an entirely separate command
    # that reads the same configuration pipeline.
    it 'prints the expanded value via `ceedling environment` when --ruby-replacement is passed' do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({
            environment: [ { ruby_replacement_test_var: 'RUBY_TEST_VALUE_#{1+1}' } ]
          })

          @output = @c.ceedling_appcmd_exec('environment --ruby-replacement')
        end
      end
      expect(@c.last_exit_status).to eq(0)
      expect(@output).to match(/RUBY_TEST_VALUE_2/)
      expect(@output).not_to match(/#\{1\+1\}/)
    end
  end
end
