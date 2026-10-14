# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

namespace :module do

  # One request per module a task's arguments name, each carrying only its own hint
  module_requests = lambda do |args, patterns: true|
    ModuleGeneratorRequest.parse(
      [args[:module_path]] + args.extras,
      test_prefix: @ceedling[:module_generator].test_prefix,
      patterns:    patterns
    )
  end

  desc "Generate module (source, header and test files)"
  task :create, :module_path do |_t, args|
    module_requests.call( args ).each do |request|
      @ceedling[:module_generator].create( request )
    end
  end

  desc "Generate module stubs from header"
  task :stub, :module_path do |_t, args|
    module_requests.call( args, patterns: false ).each do |request|
      @ceedling[:module_generator].stub( request )
    end
  end

  desc "Generate module tests from header"
  task :test, :module_path do |_t, args|
    module_requests.call( args, patterns: false ).each do |request|
      @ceedling[:module_generator].test( request )
    end
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |_t, args|
    module_requests.call( args ).each do |request|
      @ceedling[:module_generator].destroy( request )
    end
  end

end
