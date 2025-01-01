# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

iterations = (ARGV[0] || 25).to_i
puts "Stress Testing Each Scenario #{iterations} times..."

require 'open3'

defaults = { :dir => File.expand_path(File.dirname(__FILE__)) + '/../../examples/temp_sensor' }

tasks = { 
  'ceedling clobber test:all' => defaults,
  'ceedling -v=4 clobber test:all' => defaults,
  'ceedling test:all' => defaults,
  'ceedling --verbosity=obnoxious --mixin=add_unity_helper --mixin=add_gcov clobber test:all' => defaults,
}

tasks.each_pair do |k,v|
  Dir.chdir(v[:dir]) do
    iterations.times do |i|
      puts "=============== RUNNING ITERATION #{i+1}:\n#{k.to_s}\n===============\n\n"
      stdout, stderr, status = Open3.capture3(k)
      puts stdout,stderr,status
      raise "\n\nCrashed on #{k} Iteration #{i+1}" unless status.success?
    end
  end
end