# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/setupinator'

describe Setupinator do
  # FileWrapper is built before any configuration exists, so setup hands it the Windows
  # path limit, and the prober that decides it, once the configuration is built
  describe 'Windows path limit' do
    it 'gives FileWrapper the configured mode and the prober once the configuration is built' do
      configurator = double( 'configurator', project_win_path_limit: :auto, build: nil )
      file_wrapper = double( 'file_wrapper' )
      objects      = Setupinator::COLLABORATORS.to_h { |name| [name, double( name.to_s )] }
      objects      = objects.merge( configurator: configurator, file_wrapper: file_wrapper )

      setupinator = described_class.new
      setupinator.ceedling = objects

      expect(configurator).to receive(:build).ordered
      expect(file_wrapper).to receive(:configure_win_path_limit).with( mode: :auto, prober: objects[:win_path_prober] ).ordered

      setupinator.send( :build_configuration, { ceedling_lib_path: 'lib', logging_path: 'logs' } )
    end
  end
end
