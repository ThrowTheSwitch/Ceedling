# The Release Build Pipeline

A release build compiles and links exactly one artifact from a flat list of objects, using compile/assemble/link inputs that are resolved once and shared alike by every object, rather than the test pipeline's model of many independent, per-file records.

That one difference in shape -- one artifact instead of many independent test files -- is what makes the release pipeline so much smaller than the test pipeline: there's nothing here analogous to a `Testable`, no per-item struct at all, and no dedicated stage-sequencing class, because there's no per-item variation across a run for one to manage. Where the test pipeline earns its `TestPipelineManager` and its four independently composable stop-point flags by fanning out over N test files with real conditional structure between them, a release build is a fixed handful of steps every single time.

## The pipeline's shape

Three classes divide the work:

- **`ReleaseInvoker`** owns the whole run, lifecycle and sequencing both. It fires the `pre_release_build`/`post_release_build` plugin hooks, opens and flushes the dependency cache around the run, catches and logs any exception raised anywhere in the pipeline rather than letting it propagate, and calls the four steps below directly, in order. There's no separate pipeline-manager class the way the test pipeline has `TestPipelineManager`, precisely because there's no stop-point or conditional stage-skipping here for a dedicated class to own.
- **`ReleaseBuildPlanner`** decides *what* to build: the object list, and the compile/assemble/link flags, defines, and search paths every one of those objects will share alike. It never invokes a tool and never talks to the dependency tracker -- it only figures out the plan.
- **`ReleaseBuildExecutor`** does the actual work the plan calls for: compiling objects, linking the artifact, and copying the result into place. It's the only one of the three that invokes a tool or talks to the dependency tracker.

## `ReleaseState`

`ReleaseState` is the release pipeline's one state object, playing the same role `PipelineState` plays for the test pipeline -- except that since there's exactly one artifact here, not N independent ones, it holds both the flat object list and the shared, once-resolved compile/link inputs every object uses alike, rather than a collection of many separate per-item records. It carries the object list, the compile/assemble/link flags, defines, and search paths the planner resolves once, and `executable_rebuilt`. That last field is carried on the struct rather than re-derived later for exactly the same reason `Testable#executable_rebuilt` is on the test side: by the time anything downstream would ask "was this just rebuilt?", the dependency tracker has already been told the executable is fresh, so asking it again would always answer "no."

## The four steps, in order

**Planning** is `ReleaseBuildPlanner#plan`. It resolves the full object list (every configured release source plus any extra link-only objects), tailors the compiler/linker tool configuration for a shared-library or static-archive target if the project is still using Ceedling's own default release tools, and resolves the flags, defines, and search paths every object compiled in this run will use alike.

**Building objects** is `ReleaseBuildExecutor#compile_objects`, which compiles or assembles every object in the plan's list in parallel, each independently checked against the dependency tracker so only what's actually stale gets rebuilt.

**Building the release artifact** is `ReleaseBuildExecutor#link`. It separates any precompiled libraries or archives out of the object list, formats them (and any project-configured system or release-only libraries) as linker arguments, and links the executable if the dependency tracker reports it stale -- recording whether a real link just happened for the next step to use.

**Collecting artifacts** is `ReleaseBuildExecutor#artifactinate`, which copies the built executable, its map file, and any project-configured extra artifacts into the release artifacts directory -- but only when linking actually just happened; otherwise there's nothing new to collect.

## The single-file compile-check mode

The release pipeline has exactly one way to run less than the full sequence, and it's a parameter, not a set of flags the way the test pipeline's stop-points are: `ReleaseInvoker#setup_and_invoke` accepts an optional `files:` argument, and when it's a single-element Array rather than `nil`, planning and object-building still run against that one file, but linking and artifact-collection are skipped entirely. This is what backs the ad hoc `release:compile:<file>`/`release:assemble:<file>` Rake tasks, which exist so a project can compile one file in isolation -- to check it for syntax or compile errors during development -- without linking anything or touching the artifacts directory. Where the test pipeline's stop-points are several independently composable Symbols answering "how far should this run go," the release pipeline only ever answers a single yes-or-no question: is this a real, full release build, or a scoped single-file compile check?

## Shared vocabulary with the test pipeline

A handful of things carry over directly from the test pipeline's own conventions, worth knowing if you've read that pipeline's README first: `Batchinator`'s `#build_step` (for step framing) and `#exec` (for parallel per-object compilation) are the exact same collaborator, used the same way; the `Dependinator` register/`stale?`/`mark_fresh` pattern for deciding what actually needs (re)doing is identical; `executable_rebuilt`, as already mentioned, is the same carried-rather-than-requeried pattern under the same name; and both pipelines' classes are wired together through the same `constructor`-gem dependency-injection convention.
