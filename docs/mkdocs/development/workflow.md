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
| `rake docs:serve` | Serve plain MkDocs site locally on port 8000 |
| `rake docs:deploy` | Deploy `dev` version to local `gh-pages` branch (no remote push) |
| `rake docs:preview` | Browse mike-versioned site locally on port 8000 |

**Browser preview in VS Code:** When `mkdocs serve` or `mike serve` binds to 
port 8000, VS Code detects it and shows a notification. The **Ports** panel also
provides an **Open in Browser** button.

**Hosted site:** [https://throwtheswitch.github.io/Ceedling/](https://throwtheswitch.github.io/Ceedling/)

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
