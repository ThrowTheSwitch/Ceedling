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
