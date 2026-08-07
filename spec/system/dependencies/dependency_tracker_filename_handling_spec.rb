# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'dependency_tracker_system_helper'

# System-level coverage of design point (D), platform-appropriate filename
# handling, against the *real, current* filesystem this suite happens to be
# running on -- not a simulated one. Path equality is platform-dependent
# (case-sensitive on Linux; case-insensitive-but-case-preserving by default
# on macOS and Windows), and this suite can only run on one real filesystem
# at a time, so scenarios that only make sense on one kind of filesystem
# empirically detect the host's actual behavior (`filesystem_case_insensitive?`,
# via a real probe file -- never assumed from RUBY_PLATFORM) and skip
# themselves cleanly when run on the other kind, rather than asserting
# something that isn't true of the machine actually running the suite.
# (spec/units/dependencies/dependency_path_normalizer_spec.rb covers both
# branches unconditionally, via a mocked, fully-controlled fake filesystem.)
describe 'DependencyTracker platform-appropriate filename handling (system)' do
  include DependencyTrackerSystemHelper

  # Always true, on any filesystem: registering and querying with the exact
  # same casing the file was created under works trivially.
  it 'tracks a target referenced with the exact casing it was created under, on any filesystem' do
    in_temp_dir do |dir|
      store_path = File.join(dir, '.dep_cache.json')
      foo_h = write_fixture( File.join(dir, 'Foo.h'), "// header\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( target, files: [foo_h] )
      tracker.mark_fresh( target )

      expect( tracker.stale?( target ) ).to be(false)
    end
  end

  # Case-insensitive-filesystem-only scenario: a dependency referenced with
  # a *different* casing than the real file was actually created under (a
  # plausible `#include "Foo.h"` vs. an on-disk `foo.h`, or inconsistent
  # casing assembled from YAML config) must still resolve to the same real
  # file's identity -- not a false "missing dependency," and not silently
  # treated as a distinct, never-tracked file.
  it 'resolves a differently-cased reference to the same real file (case-insensitive filesystem only)' do
    in_temp_dir do |dir|
      skip 'Host filesystem is case-sensitive -- this scenario does not apply' unless filesystem_case_insensitive?(dir)

      store_path = File.join(dir, '.dep_cache.json')
      real_header = write_fixture( File.join(dir, 'Foo.h'), "// header\n" ) # created as "Foo.h"
      differently_cased_reference = File.join(dir, 'foo.h')                # referenced as "foo.h"
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( target, files: [differently_cased_reference] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      # Changing the real file via its *actual* casing must still be caught,
      # proving the differently-cased reference genuinely resolved to it
      # rather than to some other, never-tracked identity.
      write_fixture( real_header, "// header, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # Case-insensitive-filesystem-only scenario, extended across a directory
  # component rather than just the final filename.
  it 'resolves real on-disk casing across multiple path components (case-insensitive filesystem only)' do
    in_temp_dir do |dir|
      skip 'Host filesystem is case-sensitive -- this scenario does not apply' unless filesystem_case_insensitive?(dir)

      store_path = File.join(dir, '.dep_cache.json')
      real_header = write_fixture( File.join(dir, 'Src', 'Foo.h'), "// header\n" ) # created as "Src/Foo.h"
      differently_cased_reference = File.join(dir, 'src', 'foo.h')                # referenced as "src/foo.h"
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( target, files: [differently_cased_reference] )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( real_header, "// header, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # Case-sensitive-filesystem-only scenario: two genuinely distinct files
  # coexisting, differing only in case, must be tracked as two independent
  # targets -- changing one must not be conflated with the other. (This
  # cannot even be *constructed* as real files on a case-insensitive
  # filesystem: creating the second file overwrites/aliases the first, so
  # the scenario is skipped there rather than silently testing nothing.)
  it 'tracks two genuinely distinct, differently-cased files as independent targets (case-sensitive filesystem only)' do
    in_temp_dir do |dir|
      skip 'Host filesystem is case-insensitive -- cannot create two coexisting case-variant files here' if filesystem_case_insensitive?(dir)

      store_path = File.join(dir, '.dep_cache.json')
      upper = write_fixture( File.join(dir, 'Foo.o'), 'UPPER object bytes' )
      lower = write_fixture( File.join(dir, 'foo.o'), 'lower object bytes' )

      tracker = build_dependency_tracker( store_path: store_path )
      tracker.register( upper, files: [] )
      tracker.register( lower, files: [] )
      tracker.mark_fresh( upper )
      tracker.mark_fresh( lower )

      write_fixture( upper, 'UPPER object bytes, changed' )

      expect( tracker.stale?( upper ) ).to be(true)
      expect( tracker.stale?( lower ) ).to be(false) # a genuinely different file, unaffected
    end
  end

end
