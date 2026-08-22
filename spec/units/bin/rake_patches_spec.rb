# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake_patches'

# Rake::ColonTaskNameFileTaskPatch only ever matters on Windows (see the comment
# block in rake_patches.rb for why), but Errno::EINVAL can be stubbed from any
# platform -- no real Windows machine is needed to exercise the rescue itself.
describe Rake::ColonTaskNameFileTaskPatch do
  around(:each) do |example|
    # Rake.application is process-global; save/restore it so this spec's throwaway
    # application doesn't leak into any other spec that happens to run in the
    # same process.
    original_application = Rake.application
    Rake.application = Rake::Application.new

    example.run

    Rake.application = original_application
  end

  def file_task(name)
    Rake::FileTask.define_task(name)
  end

  describe '#needed?' do
    it 'treats Errno::EINVAL the same as Rake would treat a missing file' do
      allow(File).to receive(:mtime).and_raise( Errno::EINVAL )

      expect(file_task('release:compile:foo.c').needed?).to eq( true )
    end

    it 'leaves ordinary Errno::ENOENT handling (already rescued by Rake) unaffected' do
      allow(File).to receive(:mtime).and_raise( Errno::ENOENT )

      expect(file_task('release:compile:foo.c').needed?).to eq( true )
    end
  end

  describe '#timestamp' do
    it 'treats Errno::EINVAL the same as Rake would treat a missing file' do
      allow(File).to receive(:mtime).and_raise( Errno::EINVAL )

      expect(file_task('release:compile:foo.c').timestamp).to eq( Rake::LATE )
    end
  end
end
