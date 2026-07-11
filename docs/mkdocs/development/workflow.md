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

Ceedling's documentation is built with [MkDocs] + [Material theme] and versioned
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
