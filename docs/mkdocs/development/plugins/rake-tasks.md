---
toc_depth: 2
---

# Plugin Option 3: Rake Tasks

This plugin type adds custom Rake tasks to your project that can be run with `ceedling <custom_task>`.

Naming and location conventions: `<plugin_name>/<plugin_name>.rake`

!!! warning "Rake will be fully deprecated in the future"
    The Ceedling project is working towards fully removing Rake as a runtime dependency.

## Example Rake task

```ruby
# Only tasks with description are listed by `ceedling -T`
desc "Print hello world to console"
task :hello_world do
  sh "echo Hello World!"
end
```

Resulting, example command line:

```shell
 > ceedling hello_world
 > Hello World!
```

## Running a test build from a Rake task

A Rake task can trigger a full test build itself by calling
`@ceedling[:test_invoker].setup_and_invoke`. Pass a context symbol unique to
your plugin. Ceedling uses this context to distinguish build pipelines. It
also keeps your build’s delta build state separate from ordinary test builds.
See [Delta Builds](../../getting-started/builds.md) for how this tracking works.

A plain test build using Partials compiles a [Test Partial](../../testing-guide/partials/overview.md)
in place of its module’s original source, and never compiles the original. A
plugin whose reports read that original adds `:partial_originals` to
`options:`, as in `setup_and_invoke( tests: tests, context: :my_plugin,
options: [:partial_originals] )`. The gcov and Bullseye plugins do this.
For these coverage builds, by necessity, the original source is compiled
as part of retargeting coverage results from Partials to the original
source. When Partials are active, the original’s object never links into
a test executable.

## Example Rake plugin layout

Project configuration file:

```yaml
:plugins:
  :load_paths:
    - support/plugins
  :enabled:
    - hello_world
```

Ceedling project directory structure:

```
project/
├── project.yml
└── support/
    └── plugins/
        └── hello_world/
            └── hello_world.rake
```

<br/><br/>
