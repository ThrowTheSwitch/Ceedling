# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# Trivial mixin YAML content used as loading fixtures. These add harmless
# entries to :paths so the merge has no side effects on the test build.
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

# Scalar-valued mixins for precedence testing. Each sets :project ↳ :build_root
# to a distinct value so we can verify which one wins after merging.
SCALAR_MIXIN_LOW  = <<~YAML
  :project:
    :build_root: build_low
YAML

SCALAR_MIXIN_HIGH = <<~YAML
  :project:
    :build_root: build_high
YAML

# Array-valued mixins for env-var ordering tests. Each appends a unique marker
# to :plugins ↳ :enabled so we can verify the merged array element order.
ARRAY_MIXIN_1 = <<~YAML
  :plugins:
    :enabled:
      - marker_from_mixin_1
YAML

ARRAY_MIXIN_2 = <<~YAML
  :plugins:
    :enabled:
      - marker_from_mixin_2
YAML

ARRAY_MIXIN_3 = <<~YAML
  :plugins:
    :enabled:
      - marker_from_mixin_3
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
  describe 'Mixin loading :: deduplication' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'deduplicates mixin listed in :enabled and --mixin cmdline' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/shared.yml', ORDERING_MIXIN_CONFIG)
          @c.merge_project_yml_for_test({mixins: {enabled: ['shared']}})

          @output = @c.ceedling_build_exec(
            'files:header --verbosity=obnoxious --mixin=mixin/shared.yml'
          )
        end
      end
      expect(@output.to_s.scan(/Merging.*mixin.*shared/i).length).to eq(1)
    end

    it 'deduplicates mixin listed in env var and --mixin cmdline' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/shared.yml', ORDERING_MIXIN_CONFIG)
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/shared.yml')

          @output = @c.ceedling_build_exec(
            'files:header --verbosity=obnoxious --mixin=mixin/shared.yml'
          )
        end
      end
      expect(@output.to_s.scan(/Merging.*mixin.*shared/i).length).to eq(1)
    end
  end

  # =========================================================================
  describe 'Mixin loading :: merge order' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'logs merge order as [config, env, cmdline]' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/ordering_config.yml',   ORDERING_MIXIN_CONFIG)
          File.write('mixin/ordering_env.yml',      ORDERING_MIXIN_ENV)
          File.write('mixin/ordering_cmdline.yml',  ORDERING_MIXIN_CMDLINE)
          @c.merge_project_yml_for_test({mixins: {enabled: ['ordering_config']}})
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/ordering_env.yml')

          @output = @c.ceedling_build_exec(
            'files:header --verbosity=obnoxious --mixin=mixin/ordering_cmdline.yml'
          )
        end
      end

      output_str   = @c.raw_output
      cmdline_pos  = output_str.index('Merging command line mixin')
      env_pos      = output_str.index('Merging CEEDLING_MIXIN_1 mixin')
      config_pos   = output_str.index('Merging project configuration mixin')

      expect(cmdline_pos).not_to be_nil
      expect(env_pos).not_to be_nil
      expect(config_pos).not_to be_nil

      # Per loading.md: config logged first (merged first), env second, cmdline last (merged last, wins)
      expect(config_pos).to be < env_pos
      expect(env_pos).to be < cmdline_pos
    end

    it 'lower-numbered mixin env var merges first; higher-numbered wins' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_low.yml',  SCALAR_MIXIN_LOW)
          File.write('mixin/mixin_high.yml', SCALAR_MIXIN_HIGH)
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/mixin_low.yml')
          ENV['CEEDLING_MIXIN_5'] = convert_slashes('mixin/mixin_high.yml')

          @output = @c.ceedling_build_exec('files:header --verbosity=obnoxious')
        end
      end

      output_str = @c.raw_output
      mixin_1_pos = output_str.index('Merging CEEDLING_MIXIN_1 mixin')
      mixin_5_pos = output_str.index('Merging CEEDLING_MIXIN_5 mixin')

      expect(mixin_1_pos).not_to be_nil
      expect(mixin_5_pos).not_to be_nil

      # Per loading.md: MIXIN_1 logged first (merged first), MIXIN_5 logged last (merged last, wins)
      expect(mixin_1_pos).to be < mixin_5_pos
    end

    it 'env var array mixins merge in ascending numeric order' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/array_mixin_1.yml', ARRAY_MIXIN_1)
          File.write('mixin/array_mixin_2.yml', ARRAY_MIXIN_2)
          File.write('mixin/array_mixin_3.yml', ARRAY_MIXIN_3)
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/array_mixin_1.yml')
          ENV['CEEDLING_MIXIN_2'] = convert_slashes('mixin/array_mixin_2.yml')
          ENV['CEEDLING_MIXIN_3'] = convert_slashes('mixin/array_mixin_3.yml')

          @output = @c.ceedling_build_exec('files:header --verbosity=obnoxious')
        end
      end

      output_str = @c.raw_output
      pos_1 = output_str.index('Merging CEEDLING_MIXIN_1 mixin')
      pos_2 = output_str.index('Merging CEEDLING_MIXIN_2 mixin')
      pos_3 = output_str.index('Merging CEEDLING_MIXIN_3 mixin')

      expect(pos_1).not_to be_nil
      expect(pos_2).not_to be_nil
      expect(pos_3).not_to be_nil

      # Per loading.md: ascending numeric order in the log means MIXIN_1
      # logged first, MIXIN_3 logged last — so MIXIN_3 array value appears
      # after MIXIN_1's in the merged :plugins ↳ :enabled array.
      expect(pos_1).to be < pos_2
      expect(pos_2).to be < pos_3
    end
  end

  # =========================================================================
  describe 'Mixin loading :: overall source precedence' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'cmdline mixin overrides config mixin scalar value' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_cfg.yml', SCALAR_MIXIN_LOW)
          File.write('mixin/mixin_cli.yml', SCALAR_MIXIN_HIGH)
          @c.merge_project_yml_for_test({mixins: {enabled: ['mixin_cfg']}})

          dump_file = 'dump_cmdline_over_config.yml'
          @c.ceedling_appcmd_exec(
            "dumpconfig --mixin=#{convert_slashes('mixin/mixin_cli.yml')} --no-app #{dump_file}"
          )
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # SCALAR_MIXIN_HIGH sets build_root: build_high; cmdline wins over config
      expect(@dump_config.dig(:project, :build_root)).to eq('build_high')
    end

    it 'env var mixin overrides config mixin scalar value' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_cfg.yml', SCALAR_MIXIN_LOW)
          File.write('mixin/mixin_env.yml', SCALAR_MIXIN_HIGH)
          @c.merge_project_yml_for_test({mixins: {enabled: ['mixin_cfg']}})
          ENV['CEEDLING_MIXIN_1'] = convert_slashes('mixin/mixin_env.yml')

          dump_file = 'dump_env_over_config.yml'
          @c.ceedling_appcmd_exec("dumpconfig --no-app #{dump_file}")
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # SCALAR_MIXIN_HIGH sets build_root: build_high; env var wins over config
      expect(@dump_config.dig(:project, :build_root)).to eq('build_high')
    end
  end

  # =========================================================================
  describe 'Mixin loading :: --mixin inline YAML (= sigil)' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'loads inline YAML and logs its use at obnoxious verbosity' do
      # '=...' sigil form: value is passed as a separate shell argument quoted to protect YAML chars
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec(
            'files:header --verbosity=obnoxious --mixin "=paths: {include: []}"'
          )
        end
      end
      expect(@output).to match(/Merging command line inline YAML mixin/i)
    end

    it 'merges inline YAML value into configuration' do
      @c.with_context do
        Dir.chdir @proj_name do
          dump_file = 'dump_inline_yaml_merge.yml'
          @c.ceedling_appcmd_exec(
            "dumpconfig --no-app #{dump_file} --mixin \"=project: {build_root: inline_build_test}\""
          )
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # The inline YAML must appear in the dumped merged configuration
      expect(@dump_config.dig(:project, :build_root)).to eq('inline_build_test')
    end

    it 'inline YAML wins scalar conflict when it follows a file mixin (left-to-right order)' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_low.yml', SCALAR_MIXIN_LOW)

          dump_file = 'dump_inline_wins.yml'
          @c.ceedling_appcmd_exec(
            "dumpconfig --no-app #{dump_file}" \
            " --mixin #{convert_slashes('mixin/mixin_low.yml')}" \
            ' --mixin "=project: {build_root: build_high}"'
          )
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # Inline YAML comes second, so it wins the scalar conflict
      expect(@dump_config.dig(:project, :build_root)).to eq('build_high')
    end

    it 'file mixin wins scalar conflict when it follows inline YAML (left-to-right order)' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_high.yml', SCALAR_MIXIN_HIGH)

          dump_file = 'dump_file_wins.yml'
          @c.ceedling_appcmd_exec(
            "dumpconfig --no-app #{dump_file}" \
            ' --mixin "=project: {build_root: build_low}"' \
            " --mixin #{convert_slashes('mixin/mixin_high.yml')}"
          )
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # File mixin comes second, so it wins the scalar conflict
      expect(@dump_config.dig(:project, :build_root)).to eq('build_high')
    end

    it 'three-way positional order: file-low, inline-mid, file-high → file-high wins' do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('mixin/mixin_low.yml',  SCALAR_MIXIN_LOW)
          File.write('mixin/mixin_high.yml', SCALAR_MIXIN_HIGH)

          dump_file = 'dump_three_way.yml'
          @c.ceedling_appcmd_exec(
            "dumpconfig --no-app #{dump_file}" \
            " --mixin #{convert_slashes('mixin/mixin_low.yml')}" \
            ' --mixin "=project: {build_root: build_mid}"' \
            " --mixin #{convert_slashes('mixin/mixin_high.yml')}"
          )
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # Rightmost --mixin wins; file-high is last → build_high
      expect(@dump_config.dig(:project, :build_root)).to eq('build_high')
    end

    it 'exits with error for non-Hash inline YAML (array value)' do
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec('files:header --mixin "=- just_a_list_item"')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end

    it 'exits with error for invalid YAML in inline mixin' do
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec('files:header --mixin "={{{ broken yaml"')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end

    it 'exits with error for empty inline YAML (bare = sigil with no content)' do
      @c.with_context do
        Dir.chdir @proj_name do
          @output = @c.ceedling_build_exec('files:header --mixin "="')
        end
      end
      expect(@c.last_exit_status).not_to eq(0)
    end
  end

  # =========================================================================
  describe 'Mixin loading :: built-in load paths (unity/targets)' do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec('example temp_sensor')
      end
    end

    it 'loads gcc_64 by name via --mixin from built-in unity/targets load path' do
      @c.with_context do
        Dir.chdir @proj_name do
          dump_file = 'dump_gcc64_cmdline.yml'
          @c.ceedling_appcmd_exec("dumpconfig --no-app #{dump_file} --mixin gcc_64")
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # :defines ↳ :test may be a plain Array or a matcher Hash ({:* => [...]}) depending on
      # whether the project config already uses the matcher format; flatten either way
      defines_test = @dump_config.dig(:defines, :test)
      defines_list = defines_test.is_a?(Hash) ? defines_test.values.flatten : Array(defines_test)
      expect(defines_list).to include('UNITY_SUPPORT_64')
    end

    it 'loads gcc_64 by name via config :enabled from built-in unity/targets load path' do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({mixins: {enabled: ['gcc_64']}})

          dump_file = 'dump_gcc64_config.yml'
          @c.ceedling_appcmd_exec("dumpconfig --no-app #{dump_file}")
          @dump_config = File.exist?(dump_file) ? YAML.load(File.read(dump_file)) : {}
        end
      end
      # :defines ↳ :test may be a plain Array or a matcher Hash ({:* => [...]}) depending on
      # whether the project config already uses the matcher format; flatten either way
      defines_test = @dump_config.dig(:defines, :test)
      defines_list = defines_test.is_a?(Hash) ? defines_test.values.flatten : Array(defines_test)
      expect(defines_list).to include('UNITY_SUPPORT_64')
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
