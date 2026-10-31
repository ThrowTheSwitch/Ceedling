# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/filesystem/file_system_wrapper'
require 'ceedling/filesystem/working_dir'

describe FileSystemWrapper do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'app/dep' ) )
      Dir.chdir( File.join( @ws, 'app' ) ) { WorkingDirTracking.untracked { example.run } }
    end
  end

  # A plugin can change directory through this object, and paths it resolves inside must
  # resolve against the directory it changed to
  it 'changes directory for the block as WorkingDir.chdir does' do
    WorkingDir.path

    inside = described_class.new.cd( 'dep' ) { WorkingDir.path }

    expect(inside).to eq( File.join( @ws, 'app/dep' ) )
    expect(WorkingDir.path).to eq( File.join( @ws, 'app' ) )
  end
end
