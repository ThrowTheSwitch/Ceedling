# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module TestInvokerTypes

  # Partial build metadata for one test: config map plus accumulated output module names.
  TestablePartials = Struct.new(:configs, :tests, :mocks, keyword_init: true)

  # Carries all mutable state across the pipeline stages.
  PipelineState = Struct.new(
    :tests,             # Array of test filepaths (input to stage 1)
    :testables,         # Hash<Symbol, Testable> — accumulated across all stages
    :context,
    :options,
    :partials_headers,  # Produced by T1; consumed by stages 6 & 7
    :partials_sources,  # Produced by T1; consumed by stages 6 & 7
    :mocks_list,        # Produced by T2; consumed by stages 9 & 10
    :objects_list,      # Produced by T3; consumed by stage 15
    :lock,              # Mutex for thread-safe testable writes
    keyword_init: true
  )

  # Named record replacing the raw hash per test file. Fields are populated
  # across multiple stages; nil fields are valid until their stage sets them.
  Testable = Struct.new(
    :filepath, :name,
    :paths,                                    # Hash — build/results/mocks/partials/preprocess paths
    :preprocess,                               # Hash — preprocessing scratch state
    :search_paths,
    :compile_flags, :preprocess_flags, :assembler_flags, :link_flags,
    :compile_defines, :preprocess_defines,
    :runner,                                   # Hash — {output_filepath:, input_filepath:}
    :mocks,                                    # Hash — mock name → mock info
    :partials,                                 # TestablePartials — configs map + tests/mocks module name lists
    :sources, :frameworks, :core, :objects, :executable,
    :no_link_objects, :results_pass, :results_fail, :tool,
    keyword_init: true
  ) do
    def initialize(**kwargs)
      kwargs[:partials] ||= TestablePartials.new(configs: {}, tests: [], mocks: [])
      super(**kwargs)
    end
  end

  # Describes one pipeline step — either a named build_step or a silent transform.
  Stage = Struct.new(:name, :heading, :condition, :transform, :body, keyword_init: true) do
    def run?(state)
      condition.nil? || condition.call(state)
    end
  end

end
