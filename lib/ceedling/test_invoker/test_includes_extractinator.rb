# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Stage 4: a test file's #includes, from the real preprocessor. Stage 2's text scan
# reads every #include as written; this stage replaces that list with what the
# preprocessor found, in three passes that build on each other.
#
# 1. Bare includes (TestBareIncludesExtractinator): GCC's list from an isolated copy of
#    the test file, with the test file's literal #includes added as candidates and
#    stand-ins placed for their mocks and Partials.
# 2. Preprocessed includes (TestIncludesPreprocessinator): the preprocessor runs over the
#    test file, following its #includes through the stand-ins. Without -fdirectives-only,
#    a plain expansion stands in, as a best effort.
# 3. Reconciliation (TestIncludesReconcilinator): the second pass's #includes, checked
#    against the candidates, replace the stored text-scan list.
class TestIncludesExtractinator

  constructor(
    :test_bare_includes_extractinator,
    :test_includes_preprocessinator,
    :test_includes_reconcilinator
  )

  def stage_collect_preprocessor_context(state)
    @test_bare_includes_extractinator.collect( state )
    @test_includes_preprocessinator.preprocess( state )
    @test_includes_reconcilinator.reconcile( state )
  end

end
