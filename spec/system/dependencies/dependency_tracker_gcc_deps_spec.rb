# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'dependency_tracker_system_helper'

# System-level coverage of DependencyTracker's gcc -M/-MM/-MMD ingestion
# (register_gcc_deps_string / register_gcc_deps_file) against real files on
# disk. No real gcc invocation happens anywhere in this suite -- gcc's
# Makefile-dialect output is simulated with constructed heredoc content,
# exactly as gcc's `-MF` flag would have written it, and real dependency
# files matching that content are written to a real temp directory so
# staleness genuinely round-trips through real file content changes.
describe 'DependencyTracker gcc -M/-MM/-MMD ingestion (system)' do
  include DependencyTrackerSystemHelper

  # A single target, several dependencies, exactly gcc's plain `-MMD` shape.
  it 'registers a single target with several dependencies from constructed gcc -MMD content' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_c = write_fixture( File.join(dir, 'foo.c'), "int main(void) { return 0; }\n" )
      foo_h = write_fixture( File.join(dir, 'foo.h'), "#define FOO 1\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      simulated_gcc_output = <<~DEPFILE
        #{target}: #{foo_c} #{foo_h}
      DEPFILE

      tracker.register_gcc_deps_string( simulated_gcc_output )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( foo_h, "#define FOO 2\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # Real gcc -MMD -MP output spans multiple lines via backslash-newline
  # continuations. Constructed here exactly as gcc would emit it, including
  # the continuation backslashes.
  it 'joins backslash-newline continuations across multiple lines of constructed content' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_c = write_fixture( File.join(dir, 'foo.c'), "// source\n" )
      foo_h = write_fixture( File.join(dir, 'foo.h'), "// header\n" )
      unity_h = write_fixture( File.join(dir, 'unity.h'), "// vendored\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      simulated_gcc_output = <<~DEPFILE
        #{target}: \\
         #{foo_c} \\
         #{foo_h} \\
         #{unity_h}
      DEPFILE

      tracker.register_gcc_deps_string( simulated_gcc_output )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( unity_h, "// vendored, but changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # -MP emits an extra phony, no-prerequisite rule per header (`some.h:`)
  # alongside the real object-file rule, in the same blob. Both targets in
  # the blob should be registered; the phony header target legitimately has
  # zero dependencies of its own.
  it 'registers multiple targets from one blob, including an -MP-style phony header target' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_h = write_fixture( File.join(dir, 'foo.h'), "// header\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      simulated_gcc_output = <<~DEPFILE
        #{target}: #{foo_h}

        #{foo_h}:
      DEPFILE

      tracker.register_gcc_deps_string( simulated_gcc_output )
      tracker.mark_fresh( target )
      tracker.mark_fresh( foo_h ) # the phony target is a legitimate target too, with no deps

      expect( tracker.stale?( target ) ).to be(false)
      expect( tracker.stale?( foo_h ) ).to be(false)
    end
  end

  # gcc escapes a literal space in a path with a backslash in its dependency
  # output. The real file on disk genuinely has a space in its name.
  it 'resolves a dependency path containing an escaped space to the real on-disk file' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      spaced_header = write_fixture( File.join(dir, 'path with space.h'), "// header\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      escaped_path = spaced_header.gsub(' ', '\\ ')
      simulated_gcc_output = "#{target}: #{escaped_path}\n"

      tracker.register_gcc_deps_string( simulated_gcc_output )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( spaced_header, "// header, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # register_gcc_deps_file reads real `.d` file content from a real path via
  # FileWrapper (rather than being handed a string directly), matching how a
  # build step would actually consume gcc's own `-MF` output file.
  it 'reads a real .d file from disk via register_gcc_deps_file and registers its targets' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_c = write_fixture( File.join(dir, 'foo.c'), "// source\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      dep_file = write_fixture( File.join(dir, 'build', 'foo.d'), <<~DEPFILE )
        #{target}: #{foo_c}
      DEPFILE

      tracker.register_gcc_deps_file( dep_file )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      write_fixture( foo_c, "// source, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # gcc-deps ingestion is additive alongside (not a replacement for) an
  # explicit register() call for the same target -- e.g. a build step that
  # registers its own primary source file explicitly, then layers in
  # gcc-discovered header dependencies from the .d file.
  it 'is additive alongside an explicit register() call for the same target' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_c = write_fixture( File.join(dir, 'foo.c'), "// primary source\n" )
      foo_h = write_fixture( File.join(dir, 'foo.h'), "// discovered header\n" )
      target = write_fixture( File.join(dir, 'foo.o'), 'object bytes' )

      tracker.register( target, files: [foo_c] )
      tracker.register_gcc_deps_string( "#{target}: #{foo_h}\n" )
      tracker.mark_fresh( target )
      expect( tracker.stale?( target ) ).to be(false)

      # Both the explicitly-registered source and the gcc-discovered header
      # must independently trigger staleness -- proving both survived.
      write_fixture( foo_c, "// primary source, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)

      tracker.mark_fresh( target )
      write_fixture( foo_h, "// discovered header, changed\n" )
      expect( tracker.stale?( target ) ).to be(true)
    end
  end

  # meta passed to register_gcc_deps_string applies identically to every
  # target discovered in that one blob -- proven by invalidating just one of
  # two targets and confirming only that one goes stale on a meta change.
  it 'applies the same meta to every target discovered in one constructed gcc-deps blob' do
    in_temp_dir do |dir|
      tracker = build_dependency_tracker( store_path: File.join(dir, '.dep_cache.json') )

      foo_o = write_fixture( File.join(dir, 'foo.o'), 'foo object bytes' )
      bar_o = write_fixture( File.join(dir, 'bar.o'), 'bar object bytes' )

      simulated_gcc_output = <<~DEPFILE
        #{foo_o}:

        #{bar_o}:
      DEPFILE

      tracker.register_gcc_deps_string( simulated_gcc_output, meta: { opt_level: 2 } )
      tracker.mark_fresh( foo_o )
      tracker.mark_fresh( bar_o )

      expect( tracker.stale?( foo_o ) ).to be(false)
      expect( tracker.stale?( bar_o ) ).to be(false)

      # Re-registering only foo.o's meta differently makes just foo.o stale.
      tracker.register( foo_o, meta: { opt_level: 0 } )
      expect( tracker.stale?( foo_o ) ).to be(true)
      expect( tracker.stale?( bar_o ) ).to be(false)
    end
  end

end
