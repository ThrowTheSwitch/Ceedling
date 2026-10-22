# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/rake_wrapper'

# RakeWrapper's whole job is to wrap real Rake::Task state, so unlike most
# specs in this codebase there's no dependency here to double -- these specs
# exercise real, throwaway Rake::Task objects. Rake.application is
# process-global, so each example swaps in a fresh Rake::Application and
# restores the original afterward (mirrors the established precedent for
# this exact situation, spec/units/bin/rake_patches_spec.rb), keeping
# spec-defined tasks from leaking into any other spec's task namespace.
describe RakeWrapper do
  around(:each) do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new

    example.run

    Rake.application = original_application
  end

  let(:rake_wrapper) { described_class.new }

  describe '#[]' do
    it 'returns the same Rake::Task object Rake::Task[] itself returns for a defined task' do
      task :example_task_for_bracket_lookup

      expect(rake_wrapper[:example_task_for_bracket_lookup]).to equal(Rake::Task[:example_task_for_bracket_lookup])
    end
  end

  describe '#task_list' do
    it 'returns Rake::Task.tasks, including a task defined in this example' do
      task :example_task_for_task_list

      expect(rake_wrapper.task_list).to eq(Rake::Task.tasks)
      expect(rake_wrapper.task_list.map(&:name)).to include('example_task_for_task_list')
    end
  end

  # The Rake::Task#already_invoked monkey-patch (defined alongside RakeWrapper) is what
  # RakeUtils#task_invoked? relies on -- exercised here directly against a real task
  # rather than only indirectly through a double in rake_utils_spec.rb.
  describe 'Rake::Task#already_invoked' do
    it 'is falsy before the task runs and truthy after' do
      invoked = false
      task(:example_task_for_already_invoked) { invoked = true }

      rake_task = Rake::Task[:example_task_for_already_invoked]
      expect(rake_task.already_invoked).to be_falsy

      rake_task.invoke

      expect(invoked).to eq(true)
      expect(rake_task.already_invoked).to be_truthy
    end
  end
end
