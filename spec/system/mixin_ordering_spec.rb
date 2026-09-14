# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Mixin Loading -- CLI-surface smoke
## =====================================
##
## The precedence/dedup/ordering/sigil/:tools-append merge mechanics --
## everything about *how* mixins combine once Ceedling has them in hand --
## moved to spec/integration/mixin_loading_spec.rb: real Composinator/
## Mixinator/MixinResolvinator graph, real filesystem, no CLI subprocess,
## proving the same object graph the CLI uses end to end without paying for
## a full build harness per scenario. That migration is this session's own
## Stage 2 plan, Finding 6 -- mixin merging is config-hash transformation
## logic, not CLI or OS behavior, and it already has 1,970 lines of dedicated
## unit coverage across composinator_spec.rb, mixinator_spec.rb,
## mixin_resolvinator_spec.rb, recursive_merger_spec.rb, mixin_standardizer_spec.rb,
## and merginator_spec.rb.
##
## What's left here is narrower and genuinely CLI-specific: does `--mixin`
## actually get read from the real command line, does `CEEDLING_MIXIN_*`
## actually get read from the real process environment, does a project's own
## `:mixins` config section actually get read from a real file, and does the
## whole pipeline actually exit non-zero on bad input -- all questions only a
## real `ceedling` subprocess can answer.
##

ORDERING_MIXIN_CMDLINE = <<~YAML
  :paths:
    :include: []
YAML

ORDERING_MIXIN_ENV = <<~YAML
  :paths:
    :include: []
YAML

ORDERING_MIXIN_CONFIG = <<~YAML
  :paths:
    :include: []
YAML

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
  describe 'Mixin loading :: single-source smoke tests' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'loads a mixin via config :enabled and logs its use' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/smoke_config.yml', ORDERING_MIXIN_CONFIG)
          @c.merge_project_yml_for_test({mixins: {enabled: ['smoke_config']}})

          @output = @c.ceedling_build_exec('files:header --verbosity=obnoxious')
        end
      end
      expect(@output).to match(/Merging project configuration mixin/i)
    end

    it 'loads a mixin via CEEDLING_MIXIN_1 env var and logs its use' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/smoke_env.yml', ORDERING_MIXIN_ENV)
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/smoke_env.yml')

          @output = @c.ceedling_build_exec('files:header --verbosity=obnoxious')
        end
      end
      expect(@output).to match(/Merging CEEDLING_MIXIN_1 mixin/i)
    end

    it 'loads a mixin via --mixin cmdline flag and logs its use' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/smoke_cmdline.yml', ORDERING_MIXIN_CMDLINE)

          @output = @c.ceedling_build_exec(
            'files:header --verbosity=obnoxious --mixin=mixin/smoke_cmdline.yml'
          )
        end
      end
      expect(@output).to match(/Merging command line mixin/i)
    end

    it 'ignores CEEDLING_MIXIN_0' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_zero.yml', ORDERING_MIXIN_ENV)
          ENV['CEEDLING_MIXIN_0'] = convert_slashes('mixin/mixin_zero.yml')

          @output = @c.ceedling_build_exec('files:header --verbosity=obnoxious')
        end
      end
      expect(@output).not_to match(/Merging CEEDLING_MIXIN_0/i)
    end
  end

  # =========================================================================
  describe 'Mixin loading :: error handling' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'exits with error when --mixin points to a missing file' do
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec('files:header --mixin=mixin/does_not_exist.yml')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end

    it 'exits with error when :enabled contains a name not found in load_paths' do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({mixins: {enabled: ['nonexistent_mixin_name']}})

          @output = @c.ceedling_build_exec('files:header')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end

    it 'exits with error when CEEDLING_MIXIN_1 points to a missing file' do
      @c.with_context do
        Dir.chdir @proj_name do
          ENV['CEEDLING_MIXIN_1'] = 'mixin/does_not_exist.yml'
          @output = @c.ceedling_build_exec('files:header')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end
  end
end
