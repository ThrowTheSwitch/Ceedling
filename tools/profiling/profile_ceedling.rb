# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Dev-only stackprof harness invoked by the `profile:*` Rake tasks (see root
# Rakefile). Runs a real `bin/ceedling` invocation in-process, inside
# StackProf.run, so the profiler can see it -- shelling out to `ceedling` as
# a separate process would leave stackprof watching an empty wrapper.
#
# Relies on Batchinator skipping thread-spawning at worker count 1
# (lib/ceedling/batchinator.rb) so the real work happens on the same thread
# StackProf is sampling. Without that, `parallel`'s in_threads: mode would
# spawn a worker thread even for a pool of size 1, and StackProf's :wall mode
# -- which only samples the calling thread -- would see nothing but that
# thread blocked in Thread#value.
#
# Usage: bundle exec ruby tools/profiling/profile_ceedling.rb <dump_path> <ceedling_bin> -- <ceedling args...>

require 'stackprof'

dump_path    = ARGV.shift
ceedling_bin = ARGV.shift
separator    = ARGV.shift
if dump_path.nil? || ceedling_bin.nil? || separator != '--'
  raise "Usage: profile_ceedling.rb <dump_path> <ceedling_bin> -- <ceedling args...>"
end

# Remaining ARGV entries are the ceedling CLI args, left as-is for
# bin/ceedling to consume directly.
StackProf.run( mode: :wall, out: dump_path, raw: true ) do
  load ceedling_bin
end

$stderr.puts( "StackProf dump written: #{dump_path}" )
