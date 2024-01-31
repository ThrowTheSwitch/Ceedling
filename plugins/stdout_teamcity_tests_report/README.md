# Ceedling Plugin: TeamCity Tests Report

# Plugin Overview

This plugin is intended to be used within [TeamCity] Continuous Integration
(CI) builds. It processes Ceedling test suites and executable output into
TeamCity [service messages][service-messages]. Service messages are a specially
formatted type of log output that a TeamCity build server picks out of build
output to collect progress and metrics of various sorts.

Typically, this plugin is used only in CI builds. Its output is unhelpful in
development builds locally. See the [Configuration](#configuration) section for
options on enabling the build in CI but disabling it locally.

[TeamCity] https://www.jetbrains.com/teamcity/
[service-messages]
https://www.jetbrains.com/help/teamcity/service-messages.html

# Example Output

```
##teamcity[testSuiteStarted name='TestModel' flowId='15']
##teamcity[testStarted name='testInitShouldCallSchedulerAndTemperatureFilterInit' flowId='15']
##teamcity[testFinished name='testInitShouldCallSchedulerAndTemperatureFilterInit' duration='170' flowId='15']
##teamcity[testSuiteFinished name='TestModel' flowId='15']
```

# Configuration

Enable the plugin in your project.yml by adding `stdout_teamcity_tests_report`.
No further configuration is necessary or possible.

``` YAML
:plugins:
  :enabled:
    - stdout_teamcity_tests_report
```

All the `stdout_*_tests_report` plugins may be enabled along with the others,
but some combinations may not make a great deal of sense. The TeamCity
plugin “plays nice” with all the others but really only makes sense enabled for
CI builds on a TeamCity server.

You may enable the TeamCity plugin (above) but disable its operation using the
following.

```YAML
:teamcity:
  :build: FALSE
```

This may seem silly, right? Why enable the plugin and then disable it,
cancelling it out? The answer has to do with _where_ you use the second YAML
blurb configuration setting.

Ceedling provides features for applying configurations settings on top of your
core project file. These include options files and user project files.
See _CeedlingPacket_ for full details. As an example, you might enable the
plugin in the main project file that is committed to your repository while
disabling the plugin in your local user project file that is ignored by your
repository. In this way, the plugin would run on a TeamCity build server but
not in your local development environment.
