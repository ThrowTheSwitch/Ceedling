# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'lib/module_generator_request'

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
      @ceedling[:module_generator].create( request.name, { module_root_path: request.path_hint.to_s, pattern: request.pattern } )
    end
  end

  desc "Generate module stubs from header"
  task :stub, :module_path do |_t, args|
    module_requests.call( args, patterns: false ).each do |request|
      @ceedling[:module_generator].stub_from_header( request.name, { module_root_path: request.path_hint.to_s } )
    end
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |_t, args|
    module_requests.call( args ).each do |request|
      @ceedling[:module_generator].create( request.name, { destroy: true, module_root_path: request.path_hint.to_s, pattern: request.pattern } )
    end
  end

end
