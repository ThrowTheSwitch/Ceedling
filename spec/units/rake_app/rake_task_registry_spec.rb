# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/rake_task_registry'

describe RakeTaskRegistry do
  let(:registry) { described_class.new }

  describe '#tags_for' do
    it 'returns an empty array for a namespace that was never registered' do
      expect(registry.tags_for('test:all')).to eq([])
    end

    it 'resolves an explicitly namespaced task name to its root namespace' do
      registry.register_namespace('test', :test, :build)

      expect(registry.tags_for('test:all')).to eq([:test, :build])
    end

    it 'resolves a rule-synthesized task name (root:generated_name) the same as an explicit one' do
      registry.register_namespace('test', :test, :build)

      expect(registry.tags_for('test:foo_file')).to eq([:test, :build])
    end

    it 'resolves a bare, unnamespaced task name as its own root' do
      registry.register_namespace('test', :test, :build)

      expect(registry.tags_for('test')).to eq([:test, :build])
    end
  end

  describe '#task_is?' do
    it 'is true when the resolved namespace carries the given tag' do
      registry.register_namespace('test', :test)

      expect(registry.task_is?('test:all', :test)).to eq(true)
    end

    it 'is false when the resolved namespace does not carry the given tag' do
      registry.register_namespace('test', :test)

      expect(registry.task_is?('test:all', :release)).to eq(false)
    end

    it 'is false for an unregistered namespace' do
      expect(registry.task_is?('unregistered:all', :test)).to eq(false)
    end
  end

  describe '#namespaces_for_tag' do
    it 'returns only the namespaces carrying the given tag' do
      registry.register_namespace('test', :test, :build)
      registry.register_namespace('release', :release, :build)

      expect(registry.namespaces_for_tag(:test)).to eq(['test'])
      expect(registry.namespaces_for_tag(:release)).to eq(['release'])
      expect(registry.namespaces_for_tag(:build)).to match_array(['test', 'release'])
    end

    it 'returns an empty array when no namespace carries the given tag' do
      expect(registry.namespaces_for_tag(:test)).to eq([])
    end
  end

  describe '#register_namespace' do
    it 'creates a new entry on first registration' do
      registry.register_namespace('gcov', :test)

      expect(registry.tags_for('gcov')).to eq([:test])
    end

    it 'merges a new tag into an existing entry rather than overwriting it' do
      registry.register_namespace('gcov', :test)
      registry.register_namespace('gcov', :build)

      expect(registry.tags_for('gcov')).to eq([:test, :build])
    end

    it 'does not duplicate a tag that is already present' do
      registry.register_namespace('gcov', :test)
      registry.register_namespace('gcov', :test)

      expect(registry.tags_for('gcov')).to eq([:test])
    end

    it 'accepts multiple tags in a single call via the splat argument' do
      registry.register_namespace('release', :release, :build)

      expect(registry.tags_for('release')).to eq([:release, :build])
    end
  end

  describe '#register_tasks' do
    def rakefile_content(namespace_line, marker_line)
      "#{namespace_line}\n  #{marker_line}\nend\n"
    end

    it 'registers nothing for a file whose content matches no marker' do
      allow(File).to receive(:read).and_return("namespace :test do\n  # nothing interesting here\nend\n")

      registry.register_tasks(['fake.rake'], markers: [/marker/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq([])
    end

    it 'registers the enclosing namespace of a matched marker line with the given tags' do
      content = rakefile_content('namespace :test do', '@ceedling[:test_invoker].setup_and_invoke(')
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/\[\s*:test_invoker\s*\]\.setup_and_invoke/], tags: [:test, :build])

      expect(registry.tags_for('test')).to eq([:test, :build])
    end

    it "resolves a ':symbol' namespace declaration by stripping the leading colon" do
      content = rakefile_content('namespace :gcov do', 'MARKER HERE')
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['gcov'])
    end

    it 'resolves a quoted-string namespace declaration by stripping the surrounding quotes' do
      content = rakefile_content('namespace "gcov" do', 'MARKER HERE')
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['gcov'])
    end

    it 'resolves a CONSTANT namespace declaration via Object.const_get' do
      RAKE_TASK_REGISTRY_SPEC_TEST_CONSTANT = 'gcov' unless Object.const_defined?(:RAKE_TASK_REGISTRY_SPEC_TEST_CONSTANT)
      content = rakefile_content('namespace RAKE_TASK_REGISTRY_SPEC_TEST_CONSTANT do', 'MARKER HERE')
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['gcov'])
    end

    it "falls back to the '_SYM'-stripped, downcased constant name when Object.const_get raises NameError" do
      content = rakefile_content('namespace GCOV_SYM do', 'MARKER HERE')
      allow(File).to receive(:read).and_return(content)
      # GCOV_SYM is deliberately left undefined -- this is the Pass 1 scenario the
      # class comment describes, before plugin constants are loaded.

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['gcov'])
    end

    it 'falls back to a plain downcase when a constant without the _SYM suffix raises NameError' do
      content = rakefile_content('namespace UNDEFINED_CONSTANT do', 'MARKER HERE')
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['undefined_constant'])
    end

    it 'registers a namespace once even when multiple lines inside it match a marker' do
      content = "namespace :test do\n  MARKER ONE\n  MARKER TWO\nend\n"
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq(['test'])
    end

    it 'registers each distinct namespace found in the same file' do
      content = "namespace :test do\n  MARKER\nend\nnamespace :gcov do\n  MARKER\nend\n"
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to match_array(['test', 'gcov'])
    end

    it 'skips a file that raises on read, without registering anything or propagating the error' do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)

      expect { registry.register_tasks(['missing.rake'], markers: [/MARKER/], tags: [:test]) }.to_not raise_error
      expect(registry.namespaces_for_tag(:test)).to eq([])
    end

    it 'skips a matched marker line with no enclosing namespace declaration anywhere above it' do
      content = "MARKER HERE\n"
      allow(File).to receive(:read).and_return(content)

      registry.register_tasks(['fake.rake'], markers: [/MARKER/], tags: [:test])

      expect(registry.namespaces_for_tag(:test)).to eq([])
    end
  end

  describe '#register_test_tasks' do
    it "clears only previously test-tagged namespaces, leaving release-only namespaces untouched" do
      registry.register_namespace('release', :release, :build)
      allow(File).to receive(:read).and_return("namespace :gcov do\n  @ceedling[:test_invoker].setup_and_invoke(\nend\n")

      registry.register_test_tasks(['fake.rake'])

      expect(registry.namespaces_for_tag(:test)).to eq(['gcov'])
      expect(registry.namespaces_for_tag(:release)).to eq(['release'])
    end

    it 'removes a namespace that was test-tagged on a prior call but no longer matches on this one' do
      allow(File).to receive(:read).and_return("namespace :test do\n  @ceedling[:test_invoker].setup_and_invoke(\nend\n")
      registry.register_test_tasks(['fake.rake'])
      expect(registry.namespaces_for_tag(:test)).to eq(['test'])

      allow(File).to receive(:read).and_return("namespace :test do\n  # no longer calls setup_and_invoke\nend\n")
      registry.register_test_tasks(['fake.rake'])

      expect(registry.namespaces_for_tag(:test)).to eq([])
    end

    it 'registers a matched namespace with both TAG_TEST and TAG_BUILD' do
      allow(File).to receive(:read).and_return("namespace :test do\n  @ceedling[:test_invoker].setup_and_invoke(\nend\n")

      registry.register_test_tasks(['fake.rake'])

      expect(registry.tags_for('test')).to eq([RakeTaskRegistry::TAG_TEST, RakeTaskRegistry::TAG_BUILD])
    end
  end

  describe '#register_release_tasks' do
    it 'does not pre-clear test-tagged namespaces (no equivalent delete_if for the release pipeline)' do
      registry.register_namespace('test', :test, :build)
      allow(File).to receive(:read).and_return("namespace :release do\n  # no marker in this content\nend\n")

      registry.register_release_tasks(['fake.rake'])

      expect(registry.namespaces_for_tag(:test)).to eq(['test'])
    end

    it 'clears only previously release-tagged namespaces, leaving test-only namespaces untouched' do
      registry.register_namespace('test', :test, :build)
      allow(File).to receive(:read).and_return("namespace :release do\n  @ceedling[:release_invoker].setup_and_invoke(\nend\n")

      registry.register_release_tasks(['fake.rake'])

      expect(registry.namespaces_for_tag(:release)).to eq(['release'])
      expect(registry.namespaces_for_tag(:test)).to eq(['test'])
    end

    it 'registers a matched namespace with both TAG_RELEASE and TAG_BUILD' do
      allow(File).to receive(:read).and_return("namespace :release do\n  @ceedling[:release_invoker].setup_and_invoke(\nend\n")

      registry.register_release_tasks(['fake.rake'])

      expect(registry.tags_for('release')).to eq([RakeTaskRegistry::TAG_RELEASE, RakeTaskRegistry::TAG_BUILD])
    end
  end
end
