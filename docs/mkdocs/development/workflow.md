# Ceedling development

## Installation options

### Local installation

After installing Ruby…

```shell
 > git clone --recursive https://github.com/throwtheswitch/ceedling.git
 > cd ceedling
 > git submodule update --init --recursive
 > bundle install
```

The Ceedling repository incorporates its supporting frameworks and some
plugins via Git submodules. A simple clone may not pull in the latest
and greatest.

The `bundle` tool ensures you have all needed Ruby gems installed. If 
Bundler isn’t installed on your system or you run into problems, you 
might have to install it:

```shell
 > sudo gem install bundler
```

If you run into trouble running bundler and get messages like _can’t 
find gem bundler (>= 0.a) with executable bundle 
(Gem::GemNotFoundException)_, you may need to install a different 
version of Bundler. For this please reference the version in the 
Gemfile.lock.

```shell
 > sudo gem install bundler -v <version in Gemfile.lock>
```

### Docker image usage

As an alternative to local installation of Ceedling, nearly all development 
tasks can be accomplished with the _MadScienceLab_ Docker images.

When running an existing image as a development container, one merely needs 
to map a volume from your local Ceedling code repository to Ceedling’s 
installation location within the container. With that accomplished, 
experimenting with project builds and running self-tests is simple.

1. Start your target Docker container from your host system terminal:

   ```shell
   > docker run -it --rm throwtheswitch/<image>:<tag>
   ```
1. Look up and note Ceedling’s installation path (listed in `version` output) from within the container command line:

   ```shell
   ~/project > ceedling version


   ```
1. Exit the container.
1. Restart the container from your host system with the Ceedling installation
   volume mapping from (2) and any other command line options you need:

   ```shell
   > docker run -it --rm -v /my/local/ceedling/repo:<container installation path> -v /my/local/experiment/path:/home/dev/project throwtheswitch/<image>:<tag>
   ```

For development tasks, from the container shell you can:

1. Run experiment projects you map into the container (e.g. at _/home/dev/project_).
1. Run the self-test suite. Navigate to the gem installation path discovered in (2) above. From this location, follow the instructions in the section that immediately follows.

## Managing dependencies

Two files declare Ceedling’s Ruby dependencies.

- **`ceedling.gemspec`** is part of the Ceedling gem publication process —
  it declares the runtime dependencies that ship with every published
  `ceedling` gem, installed via `gem install ceedling` regardless of
  Bundler.
- **`Gemfile`** declares dependencies for the development/contributor
  environment — running the self-test suite, generating docs, and so on.
  It duplicates `ceedling.gemspec`’s runtime dependencies by hand rather
  than using Bundler’s `gemspec` directive, and it adds development/test-only
  tools that real users never need.

Because `Gemfile` duplicates rather than references `ceedling.gemspec`,
keeping the two in sync for any shared runtime dependency is a manual step.

### When to change `Gemfile`

- **Adding or changing a runtime dependency** — a dependency real Ceedling
  users and developers both need:
  1. Add or update it in `ceedling.gemspec`.
  2. Mirror the same entry into `Gemfile`’s `# Ceedling dependencies` section
     so the development/contributor Bundler environment matches what real
     users get.
- **Adding, removing, or updating a development/test-only tool** (e.g. an
  RSpec helper) — change only `Gemfile`, under `# Testing tools`. These have
  no bearing on the published gem’s dependencies and don’t belong in
  `ceedling.gemspec`.

### Choosing version constraints

!!! note
    Runtime dependency constraints declared in `ceedling.gemspec` and their
    mirrored `Gemfile` entries should always match exactly.

This repository favors conservative version constraints.

- `~> X.Y`, the pessimistic operator, for most dependencies — it allows
  patch/minor updates within a major version and blocks the next major
  version, where a breaking change is more likely.
- An explicit range (`>= X`, `< Y`) where a specific known-incompatible
  upper bound exists.
- An open floor (`>= X`) only where no meaningful upper bound is known or
  necessary, and a specific minimum version is what actually provides
  required functionality.

When adding or changing a constraint, prefer the loosest bound that still
guarantees the API or behavior Ceedling’s code actually depends on — check
the calling code for what’s used (specific method signatures, keyword
arguments, etc.) rather than defaulting to "pin to whatever’s newest."

A floor stricter than functionally necessary can force otherwise-unneeded
work at install time — fetching and building a newer version of a
dependency when an already-available version will do.

### After changing `Gemfile`

Whenever you change `Gemfile`, regenerate `Gemfile.lock` with:

```shell
 > bundle install --prefer-local
```

Two choices in that exact command are worth understanding:

- **`--prefer-local`** — prefers an already-installed gem, including Ruby’s
  own default gems, over fetching a newer gem, as long every `Gemfile` 
  constraint is respected.
- **`bundle install`, not `bundle update`** — resolve only what changed,
  leaving everything else in `Gemfile.lock` locked as-is. A bare 
  `bundle update` re-resolves the entire dependency graph
  to the newest versions satisfying all constraints, which can bump many
  unrelated transitive dependencies at once and produce a large,
  hard-to-review `Gemfile.lock` diff.

!!! tip
    For a deliberate, targeted bump of one specific gem, use 
    `bundle update <gem name>` instead of `bundle update`.

`Gemfile` must sometimes declare gems that also ship as Ruby’s own built-in
default gems to deal with Ruby’s own package management across multiple
supported Ruby language versions (e.g. a default gem is kicked out of Ruby’s 
core). Without `--prefer-local`, Bundler resolves to the newest
version satisfying the constraint from `rubygems.org` regardless — even
when Ruby’s built-in version already satisfies it — forcing an unnecessary
fetch-and-compile of a standalone copy. If that gem itself depends on
something with a native C extension, this also then requires a full C
toolchain and Ruby’s development headers, which aren’t guaranteed to be
present on every system, particularly slim/minimal Docker images.

Commit the resulting `Gemfile.lock` changes alongside your `Gemfile` edit.

**Note:** `--prefer-local` is install-time-only — as of this writing
there’s no persistent `bundle config` equivalent. So, the `--prefer-local` 
flag must be passed explicitly every time.

!!! tip
    If you'd rather not remember the `--prefer-local`, add a shell alias, 
    e.g. in `~/.bashrc` / `~/.zshrc`:

    ```shell
    alias bundle-install-local="bundle install --prefer-local"
    ```

### Checking your environment without installing anything

To confirm your currently-installed gems still satisfy `Gemfile` /
`Gemfile.lock` without triggering any installs or fetches:

```shell
 > bundle check
```

### Running commands against Ceedling’s Bundler environment

Any Ruby-based development command that depends on the gems declared in
`Gemfile` (running specs, Rake tasks, etc.) should run through Bundler’s
managed environment so the exact versions recorded in `Gemfile.lock` are
what actually get loaded, rather than whatever happens to be installed
globally on your system.

`rake spec` and other Rake tasks in this repo already do this 
automatically; if you ever invoke an RSpec or Ruby command directly 
instead of through a Rake task, prefix it with `bundle exec`:

```shell
 > bundle exec rspec spec/some_spec.rb
```

## Running self-tests

Ceedling uses [RSpec] for its tests.

To execute tests you may run the following from the root of your local 
Ceedling repository. This test suite build option balances test coverage
with suite execution time.

```shell
 > rake spec
```

To run individual test files (Ceedling’s Ruby-based tests, that is) and 
perform other tasks, use the available Rake tasks. From the root of your 
local Ceedling repo, list those task like this:

```shell
 > rake -T
```

[RSpec]: https://rspec.info

## Troubleshooting system tests

System test failures are diagnosed from retained artifacts rather than from spec
output alone. Each system spec deploys a real Ceedling installation into a
temporary directory and runs real builds there. The RSpec failure reports which
expectation failed. It does not report what the build under test actually did.

Nothing is retained by default. A normal run deletes every temporary directory as
it finishes, so a failure leaves no evidence behind.

Two Rake tasks turn retention on.

```shell
 > rake specs:system:debug
 > rake spec:system:debug:cli_surface
```

`specs:system:debug` runs the whole suite and keeps failures only. Passing project
directories are deleted as they finish, and passing logs are never written. This
is the mode CI uses.

`spec:system:debug:<name>` runs one spec and keeps everything, pass and fail
alike. Reach for it while working on a single spec.

!!! tip
    `rake -T` advertises the family as `spec:system:debug:*`. Replace the wildcard
    with a spec name. `rake -AT spec:system:debug` lists every name it accepts.

Both tasks set `CEEDLING_SYSTEM_TEST_KEEP` on your behalf. Set it to `all` or
`failures` yourself when driving RSpec directly.

### Retained artifacts

Everything retained lands under `specout/` in the repository root.

| Path | Contents |
|---|---|
| `specout/proj/fail/` | Deployed project directory for each failing spec |
| `specout/proj/pass/` | The same for passing specs, in `all` mode only |
| `specout/fail.<description>.<pid>-<timestamp>.log` | Captured console output of a failing spec |
| `specout/pass.<description>.<pid>-<timestamp>.log` | The same for passing specs, in `all` mode only |

Each log opens with the command that produced it, followed by that command's
combined stdout and stderr.

Each retained project directory is a complete deployment, including the vendored
Ceedling the spec installed. This is where to reproduce a failure by hand. Change
into it and run the same `ceedling` command the log names.

### Failure output at the console

A failing spec prints a diagnostic block to stderr before the suite continues. The
block names the temporary directory, names the log file, and summarizes the
captured output.

The summary carries only what is worth reading first. It collects every line
containing `ERROR` or `EXCEPTION`, the whole of stderr, any debug backtrace, and
the failed and overall test summaries. Full output stays in the log file.

### Artifacts from a failed CI run

CI uploads the same directory whenever a test job fails. Download it from the
workflow run's summary page.

Artifacts are named `specout-failures-<os>-ruby-<version>`. The two specialized
jobs add `specout-failures-locale-ruby-3.3` and
`specout-failures-encoding-stress-ruby-3.3`.

CI runs in `failures` mode, so an artifact holds only failure data.

## Linting

Ceedling lints its own Ruby with [RuboCop]. Four departments are enforced. Lint
and Security catch defects. Metrics tracks complexity. Performance flags
avoidable allocations and slower idioms.

Style, Layout, and Naming are deliberately not enforced. Those departments encode
taste rather than defects, and applying them would rewrite nearly every call site
in the project to no benefit. ThrowTheSwitch's house style is described in prose
in the coding standard instead.

Configuration lives in `.rubocop.yml` at the root of the repository. Every
decision in that file is commented, including the cops deliberately turned down
and the reasoning for each.

The linting gems are not installed by an ordinary `bundle install`. Install them
once with the setup task.

```shell
 > rake lint:setup
```

Then lint the whole project, or only the files your branch changed.

```shell
 > rake lint
 > rake lint:changed
 > rake "lint:changed[master]"
```

`lint:changed` is the faster loop while working on a branch. It compares against
`next_version` unless you name another branch or revision. Quote the task name so
your shell does not interpret the brackets.

Changed files include both commits on your branch and uncommitted work in your
tree. Naming a branch that does not exist is an error rather than an empty
result.

RuboCop can correct some offenses itself. Only safe corrections are applied.
Review the resulting diff before keeping it.

```shell
 > rake lint:fix
```

Metrics offenses are never autocorrectable, so this task mostly touches
Performance cops.

### The offense backlog

A passing `rake lint` means no *new* offenses rather than zero offenses.

`.rubocop_todo.yml` records the offenses that already existed when RuboCop was
adopted. Without that file every run would report all of them and bury anything 
newly introduced.

The file is generated, and it is meant to shrink. Removing records as the
underlying code improves is the entire point of baselining. Regenerate the file
after an improvement rather than editing it by hand.

```shell
 > rake lint:todo
```

A decision to live with a cop permanently does not belong in the backlog. Those
belong in `.rubocop.yml`, with a comment explaining why the cop is wrong for this
project.

### Linting in continuous integration

CI runs `rake lint` on every pull request. Findings appear as annotations
directly on the changed lines of the diff.

The job is advisory. It reports findings without failing the build.

That is a starting position rather than the intent. The backlog is still large
enough that a new offense is unremarkable, so blocking would obstruct more than
it would protect. The job becomes blocking once the backlog has shrunk far enough
that any finding is a genuine surprise.

[RuboCop]: https://rubocop.org

## Profiling

Profiling answers where a Ceedling build spends its time. It samples a real build
of a real example project with [StackProf] and renders a flame graph.

The profiling gem is not installed by an ordinary `bundle install`. Install it
once with the setup task.

```shell
 > rake profile:setup
```

Then profile any example project against any Ceedling build task.

```shell
 > rake "profile:run[temp_sensor,test:all]"
 > rake "profile:run[temp_sensor,clobber test:all]"
```

The first argument names a project under `examples/`. The choices are
`cipher_quest`, `temp_sensor`, and `wondrous_forest`. The second argument is
whatever you would type after `ceedling`. Quote the task name so your shell does
not interpret the brackets.

### Reports

Three files land in `tmp/profiling/<project>/reports/`, each named by timestamp.

| Extension | Contents |
|---|---|
| `.txt` | Ranked list of the hottest frames |
| `.html` | Interactive flame graph |
| `.dump` | Raw StackProf data, for your own queries |

Timestamps keep successive runs from overwriting one another. A full build followed
by a no-op rebuild produces two comparable sets.

### Reading a report

Profiling runs single threaded, and that is deliberate. The task pins both thread
counts to 1 so the work stays on the thread StackProf samples. A multi-threaded run
would hide most of the build in worker threads the profiler never sees. No flame
graph this task produces says anything about thread contention.

Expect `Kernel#sleep` and `Thread#value` to dominate every report. They represent
time spent waiting on child processes rather than work done in Ruby. Read past
them to the frames underneath.

The scaffolded project persists between runs. `profile:run` copies the example into
`tmp/profiling/<project>/` on first use and leaves it there, build directory and
dependency cache included. A second run against the same project therefore
profiles a real incremental build. Delete `tmp/profiling/<project>/` to start from
a clean scaffold.

!!! note
    Profiling is unavailable on Windows. StackProf builds a native extension that
    does not compile there, so `profile:setup` declines with a message rather than
    attempting it.

[StackProf]: https://github.com/tmm1/stackprof

## Building the gem

Building the gem locally shows what a release would actually contain. The gemspec
assembles its file list by sweeping the working tree, so a local build reflects
whatever happens to be lying around.

```shell
 > rake gem:build
 > rake gem:clean
```

`gem:build` runs the same `gem build ceedling.gemspec` that CI runs and leaves
`ceedling-<version>.gem` in the repository root. `gem:clean` removes built gems.

The version carries a `.dev` suffix, so a local build is named
`ceedling-<version>.dev.gem`. `lib/version.rb` appends that marker to every build
the release pipeline did not produce, which is also why `ceedling version` reports
it. See [Branching & Releases][releases] for how a release build clears it.

`gem:build` depends on `gem:clean`, which matters more than it appears to. The
gemspec has no exclusion for `.gem` files, so a gem left from an earlier build
would be packaged inside the next one.

!!! note
    A local build omits the offline documentation bundle unless `site-local/`
    already exists. CI builds that bundle first. Run `rake docs:build:local` to
    match it.

Unpack the result to inspect it.

```shell
 > gem unpack ceedling-1.2.0.gem
```

The packaged gem deliberately carries `spec/`, `Gemfile`, `Gemfile.lock`, and
`.rspec`. External tooling runs Ceedling's own suites against the released gem
as part of validating installations and environments. These files make that 
possible.

Development-only tasks refuse to run from an unpacked gem. Profiling, linting, and
the gem tasks each need repository files the gem does not carry, so they report
that rather than failing on a missing file. The `specs:*` tasks and
`coverage:report` work as normal.

[releases]: releases.md

## Documentation

Ceedling’s documentation is built with [MkDocs] + [Material theme] and versioned
with [mike]. All Markdown source lives under `docs/mkdocs/`. The public site 
configuration is in `mkdocs.yml` while the local site bundle configuration is in
`mkdocs.local.yml`.

**First-time setup** (installs MkDocs, Material, and mike into the container):

```shell
 > rake docs:install
```

**Available Rake tasks:**

| Task | Description |
|---|---|
| `rake docs:install` | Install Python documentation tooling |
| `rake docs:build:local` | Build the site for local filesystem navigation in strict mode — fails on broken links or warnings |
| `rake docs:build:web` | Build the site to be served in strict mode — fails on broken links or warnings |
| `rake docs:build:prerelease` | Build the prerelease site in strict mode, for local validation |
| `rake docs:serve` | Serve plain MkDocs site locally on port 8000 |
| `rake docs:serve:prerelease` | Serve the prerelease site locally on port 8000, for docs development |
| `rake docs:deploy:prerelease[version]` | Deploy a prerelease build to Github Pages under `version` (usage: `rake docs:deploy:prerelease[1.2.0]`) |
| `rake docs:deploy:release[version]` | Deploy a release build to Github Pages under `version`, without changing `latest` (usage: `rake docs:deploy:release[1.1.0]`) |
| `rake docs:deploy:release:latest[version]` | Deploy a release build to Github Pages under `version` and set it as `latest` (usage: `rake docs:deploy:release:latest[1.2.0]`) |
| `rake docs:preview` | Browse mike-versioned site locally on port 8000 |

**Browser preview in VS Code:** When `mkdocs serve` or `mike serve` binds to 
port 8000, VS Code detects it and shows a notification. The **Ports** panel also
provides an **Open in Browser** button.

**Hosted site:** [https://docs.throwtheswitch.org/Ceedling/](https://docs.throwtheswitch.org/Ceedling/)

[MkDocs]: https://www.mkdocs.org
[Material theme]: https://squidfunk.github.io/mkdocs-material/
[mike]: https://github.com/jimporter/mike

## `bin/` vs. `lib/`

Most of Ceedling’s functionality is contained in the application code residing 
in `lib/`. Ceedling’s command line handling, startup configuration, project
file loading, and mixin handling are contained in a “bootloader” in `bin/`.
The code in `bin/` is the source of the `ceedling` command line tool and 
launches the application from `lib/`.

Depending on what you’re working on you may need to run Ceedling using
a specialized approach.

If you are only working in `lib/`, you can:

1. Run Ceedling using the `ceedling` command line utility you already have 
   installed. The code in `bin/` will run from your locally installed gem or 
   from within your Docker container and launch the Ceedling application for 
   you.
1. Modify a project file by setting a path value for `:project` ↳ `:which_ceedling` 
   that points to the local copy of Ceedling you cloned from the Git repository.

If you are working in `bin/`, running `ceedling` at the command line will not
call your modified code. Instead, you must execute the path to the executable
`ceedling` in the `bin/` folder of the local Ceedling repository you are 
working on.

<br/><br/>
