# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

namespace :generate do

  desc "Just generate mocks without further building or running."
  task :mocks => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:mocking])
  end

  desc "Just generate test runners without further building or running."
  task :test_runners => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:test_runners])
  end

end
