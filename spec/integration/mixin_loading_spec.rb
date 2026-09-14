# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for mixin loading and merging -- real Composinator +
# Projectinator + MixinResolvinator + Mixinator + MixinStandardizer + Merginator
# + RecursiveMerger, real YAML files on a real temp directory, real ENV
# manipulation. No `ceedling` CLI subprocess and no gem deployment: mixin
# merging is project-configuration-hash transformation, not CLI or OS
# behavior, so a real object graph proves it without paying for a real build
# harness.
#
# This is PR 4 of the system-test redesign (Stage 2 plan, Finding 6), split
# out of the system-tier spec/system/mixin_ordering_spec.rb, which originally
# ran every one of these scenarios through a full `dumpconfig --no-app` CLI
# round-trip. Two things kept this spec from being a flat 1:1 port:
#
#   1. Real filesystem resolution (project directory as an implicit load
#      path, the built-in vendor/unity/test/targets/ path, a custom
#      :extension ↳ :yaml) is exercised nowhere else -- every unit spec for
#      these collaborators (composinator_spec.rb, mixinator_spec.rb,
#      mixin_resolvinator_spec.rb) stubs `file_wrapper`/`load_paths` away.
#      That's this spec's main, net-new job below.
#   2. Precedence/dedup/ordering/sigil/:tools-append mechanics are already
#      proven, exhaustively and per-scenario, by composinator_spec.rb,
#      mixinator_spec.rb, and recursive_merger_spec.rb against a mocked
#      object graph. Porting all of mixin_ordering_spec.rb's examples here
#      would just re-run logic already covered -- one representative example
#      per mechanic is kept instead, proving the *real* object graph produces
#      the same result end-to-end; the exhaustive edge cases stay where they
#      already are, in those three unit specs.
#
# What's left at system tier (spec/system/mixin_ordering_spec.rb, 7 examples):
# proof that `--mixin`, `CEEDLING_MIXIN_*`, and a project's own :mixins
# config section actually get read from the real command line/environment/
# file when wired through the real `ceedling` CLI entry point -- exactly the
# CLI-surface question this integration spec's real-object-graph approach
# can't answer on its own.
#
# config[:history][:config] (populated by Mixinator#mixin) is used throughout
# below in place of the system spec's log-text scanning/positions -- it's a
# structured, directly-inspectable record of exactly what got merged, in what
# order, by what mechanism, which is a strictly more precise signal than
# grepping console output for a log line.

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/constants'
require 'ceedling/file_wrapper'
require 'ceedling/yaml_wrapper'
require 'ceedling/ruby_expandinator'
require 'ceedling/reportinator'
require 'ceedling/config/config_walkinator'
require 'path_validator'
require 'projectinator'
require 'mixin_resolvinator'
require 'recursive_merger'
require 'mixin_standardizer'
require 'merginator'
require 'mixinator'
require 'composinator'
require 'mixins' # BUILTIN_MIXIN_LOAD_PATHS -- resolves to this repo's own vendor/unity/test/targets/

class NullObject
  def method_missing(*_args, **_kwargs); self; end
  def respond_to_missing?(*); true; end
end
NULL = NullObject.new

# Trivial mixin YAML content -- adds a harmless empty :paths ↳ :include entry
# so a merge has no side effects beyond what each test itself is checking.
TRIVIAL_MIXIN = ":paths:\n  :include: []\n"

# Scalar-valued mixins for precedence/ordering testing. Each sets
# :project ↳ :build_root to a distinct value so a test can verify which one
# wins after merging.
SCALAR_MIXIN_LOW  = ":project:\n  :build_root: build_low\n"
SCALAR_MIXIN_HIGH = ":project:\n  :build_root: build_high\n"

describe 'Mixin loading and merging (integration)' do

  # Builds a real Composinator wired to a real object graph -- every
  # collaborator Composinator#loadinate actually calls, none stubbed except
  # Loginator/Verbosinator (a real Loginator drags in a background worker
  # thread this spec has no need of, matching the same convention other
  # integration/system-support helpers in this repo already use).
  def build_composinator
    file_wrapper = FileWrapper.new(loginator: NULL, verbosinator: NULL)
    path_validator = PathValidator.new(file_wrapper: file_wrapper, loginator: NULL)
    yaml_wrapper = YamlWrapper.new(file_wrapper: file_wrapper)

    projectinator = Projectinator.new(
      file_wrapper: file_wrapper, path_validator: path_validator,
      yaml_wrapper: yaml_wrapper, loginator: NULL
    )
    mixin_resolvinator = MixinResolvinator.new(
      file_wrapper: file_wrapper, path_validator: path_validator,
      loginator: NULL, ruby_expandinator: RubyExpandinator.new
    )
    mixin_standardizer = MixinStandardizer.new(reportinator: Reportinator.new)
    merginator = Merginator.new(reportinator: Reportinator.new)
    mixinator = Mixinator.new(
      mixin_standardizer: mixin_standardizer, merginator: merginator,
      path_validator: path_validator, yaml_wrapper: yaml_wrapper, loginator: NULL
    )
    mixinator.setup

    Composinator.new(
      config_walkinator: ConfigWalkinator.new, projectinator: projectinator,
      mixin_resolvinator: mixin_resolvinator, mixinator: mixinator
    )
  end

  # Writes `files` (relative path => contents) into a fresh temp directory
  # and yields that directory's absolute path, cleaned up on block exit.
  # `project.yml` is the default project file every test resolves against
  # unless it explicitly names a different `filepath:`.
  def with_project_tree(files = {})
    Dir.mktmpdir('ceedling-mixin-loading-') do |dir|
      { 'project.yml' => ":project:\n  :build_root: build\n" }.merge(files).each do |rel, contents|
        path = File.join(dir, rel)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end
      yield dir
    end
  end

  # Resolves mixins the same way Composinator#loadinate does in production --
  # real project file, real load-path resolution (project directory + this
  # repo's real vendor/unity/test/targets/), real merge -- and returns just
  # the resulting config Hash.
  def resolve(dir:, mixins: [], env: {})
    _, config = build_composinator.loadinate(
      builtin_load_paths: BUILTIN_MIXIN_LOAD_PATHS,
      filepath: File.join(dir, 'project.yml'),
      mixins: mixins,
      env: env
    )
    config
  end

  # =========================================================================
  describe 'project directory as default load path' do
  # =========================================================================

    it 'loads a mixin by name from the project directory without configuring :load_paths' do
      with_project_tree('project_mixin.yml' => ":project:\n  :build_root: from_project_dir\n") do |dir|
        config = resolve(dir: dir, mixins: ['project_mixin'])
        expect(config.dig(:project, :build_root)).to eq('from_project_dir')
      end
    end

    it 'project directory mixin takes priority over unity/targets for the same name' do
      with_project_tree('no_stdlib.yml' => ":defines:\n  :test:\n    - PROJECT_DIR_WINS\n") do |dir|
        config = resolve(dir: dir, mixins: ['no_stdlib'])
        defines = Array(config.dig(:defines, :test))
        expect(defines).to include('PROJECT_DIR_WINS')
        expect(defines).not_to include('UNITY_EXCLUDE_STDINT_H')
      end
    end

    it 'user-configured :load_paths wins over both the project directory and unity/targets for the same name' do
      with_project_tree(
        'no_stdlib.yml' => ":defines:\n  :test:\n    - PROJECT_DIR_WINS\n",
        'user_mixins/no_stdlib.yml' => ":defines:\n  :test:\n    - USER_LOAD_PATH_WINS\n"
      ) do |dir|
        # Absolute path -- unlike the CLI (which chdirs into the deployed project
        # before resolving a relative :load_paths entry), nothing here changes
        # this process's own working directory.
        File.write(File.join(dir, 'project.yml'), ":project:\n  :build_root: build\n:mixins:\n  :load_paths:\n    - #{File.join(dir, 'user_mixins')}\n")
        config = resolve(dir: dir, mixins: ['no_stdlib'])
        defines = Array(config.dig(:defines, :test))
        expect(defines).to include('USER_LOAD_PATH_WINS')
        expect(defines).not_to include('PROJECT_DIR_WINS')
        expect(defines).not_to include('UNITY_EXCLUDE_STDINT_H')
      end
    end

  end

  # =========================================================================
  describe 'built-in load paths (unity/targets)' do
  # =========================================================================

    it 'loads no_stdlib by name via cmdline mixin from the built-in unity/targets load path' do
      with_project_tree do |dir|
        config = resolve(dir: dir, mixins: ['no_stdlib'])
        expect(Array(config.dig(:defines, :test))).to include('UNITY_EXCLUDE_STDINT_H')
      end
    end

    it 'loads no_stdlib by name via config :enabled from the built-in unity/targets load path' do
      with_project_tree('project.yml' => ":project:\n  :build_root: build\n:mixins:\n  :enabled:\n    - no_stdlib\n") do |dir|
        config = resolve(dir: dir)
        expect(Array(config.dig(:defines, :test))).to include('UNITY_EXCLUDE_STDINT_H')
      end
    end

    # Each named built-in toolchain target under vendor/unity/test/targets/, loaded
    # by name with no :load_paths configuration -- one distinctive setting per
    # target confirms the right file was actually found and merged.
    {
      'clang'         => [[:tools, :test_compiler, :executable], 'clang'],
      'gcc'           => [[:tools, :test_compiler, :executable], 'gcc'],
      'hitech_picc18' => [[:tools, :test_compiler, :executable], 'cd build && picc18'],
      'iar_arm'       => [[:iar_config], nil],
    }.each do |target_name, (key_path, expected)|
      it "loads the built-in '#{target_name}' toolchain target by name" do
        with_project_tree do |dir|
          config = resolve(dir: dir, mixins: [target_name])
          if expected.nil?
            expect(config.dig(*key_path)).to_not be_nil
          else
            expect(config.dig(*key_path)).to eq(expected)
          end
        end
      end
    end

  end

  # =========================================================================
  describe ':extension ↳ :yaml override' do
  # =========================================================================

    it 'finds a mixin by name using the configured :extension ↳ :yaml, not the default .yml' do
      with_project_tree(
        'custom_ext_mixin.yaml' => ":project:\n  :build_root: from_custom_extension\n",
        'project.yml' => ":project:\n  :build_root: build\n:extension:\n  :yaml: '.yaml'\n"
      ) do |dir|
        config = resolve(dir: dir, mixins: ['custom_ext_mixin'])
        expect(config.dig(:project, :build_root)).to eq('from_custom_extension')
      end
    end

  end

  # =========================================================================
  # Representative wiring smoke: one example per mechanic composinator_spec.rb/
  # mixinator_spec.rb/recursive_merger_spec.rb already prove exhaustively
  # against a mocked graph -- this proves the *real* graph agrees, not a
  # second exhaustive pass over the same scenarios.
  # =========================================================================
  describe 'end-to-end wiring, representative of unit-proven merge mechanics' do

    it 'deduplicates a mixin named in both :enabled and cmdline, keeping one merge-history entry' do
      with_project_tree(
        'shared.yml' => TRIVIAL_MIXIN,
        'project.yml' => ":project:\n  :build_root: build\n:mixins:\n  :enabled:\n    - shared\n"
      ) do |dir|
        config = resolve(dir: dir, mixins: [File.join(dir, 'shared.yml')])
        shared_entries = config[:history][:config].select { |e| e[:value].to_s.include?('shared') }
        expect(shared_entries.size).to eq(1)
      end
    end

    it 'merges in [config, env, cmdline] order, reflected directly in merge history' do
      with_project_tree(
        'ordering_config.yml' => TRIVIAL_MIXIN,
        'ordering_env.yml' => TRIVIAL_MIXIN,
        'ordering_cmdline.yml' => TRIVIAL_MIXIN,
        'project.yml' => ":project:\n  :build_root: build\n:mixins:\n  :enabled:\n    - ordering_config\n"
      ) do |dir|
        config = resolve(
          dir: dir,
          mixins: [File.join(dir, 'ordering_cmdline.yml')],
          env: { 'CEEDLING_MIXIN_1' => File.join(dir, 'ordering_env.yml') }
        )
        # :project is Projectinator's own record of the base project file load,
        # which always precedes any mixin merge -- config/env/cmdline is the
        # order under test here.
        expect(config[:history][:config].map { |e| e[:mechanism] }).to eq([:project, :config, :env, :cmdline])
      end
    end

    it 'a repeated cmdline --mixin value resolves at its last-typed position, not its first' do
      with_project_tree('mixin_foo.yml' => SCALAR_MIXIN_LOW, 'mixin_bar.yml' => SCALAR_MIXIN_HIGH) do |dir|
        foo = File.join(dir, 'mixin_foo.yml')
        bar = File.join(dir, 'mixin_bar.yml')
        config = resolve(dir: dir, mixins: [foo, bar, foo])
        # foo (build_low) was the user's actual last-typed flag -- it must win,
        # even though bar (build_high) is the second, distinct flag.
        expect(config.dig(:project, :build_root)).to eq('build_low')
      end
    end

    it 'cmdline mixin overrides config-enabled mixin on a scalar conflict' do
      with_project_tree(
        'mixin_cfg.yml' => SCALAR_MIXIN_LOW,
        'mixin_cli.yml' => SCALAR_MIXIN_HIGH,
        'project.yml' => ":project:\n  :build_root: build\n:mixins:\n  :enabled:\n    - mixin_cfg\n"
      ) do |dir|
        config = resolve(dir: dir, mixins: [File.join(dir, 'mixin_cli.yml')])
        expect(config.dig(:project, :build_root)).to eq('build_high')
      end
    end

    it 'three-way positional order (file, inline, file) resolves left-to-right -- rightmost wins' do
      with_project_tree('mixin_low.yml' => SCALAR_MIXIN_LOW, 'mixin_high.yml' => SCALAR_MIXIN_HIGH) do |dir|
        config = resolve(
          dir: dir,
          mixins: [
            File.join(dir, 'mixin_low.yml'),
            '=project: {build_root: build_mid}',
            File.join(dir, 'mixin_high.yml')
          ]
        )
        expect(config.dig(:project, :build_root)).to eq('build_high')
      end
    end

    it 'the @ sigil loads a file the same way an unprefixed cmdline value would' do
      with_project_tree('at_sigil.yml' => SCALAR_MIXIN_HIGH) do |dir|
        config = resolve(dir: dir, mixins: ["@#{File.join(dir, 'at_sigil.yml')}"])
        expect(config.dig(:project, :build_root)).to eq('build_high')
      end
    end

    it 'appends mixin :tools ↳ :arguments after existing config arguments instead of prepending' do
      mixin_content = ":tools:\n  :test_compiler:\n    :arguments:\n      - -DMIXIN_ARG\n"
      with_project_tree(
        'tool_args.yml' => mixin_content,
        'project.yml' => ":project:\n  :build_root: build\n:tools:\n  :test_compiler:\n    :arguments:\n      - -DBASE_ARG\n"
      ) do |dir|
        config = resolve(dir: dir, mixins: [File.join(dir, 'tool_args.yml')])
        arguments = config.dig(:tools, :test_compiler, :arguments)
        # -DMIXIN_ARG must come after -DBASE_ARG so it takes effect left-to-right.
        expect(arguments.index('-DBASE_ARG')).to be < arguments.index('-DMIXIN_ARG')
      end
    end

  end

end
