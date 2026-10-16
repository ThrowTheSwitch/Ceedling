# Ceedling GitHub Actions

Ceedling’s GitHub Actions do three jobs. They test every pull request and integration-branch push across Linux, Windows, and macOS. They report the results on the pull request, and they publish tagged releases. Five workflows split this work, three composite actions share steps among them, and two shell scripts and a set of rake tasks do the work inside the steps.

## Workflows at a glance

| Workflow | Trigger | Purpose |
|---|---|---|
| [`ci.yml`](workflows/ci.yml) | Push to `master` or `next_version`; any pull request except to `gh-pages`; manual dispatch | Test everything, validate the gem build, and render the CI summary |
| [`pr-comment.yml`](workflows/pr-comment.yml) | Completion of a `CI` run | Post the CI summary as a sticky pull request comment |
| [`prerelease.yml`](workflows/prerelease.yml) | Tag push matching `v*.*.*-pre.*`, `-beta.*`, or `-alpha.*` | Publish a GitHub pre-release |
| [`release.yml`](workflows/release.yml) | Tag push matching `v*.*.*` with no suffix | Publish a GitHub release and push the gem to RubyGems.org |
| [`_generate-docs.yml`](workflows/_generate-docs.yml) | Called by the three above | Build the HTML documentation bundle the gem ships |
| [`_publish-gem.yml`](workflows/_publish-gem.yml) | Called by `prerelease.yml` and `release.yml` | Build, attest, and publish the gem |

The workflows call one another in two chains.

- **Testing:** `ci.yml` calls `_generate-docs.yml` first, because system and plugin tests build a gem that includes the documentation bundle. When `ci.yml` completes, its completion triggers `pr-comment.yml`.
- **Releasing:** `prerelease.yml` and `release.yml` each call `_generate-docs.yml`, then `_publish-gem.yml`. They differ only in the `prerelease` input.

Feature branches get CI only through their pull request. `ci.yml` deliberately triggers on push only for `master` and `next_version`, the branches that are never themselves the source of a pull request. This avoids two identical runs for one commit. A `concurrency` group keyed on the commit SHA cancels any duplicate run that still occurs. Draft pull requests skip every job until they are marked ready for review.

## CI summary and pull request comment

Every CI run renders one markdown summary in its GitHub page. On a pull request that summary becomes a single comment, updated in place on every later run. It reads top down.

1. **Verdict:** the commit, how many jobs passed or failed, and the baseline the run is compared against.
2. **Warnings:** any test leg that skips more specs than the same leg on the base branch. Legs are never compared with each other, because some specs skip by design on some hosts. The failure this catches is silent: a broken tool install turns that tool’s specs into skips while CI stays green.
3. **Failing jobs,** each linked to its log.
4. **Tests:** examples, failures, and pending per suite on the Linux Ruby 3.3 leg, with the change in examples against the baseline.
5. **Coverage:** line coverage per suite and combined, with percentage-point changes against the baseline.
6. **Diff coverage:** the share of changed Ruby lines in `lib/`, `bin/`, and `plugins/` that tests execute, with up to twenty uncovered ranges.
7. **Detail,** collapsed: every leg’s counts and every job.

The baseline is the summary data of a base-branch push run. Every push run on `master` or `next_version` publishes its own as the `ci-baseline` artifact, kept 90 days. A pull request run uses the baseline from the push run for its merge base. When no such run exists, for example after a `[skip ci]` commit or an expired artifact, it falls back to the base branch’s latest successful push run and marks that baseline "nearest". Without any baseline, the changes show as "—".

Posting takes two workflows because of fork permissions. A pull request from a fork runs `ci.yml` with a read-only token, so `ci.yml` only renders the summary and uploads it. `pr-comment.yml` runs in the repository’s own context, where it may write. It never checks out or runs pull request code, and it posts only when the pull request’s current head is the commit the run tested. That check also stops a stale run from overwriting a newer comment. GitHub runs a `workflow_run` workflow only from its copy on the default branch, so changes to `pr-comment.yml` take effect once merged to `master`.

## `ci.yml` jobs

All test jobs run with `fail-fast: false`, so one failing leg never hides another.

### Generate Local Docs Bundle

Calls `_generate-docs.yml`. Every test job except the locale, encoding stress, and lint jobs waits on it.

### Linux Test Suite

Ruby 3.0 through 3.5 on `ubuntu-latest`. This is the most complete leg, and two of its legs do extra work (see [Special matrix legs](#special-matrix-legs)).

1. Check out with submodules, and set up Ruby through [`actions/setup`](#composite-actions).
2. Apply the toolcache permissions workaround (see [Special matrix legs](#special-matrix-legs)), then `bundle install`.
3. Run unit specs, then integration specs. Both run before the slow tool installs, so their failures surface early.
4. Run the specs of the SBOM generator, the CI summary, and the coverage report tooling, which live in `tools/` and so are outside the shipped suites.
5. Install gdb and valgrind, then cppcheck 2.16.0. cppcheck is built from source and cached by version.
6. Install gcovr and ReportGenerator.
7. Run system specs through [`run-system-tests`](#composite-actions), then plugin tests through [`run-plugin-tests`](#composite-actions).
8. On Ruby 3.3, merge and upload the coverage report.
9. Upload the leg’s CI results, pass or fail.

### Windows Test Suite

Ruby 3.0 through 3.4 on `windows-latest`. Ruby 3.5 is not yet available on Windows runners.

1. Check out with submodules.
2. Turn off Windows Defender real-time scanning, which otherwise adds 5 to 15 minutes per run.
3. Set up Ruby and `bundle install`.
4. Run unit and integration specs.
5. Install gcovr, ReportGenerator, and cppcheck 2.16.0 through Chocolatey, with cppcheck’s install directory placed ahead of the Chocolatey shim on `PATH`.
6. Run system and plugin tests, then upload the leg’s CI results.

### macOS Test Suite

Ruby 3.1 through 3.5 on `macos-latest` (Apple Silicon), where `gcc` is Apple Clang. Ruby 3.0 has no prebuilt ARM64 binary.

1. Check out with submodules and set up Ruby.
2. Run `bundle install` with `force_ruby_platform`, which works around mixed lockfile platform strings on ARM64.
3. Run unit and integration specs.
4. Install cppcheck through Homebrew, then gcovr and ReportGenerator. gdb and valgrind are unavailable, and their specs detect that and skip.
5. Run system and plugin tests, then upload the leg’s CI results.

### Linux Test Suite (ja_JP.UTF-8 Locale)

A regression test for localized GCC preprocessor output, such as `<組み込み>` for `<built-in>`. It installs the `ja_JP.UTF-8` locale and runs `spec:system:debug:preprocessing_locale` under it on Ruby 3.3. On failure it uploads the failing projects and logs.

### Linux Encoding Stress Test (C/POSIX)

It runs the example projects with `LC_ALL=C`, under which Ruby’s default external encoding is US-ASCII, against UTF-8 sources (`spec:system:debug:encoding_stress`). It catches code that reads files without accounting for the platform encoding. On failure it uploads the failing projects and logs.

### Lint Ruby Source

RuboCop on Ruby 3.3, scoped to the Lint, Metrics, Security, and Performance departments. Pre-existing offenses are recorded in `.rubocop_todo.yml`, so only new ones are reported, annotated inline on the pull request diff. The job is advisory: `continue-on-error` keeps a finding from failing the run, though the summary still lists the job as failed. It runs in parallel with everything else.

### Validate Ceedling Gem Build

This job runs once every test job passes. It builds the gem with the documentation bundle, generates the CycloneDX and SPDX SBOMs, validates both against their published schemas, confirms neither SBOM reached the gem, and uploads the gem as an artifact. `sbom:build` also enforces the curated gem license list, so a dependency change without a license entry fails here rather than at release.

### CI Summary

This job runs after every other job, including failed ones, but not in a cancelled run (`!cancelled()`).

1. Download every leg’s results.
2. Fetch the run’s job list from the GitHub API.
3. On a pull request, compute the merge base, the zero-context diff, and the baseline.
4. Render the summary with `rake ci:summary`, and write it to the run’s own page.
5. On a pull request, upload the summary and the pull request number as `ci-summary`.
6. On a push, upload `ci-baseline`.

It needs `actions: read` and nothing more.

## Special matrix legs

- **Linux Ruby 3.3 measures coverage.** `CEEDLING_TEST_COVERAGE` instruments the unit, integration, system, and plugin runs. `coverage:report` merges them into per-suite and combined HTML reports, uploaded as `coverage-report`, and into the summary’s coverage and line-hit data. Each report is named for the suites it merges, such as `units, integration, system (714 runs)`, rather than for each run, since the system suite records one run per child process and their names would fill every page’s footer. This leg is also the summary’s reference leg. One leg suffices because coverage of Ruby does not vary by platform, and this leg already pays for every tool install.
- **Linux Ruby 3.5 runs sanitizers.** System specs build and run the generated C under ASan and UBSan with leak detection (`asan_ubsan_leaks`). Fixtures that fault on purpose are excluded by name. One leg suffices because a finding in generated C appears identically everywhere, and instrumentation roughly doubles build time.
- **Tool installs differ by OS.** Linux has every tool. Windows lacks gdb and valgrind. macOS lacks both and compiles with Apple Clang, which on current runners supports `-fdirectives-only` as GCC does. Specs that need a missing tool detect its absence and skip, and specs covering the text-scan preprocessing fallback force it so it runs on every OS.
- **Ruby ranges differ by OS.** Linux runs 3.0–3.5, Windows 3.0–3.4, and macOS 3.1–3.5.
- **Linux works around toolcache permissions.** Linux runners chmod the Ruby toolcache’s gem directories before `bundle install`, which otherwise exits 38 ([rubygems#7983](https://github.com/rubygems/rubygems/issues/7983)).

## Release workflows

`prerelease.yml` and `release.yml` share everything through `_publish-gem.yml`, whose two jobs run in order.

**Build and Publish Ceedling Gem** (`contents: write`, `id-token: write`, `attestations: write`):

1. Set up Ruby 3.3 and stamp the gem version from the tag with `stamp_gem_version.sh`.
2. Record the short commit SHA in `GIT_COMMIT_SHA`.
3. Extract the version’s Changelog section with `extract_changelog.sh` for the release notes.
4. Build the gem with the documentation bundle, then generate and schema-validate both SBOMs.
5. Attest both SBOMs against the gem.
6. Publish the GitHub release with the gem and SBOMs attached. The notes are the Changelog section when one exists, and GitHub’s auto-generated notes otherwise.
7. Upload the gem for the next job.

**Publish Gem to RubyGems.org** runs in the `rubygems` environment. It exchanges its OIDC token for a RubyGems credential, then confirms a credential was actually written. A release pushes the gem. A pre-release pushes nothing, but the credential exchange is still exercised end to end.

`release.yml` also guards its publish job against any tag containing a hyphen, which backs up the trigger’s own exclusion of pre-release tags.

## Support scripts and tasks

### Composite actions

- [`actions/setup`](actions/setup/action.yml) restores the bundle cache keyed by OS, Ruby, and `Gemfile.lock`, then sets up the requested Ruby.
- [`actions/run-system-tests`](actions/run-system-tests/action.yml) downloads the documentation bundle and runs `rake specs:system:debug`, which keeps only failing projects. It takes `coverage` and `sanitizers` inputs. On failure it uploads `specout/` as `specout-failures-<os>-ruby-<version>`.
- [`actions/run-plugin-tests`](actions/run-plugin-tests/action.yml) builds and installs the gem, then runs the FFF, Module Generator, and Dependencies plugin suites. It takes a `coverage` input.

### Shell scripts

- [`workflows/stamp_gem_version.sh`](workflows/stamp_gem_version.sh) converts a tag to a RubyGems version (`v1.1.0-pre.1` becomes `1.1.0.pre.1`) and stamps it into `lib/version.rb`. It empties the `.dev` marker so the build reports a bare version.
- [`workflows/extract_changelog.sh`](workflows/extract_changelog.sh) writes the body of one version’s section from `docs/Changelog.md`, and exits 1 when the section is absent.

### Rake tasks the workflows run

| Task | Used by | Does |
|---|---|---|
| `specs:units`, `specs:integration` | Test jobs | Run the shipped unit and integration suites |
| `specs:system:debug` | `run-system-tests` | Run system specs, keeping only failing projects |
| `spec:system:debug:<name>` | Locale and encoding stress jobs | Run one system spec file the same way |
| `sbom:specs`, `ci:summary:specs`, `coverage:specs` | Linux Test Suite | Run the specs of the tools in `tools/` |
| `coverage:report` | Linux Ruby 3.3 | Merge coverage into reports, each named for its suites, and summary data |
| `lint` | Lint Ruby Source | Run RuboCop |
| `docs:build:local` | `_generate-docs.yml` | Build the documentation bundle the gem ships |
| `sbom:build` | Gem build and publish | Generate the SBOMs and enforce the license list |
| `ci:summary` | CI Summary | Render the summary and, on a push, the baseline |

With `CI_RESULTS_DIR` set, as every test leg sets it, the spec suites also write RSpec JSON results and `coverage:report` writes the summary’s coverage data. The test legs upload that directory as `ci-results-<os>-ruby-<version>`.

### `tools/ci_summary`

The CI summary’s renderer. It is excluded from the gem, like the SBOM generator beside it.

| File | Role |
|---|---|
| `results.rb` | Reads a leg’s RSpec counts and names the leg from its artifact |
| `diff_coverage.rb` | Turns a zero-context diff and per-line hits into diff coverage |
| `renderer.rb` and `format.rb` | Build the markdown from in-memory data |
| `collector.rb` | Reads the gathered files and writes the summary and baseline. It is the only part that touches the filesystem, and it makes no network or shell calls. |

## Action dependencies

| Action | Version | Used in |
|---|---|---|
| `actions/checkout` | `v7` | Every workflow that builds or tests |
| `actions/cache` | `v6` | Bundle caches in every Ruby job; the cppcheck build on Linux |
| `actions/upload-artifact` | `v7` | Docs bundle, coverage report, leg results, CI summary, baseline, failure output, gems |
| `actions/download-artifact` | `v8` | Docs bundle, leg results, CI summary, release gem |
| `actions/attest` | `v4` | SBOM attestations in `_publish-gem.yml` |
| `ruby/setup-ruby` | `v1` | Every Ruby job, directly or through `actions/setup` |
| `rubygems/configure-rubygems-credentials` | `v2.1.0` | RubyGems trusted publishing |
| `softprops/action-gh-release` | `v3` | GitHub releases in `_publish-gem.yml` |
| `marocchino/sticky-pull-request-comment` | `v2` | The CI summary comment in `pr-comment.yml` |

`checkout`, `cache`, and the artifact actions are pinned to their latest majors for the Node 24 runtime that runners now require.

### Permissions

Each workflow grants the least it needs, and jobs narrow or extend that only where noted.

| Workflow | Permissions |
|---|---|
| `ci.yml` | `contents: read`; the CI Summary job adds `actions: read` |
| `pr-comment.yml` | `contents: read`; its job grants `actions: read` and `pull-requests: write` |
| `_generate-docs.yml` | `contents: read` |
| `prerelease.yml`, `release.yml`, `_publish-gem.yml` | `contents: write`, `id-token: write`, `attestations: write`; the RubyGems job narrows to `id-token: write` and `contents: read` |
