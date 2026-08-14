# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module TestInvokerTypes

  # Partial build metadata for one test: config map plus accumulated output module names.
  TestablePartials = Struct.new(:configs, :tests, :mocks, keyword_init: true) unless const_defined?(:TestablePartials, false)

  # Carries all mutable state across the pipeline stages.
  PipelineState = Struct.new(
    :tests,             # Array of test filepaths (input to stage 1)
    :testables,         # Hash<Symbol, Testable> — accumulated across all stages
    :context,
    :options,           # Array<Symbol> — pipeline-control flags (see TestPipelineManager)
    :partials_headers,  # Array<PartialWork> — produced by T1; consumed by stages 6 & 7
    :partials_sources,  # Array<PartialWork> — produced by T1; consumed by stages 6 & 7
    :mocks_list,        # Array<MockWork> — produced by T2; consumed by stages 9 & 10
    :objects_list,      # Produced by T3; consumed by stage 15
    :lock,              # Mutex for thread-safe testable writes
    keyword_init: true
  ) do
    def initialize(**kwargs)
      kwargs[:options] ||= []
      super(**kwargs)
    end
  end unless const_defined?(:PipelineState, false)

  # A resolved mock: its own header's real, resolved location (`source`, also
  # duplicated onto `filepath`), the mirrored subdirectory it lives in below
  # this test's mock root (`path`), and whichever of the two the compiler
  # should actually read (`input` -- the raw header or its preprocessed
  # output, depending on whether mock preprocessing is enabled).
  MockDetails = Struct.new(:name, :filepath, :path, :source, :input, keyword_init: true) unless const_defined?(:MockDetails, false)

  # A test's generated Unity runner: the C file to be compiled (`output_filepath`)
  # and the (possibly preprocessed) test file it was generated from (`input_filepath`).
  RunnerInfo = Struct.new(:output_filepath, :input_filepath, keyword_init: true) unless const_defined?(:RunnerInfo, false)

  # One partial header or source file's own preprocessing work, flattened out of its
  # owning testable for parallel processing (T1). `preprocessed_target` and `stale` are
  # unset until the corresponding stage settles this target's staleness.
  PartialWork = Struct.new(
    :config, :testable, :directives_only_filepath, :preprocessed_target, :stale,
    keyword_init: true
  ) unless const_defined?(:PartialWork, false)

  # One mock's own preprocessing/generation work, flattened out of its owning testable
  # for parallel processing (T2). `details` is this mock's own MockDetails; `preprocessed_target`
  # and `stale` are unset until the corresponding stage settles this target's staleness.
  MockWork = Struct.new(
    :name, :details, :testable, :directives_only_filepath, :preprocessed_target, :stale,
    keyword_init: true
  ) unless const_defined?(:MockWork, false)

  # Named record replacing the raw hash per test file. Fields are populated
  # across multiple stages; nil fields are valid until their stage sets them.
  Testable = Struct.new(
    :filepath, :name,
    :paths,                                    # Hash — build/results/mocks/partials/preprocess paths
    :preprocess,                               # Hash — preprocessing scratch state
    :mock_search_paths,                        # Array — each mocked header's own mirrored
                                                # directory below this test's mock root, folded
                                                # into search_paths so a mock is still findable
                                                # by however little path its own #include wrote
    :search_paths,
    :compile_flags, :preprocess_flags, :assembler_flags, :link_flags,
    :compile_defines, :preprocess_defines,
    :runner,                                   # RunnerInfo
    :mocks,                                    # Hash — mock name (Symbol) → MockDetails
    :partials,                                 # TestablePartials — configs map + tests/mocks module name lists
    :sources, :frameworks, :core, :objects, :executable,
    :no_link_objects, :results_pass, :results_fail,
    :executable_rebuilt,                       # Boolean — set by stage 16, read by stage 17 to decide
                                                # whether to run the fixture. Carried on the struct rather
                                                # than re-querying the dependency tracker in stage 17: by
                                                # then the executable has already been marked fresh (if it
                                                # was rebuilt), so a fresh staleness query would always
                                                # answer false regardless of what actually happened.
    keyword_init: true
  ) do
    def initialize(**kwargs)
      kwargs[:partials]           ||= TestablePartials.new(configs: {}, tests: [], mocks: [])
      kwargs[:mock_search_paths]  ||= []
      super(**kwargs)
    end
  end unless const_defined?(:Testable, false)

  # Describes one pipeline step — either a named build_step or a silent transform.
  # `condition` gates whether this stage's feature is in play at all for the project
  # (e.g. Partials or mocking enabled) -- when false, the stage is skipped in total
  # silence, exactly as if it didn't exist. `empty_condition` (nil for most stages)
  # gates a narrower case: the feature IS enabled, but this particular run happens to
  # have none of that stage's kind of work to do -- when true, the stage's heading and
  # body are both skipped, but `empty_notice` is logged at OBNOXIOUS so a verbose run
  # can still see that the stage was considered and correctly found nothing to do,
  # distinct from the feature being off project-wide.
  Stage = Struct.new(:name, :heading, :condition, :empty_condition, :empty_notice, :transform, :body, keyword_init: true) do
    def enabled?(state)
      condition.nil? || condition.call(state)
    end

    def empty?(state)
      !empty_condition.nil? && empty_condition.call(state)
    end

    def run?(state)
      enabled?(state) && !empty?(state)
    end
  end unless const_defined?(:Stage, false)

end
