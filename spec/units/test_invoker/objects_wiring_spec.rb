# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'yaml'

# DIY builds Ceedling's objects from lib/ceedling/objects.yml, and an object fails to
# construct when its entry composes other than what its constructor takes. Unit specs
# build their subjects by hand, so only a real build would otherwise notice a missed
# entry. This checks the test pipeline's classes.
describe 'Test pipeline object wiring' do
  OBJECTS_WIRING = YAML.load_file( File.expand_path( '../../../lib/ceedling/objects.yml', __dir__ ) ).freeze

  %w[
    test_invoker test_pipeline_manager test_build_setup test_includes_extractinator test_bare_includes_extractinator
    test_includes_preprocessinator test_includes_reconcilinator test_build_planner partials_manager
    test_build_executor test_file_preprocessinator test_runner_generatinator test_search_paths mock_locator
    standin_headerinator
  ].each do |name|
    it "composes exactly what #{name}'s constructor takes" do
      require "ceedling/test_invoker/#{name}"
      klass = Object.const_get( name.split( '_' ).map( &:capitalize ).join )

      expect(OBJECTS_WIRING.dig( name, 'compose' )).to match_array( klass.constructor_keys.map( &:to_s ) )
    end
  end
end
