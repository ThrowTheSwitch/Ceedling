# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The task registry decides from the requested task names whether a command builds tests or a
# release, and so whether build/vendor/ is populated (GH #1361). It reads that from the real
# .rake files. The first pass runs before plugin constants are loaded, so a plugin namespace
# such as `namespace GCOV_SYM do` is resolved by its NAME_SYM naming convention. The second
# pass resolves the constants themselves. Both must agree.

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/rake_app/rake_task_registry'

describe 'RakeTaskRegistry against the real rakefiles (integration)' do
  REGISTRY_SPEC_ROOT = File.expand_path( '../..', __dir__ )

  REGISTRY_SPEC_RAKEFILES = Dir.glob( File.join( REGISTRY_SPEC_ROOT, 'lib/ceedling/rakefiles/**/*.rake' ) ) +
              %w[gcov valgrind sanitize bullseye].map { |plugin| File.join( REGISTRY_SPEC_ROOT, "plugins/#{plugin}/#{plugin}.rake" ) }

  REGISTRY_SPEC_PLUGIN_CONSTANTS = {
    'GCOV_SYM'     => :gcov,
    'VALGRIND_SYM' => :valgrind,
    'SANITIZE_SYM' => :sanitize,
    'BULLSEYE_SYM' => :bullseye
  }.freeze

  REGISTRY_SPEC_TEST_BUILDS = %w[
    test test:all test:test_foo.c test:unit/test_foo.c
    gen:mocks:test_foo.c
    gcov:all gcov:test_foo.c gcov:test/test_foo.c
    valgrind:all valgrind:test/test_foo.c
    sanitize:all sanitize:test/test_foo.c
    bullseye:all bullseye:test/test_foo.c
  ].freeze

  REGISTRY_SPEC_NOT_BUILDS = %w[files:test dumpconfig clobber clean utils:gcov report:gcov module:create].freeze

  def registry
    registry = RakeTaskRegistry.new
    registry.register_test_tasks( REGISTRY_SPEC_RAKEFILES )
    registry.register_release_tasks( REGISTRY_SPEC_RAKEFILES )
    return registry
  end

  def expect_classified(registry)
    REGISTRY_SPEC_TEST_BUILDS.each do |task|
      expect( registry.task_is?( task, RakeTaskRegistry::TAG_TEST ) ).to be(true), "#{task} should be a test build"
      expect( registry.task_is?( task, RakeTaskRegistry::TAG_BUILD ) ).to be(true), "#{task} should be a build"
    end

    expect( registry.task_is?( 'release', RakeTaskRegistry::TAG_RELEASE ) ).to be(true)
    expect( registry.task_is?( 'release', RakeTaskRegistry::TAG_TEST ) ).to be(false)

    REGISTRY_SPEC_NOT_BUILDS.each do |task|
      expect( registry.task_is?( task, RakeTaskRegistry::TAG_BUILD ) ).to be(false), "#{task} should not be a build"
    end
  end

  it 'finds every test-building plugin namespace before plugin constants are loaded' do
    REGISTRY_SPEC_PLUGIN_CONSTANTS.each_key { |name| hide_const( name ) }
    expect_classified( registry )
  end

  it 'finds every test-building plugin namespace once plugin constants are loaded' do
    REGISTRY_SPEC_PLUGIN_CONSTANTS.each { |name, value| stub_const( name, value ) }
    expect_classified( registry )
  end
end
