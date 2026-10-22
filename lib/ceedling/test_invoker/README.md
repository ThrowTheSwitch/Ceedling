# Test Invoker

This directory implements Ceedling's test-build pipeline -- from a list of test-file paths to compiled, linked, executed test results.

- **`PIPELINE.md`** -- the pipeline's overall architecture: its stages, the classes that own them, and the state (`PipelineState`, `Testable`) they share.
- **`HEADER_COLLISIONS.md`** -- how a mock or Partial's substitution can be silently bypassed by the real header it's meant to replace, why that happens, and the two mechanisms (`TestBuildExecutor`) that address it.
