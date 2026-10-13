<!--
  Thanks for contributing! Describe what changed and why below.
  Not every item applies to every pull request. Check what does, and delete what doesn't.
  This checklist is kept in sync with docs/CeedlingPullRequestChecklist.md.
-->

## Description

<!-- What changed, why, and any related issues (e.g. "Resolves: #123"). -->

## Checklist

### Documentation

 - [ ] Has the documentation site source in `docs/mkdocs/` been updated? (if it provides a new or changed feature)
 - [ ] Has `README.md` been updated? (if it provides a huge feature or change)
 - [ ] Does this description explain what changed and why, well enough for maintainers to write the Changelog, Release Notes, and Breaking Changes entries? (maintainers write those entries)
 - [ ] Does this description say so if it changes compatibility with something that has existed before?

### Software

 - [ ] Does it follow our [coding standard](https://github.com/ThrowTheSwitch/Ceedling/blob/master/docs/ThrowTheSwitchCodingStandard.md)?
 - [ ] Are all existing tests passing?
 - [ ] Are there new tests added and passing?
 - [ ] Do new configuration options have defaults in `lib/ceedling/defaults.rb` and entries in the configuration reference (`docs/mkdocs/configuration/reference/`)?
 - [ ] Should new configuration options be added to the starter project file (`assets/features/project.yml`) or the example projects' `project.yml` files?
 - [ ] Does the feature follow our "Logical Defaults" philosophy where possible?
 - [ ] Could this change make a failing test appear to pass, keep a test from running, or misreport results or coverage? If so, explain above.
 - [ ] Does it pass CI (continuous integration) tests?
