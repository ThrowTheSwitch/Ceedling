# Ceedling Plugin: TeamCity Test Suite Console Report

Prints to the console ($stdout) test suite build events and results in a format understood by the CI product TeamCity.

# Plugin Overview

This plugin is intended to be used within [TeamCity] Continuous Integration
(CI) builds. It processes Ceedling test suites and executable output into
TeamCity [service messages][service-messages]. Service messages are a specially
formatted type of log output that a TeamCity build server picks out of build
output to collect progress and metrics of various sorts.

Typically, this plugin is used only in CI builds. Its output is unhelpful in
development builds locally. See the [Configuration](#configuration) section for
options on enabling the build in CI but disabling it locally.

[TeamCity]: https://www.jetbrains.com/teamcity/
[service-messages]:
https://www.jetbrains.com/help/teamcity/service-messages.html

# Setup

Enable the plugin in your Ceedling project file by adding 
`report_tests_teamcity_stdout`.

``` YAML
:plugins:
  :enabled:
    - report_tests_teamcity_stdout
```

# Configuration

All the `report_tests_*_stdout` plugins may be enabled in various combinations.
But, some combinations may not make a great deal of sense. The TeamCity
plugin “plays nice” with all the others but is generally most appropriate 
running in a CI build on a TeamCity server. Its output will clutter and obscure
console logging at a local development environment command line.

You may enable the TeamCity plugin (above) but disable its operation using the
following.

```YAML
:teamcity:
  :build: FALSE
```

This may seem silly, right? Why enable the plugin and then disable it,
cancelling it out? The answer has to do with _where_ you use the second YAML
blurb configuration setting.

Ceedling provides Mixins for applying configurations settings on top of your
base project configuraiton file. 
See the [Mixins documentation][ceedling-mixins] for full details.

[ceedling-mixins]: ../docs/CeedlingPacket.md#base-project-configuration-file-mixins-section-entries

As an example, you might enable the plugin in the main project file that is
committed to your repository while disabling the plugin in your local user
project file that is ignored by your repository. In this way, the plugin would
run on a TeamCity build server but not in your local development environment.

# Example Output

TeamCity's convention for identifying tests uses the naming convention of the
underlying Java language in which TeamCity is written,
`package_or_namespace.ClassName.TestName`.

This plugin maps Ceedling conventions to TeamCity test service messages as
`context.TestFilepath.TestCaseName`.

* `context` Your build's context defaults to `test`. Certain other test build 
  plugins (e.g. GCov) provide a different context (`gcov`) for test builds, 
  generally named after themselves.
* `TestFilepath` This identifier is the relative filepath of the relevant test
  file without a file extension (e.g. no `.c`).
* `TestCaseName` This identifier is a test case function name within a Ceedling test file.

```sh
 > ceedling test:UsartModel
```

```
##teamcity[testSuiteStarted name='TestUsartModel' flowId='15']
##teamcity[testStarted name='test.test/TestUsartModel.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting' flowId='15']
##teamcity[testFinished name='test.test/TestUsartModel.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting' duration='81' flowId='15']
##teamcity[testStarted name='test.test/TestUsartModel.testShouldReturnErrorMessageUponInvalidTemperatureValue' flowId='15']
##teamcity[testFinished name='test.test/TestUsartModel.testShouldReturnErrorMessageUponInvalidTemperatureValue' duration='81' flowId='15']
##teamcity[testStarted name='test.test/TestUsartModel.testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately' flowId='15']
##teamcity[testFailed name='test.test/TestUsartModel.testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately' message='Function TemperatureFilter_GetTemperatureInCelcius() called more times than expected.' details='File: test/TestUsartModel.c Line: 25' flowId='15']
##teamcity[testFinished name='test.test/TestUsartModel.testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately' duration='81' flowId='15']
##teamcity[testIgnored name='test.test/TestUsartModel.testShouldReturnWakeupMessage' flowId='15']
##teamcity[testSuiteFinished name='TestUsartModel' flowId='15']
```
