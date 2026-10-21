# 🌱 Ceedling Pull-Request Checklist

Hello lovely developers! We hear you're interested in submitting some work to our project. Thanks! We really appreciate it! 

Below is a quick checklist of the things that need to be done before a full PR is merged to our project. Don't worry. You're not responsible for ALL of it. We'll accept your contribution however you are able to make it, with our thanks. But if you have some extra time and would like to maximize your contribution, here's a handy reference!

The same checklist appears in the description of every new pull request. It lives in `.github/pull_request_template.md`, and the two are kept in sync.

### Documentation

 - [ ] Has the [documentation site](https://docs.throwtheswitch.org/Ceedling/) source in `docs/mkdocs/` been updated? (if it provides a new or changed feature)
 - [ ] Does the pull request description explain what changed and why, well enough for maintainers to write the Changelog, Release Notes, and Breaking Changes entries? (maintainers write those entries)
 - [ ] Does the description say so if it changes compatibility with something that has existed before?

### Software

 - [ ] Does it follow our [coding standard](ThrowTheSwitchCodingStandard.md)?
 - [ ] Are all existing tests passing?
 - [ ] Are there new tests added and passing?
 - [ ] Do new configuration options have defaults in `lib/ceedling/defaults.rb` and entries in the configuration reference (`docs/mkdocs/configuration/reference/`)?
 - [ ] Should new configuration options be added to the starter project file (`assets/features/project.yml`) or the example projects' `project.yml` files?
 - [ ] Does the feature follow our "Logical Defaults" philosophy where possible?
 - [ ] Has it passed a peer review?
 - [ ] Could this change make a failing test appear to pass, keep a test from running, or misreport results or coverage? If so, explain in the description.
 - [ ] Does it pass CI (continuous integration) tests?
