# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/rakefile_component_resolver'

describe RakefileComponentResolver do
  describe '.prepare_plugin_load_paths' do
    it "appends ceedling_plugins_path after any configured :plugins ↳ :load_paths" do
      config = { plugins: { load_paths: ['user/plugins'] } }

      result = described_class.prepare_plugin_load_paths(config, 'ceedling/plugins')

      expect(result).to eq(['user/plugins', 'ceedling/plugins'])
    end

    it 'returns just ceedling_plugins_path when :load_paths is entirely absent from config' do
      config = {}

      result = described_class.prepare_plugin_load_paths(config, 'ceedling/plugins')

      expect(result).to eq(['ceedling/plugins'])
    end

    it 'dedupes a load path that is already present' do
      config = { plugins: { load_paths: ['ceedling/plugins'] } }

      result = described_class.prepare_plugin_load_paths(config, 'ceedling/plugins')

      expect(result).to eq(['ceedling/plugins'])
    end
  end

  describe '.gather_rakefiles' do
    it 'sorts whatever Dir.glob returns for deterministic, platform-independent ordering' do
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'tests', '*.rake'))
        .and_return(['lib/rakefiles/tests/z.rake', 'lib/rakefiles/tests/a.rake'])

      result = described_class.gather_rakefiles('lib', 'tests')

      expect(result).to eq(['lib/rakefiles/tests/a.rake', 'lib/rakefiles/tests/z.rake'])
    end
  end

  describe '.base_rakefiles' do
    it "globs the 'base' subdirectory" do
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'base', '*.rake'))
        .and_return(['lib/rakefiles/base/tasks_filesystem.rake'])

      expect(described_class.base_rakefiles('lib')).to eq(['lib/rakefiles/base/tasks_filesystem.rake'])
    end
  end

  describe '.test_rakefiles' do
    it "globs the 'tests' subdirectory" do
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'tests', '*.rake'))
        .and_return(['lib/rakefiles/tests/rules_tests.rake'])

      expect(described_class.test_rakefiles('lib')).to eq(['lib/rakefiles/tests/rules_tests.rake'])
    end
  end

  describe '.release_rakefiles' do
    it "globs the 'release' subdirectory" do
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'release', '*.rake'))
        .and_return(['lib/rakefiles/release/rules_release.rake'])

      expect(described_class.release_rakefiles('lib')).to eq(['lib/rakefiles/release/rules_release.rake'])
    end
  end

  describe '.resolve' do
    before(:each) do
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'base', '*.rake'))
        .and_return(['lib/rakefiles/base/base.rake'])
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'tests', '*.rake'))
        .and_return(['lib/rakefiles/tests/tests.rake'])
      allow(Dir).to receive(:glob)
        .with(File.join('lib', 'rakefiles', 'release', '*.rake'))
        .and_return(['lib/rakefiles/release/release.rake'])
      allow(File).to receive(:exist?).and_return(false)
    end

    it 'excludes release rakefiles when :project ↳ :release_build is falsy' do
      config = { project: { release_build: false }, plugins: {} }

      result = described_class.resolve(config, 'lib', 'ceedling/plugins')

      expect(result).to eq(['lib/rakefiles/base/base.rake', 'lib/rakefiles/tests/tests.rake'])
    end

    it 'includes release rakefiles, in base → test → release → plugin order, when :release_build is truthy' do
      config = { project: { release_build: true }, plugins: {} }

      result = described_class.resolve(config, 'lib', 'ceedling/plugins')

      expect(result).to eq([
        'lib/rakefiles/base/base.rake',
        'lib/rakefiles/tests/tests.rake',
        'lib/rakefiles/release/release.rake',
      ])
    end

    it 'appends plugin rake files after every stock file' do
      config = { project: { release_build: false }, plugins: { enabled: ['gcov'], load_paths: ['ceedling/plugins'] } }
      allow(File).to receive(:exist?)
        .with(File.join('ceedling/plugins', 'gcov', 'gcov.rake'))
        .and_return(true)

      result = described_class.resolve(config, 'lib', 'ceedling/plugins')

      expect(result).to eq([
        'lib/rakefiles/base/base.rake',
        'lib/rakefiles/tests/tests.rake',
        File.join('ceedling/plugins', 'gcov', 'gcov.rake'),
      ])
    end
  end

  describe '.plugin_rake_files' do
    it 'includes a plugin whose .rake file exists at the first load path checked' do
      config = { plugins: { enabled: ['gcov'] } }
      allow(File).to receive(:exist?)
        .with(File.join('first/path', 'gcov', 'gcov.rake'))
        .and_return(true)

      result = described_class.plugin_rake_files(config, ['first/path', 'second/path'])

      expect(result).to eq([File.join('first/path', 'gcov', 'gcov.rake')])
    end

    it 'does not check a second load path once a match is found at the first' do
      config = { plugins: { enabled: ['gcov'] } }
      allow(File).to receive(:exist?)
        .with(File.join('first/path', 'gcov', 'gcov.rake'))
        .and_return(true)
      expect(File).to_not receive(:exist?).with(File.join('second/path', 'gcov', 'gcov.rake'))

      described_class.plugin_rake_files(config, ['first/path', 'second/path'])
    end

    it 'excludes a plugin whose .rake file is found at no load path' do
      config = { plugins: { enabled: ['gcov'] } }
      allow(File).to receive(:exist?).and_return(false)

      expect(described_class.plugin_rake_files(config, ['first/path'])).to eq([])
    end

    it 'includes one file per enabled plugin, in plugin order' do
      config = { plugins: { enabled: ['gcov', 'bullseye'] } }
      allow(File).to receive(:exist?)
        .with(File.join('path', 'gcov', 'gcov.rake'))
        .and_return(true)
      allow(File).to receive(:exist?)
        .with(File.join('path', 'bullseye', 'bullseye.rake'))
        .and_return(true)

      result = described_class.plugin_rake_files(config, ['path'])

      expect(result).to eq([
        File.join('path', 'gcov', 'gcov.rake'),
        File.join('path', 'bullseye', 'bullseye.rake'),
      ])
    end

    it 'returns an empty array when :plugins ↳ :enabled is absent from config' do
      config = {}

      expect(described_class.plugin_rake_files(config, ['path'])).to eq([])
    end
  end
end
