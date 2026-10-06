# Security Policies and Procedures

This document outlines security procedures and general policies for all `ThrowTheSwitch.org`
projects, including `Unity`, `CMock`, and `Ceedling`.

  * [Software Bill of Materials](#software-bill-of-materials)
  * [Reporting a Bug](#reporting-a-bug)
  * [Disclosure Policy](#disclosure-policy)
  * [Comments on this Policy](#comments-on-this-policy)

## Software Bill of Materials

Ceedling publishes a [Software Bill of Materials with every release](https://docs.throwtheswitch.org/Ceedling/latest/project/sbom/).
Use it to determine whether a given release is affected by a vulnerability in 
something Ceedling ships or depends on.

Each release carries two documents, one CycloneDX and one SPDX, attached beside
the `.gem` file. Every component is identified by a Package URL (PURL). The 
vendored C components are identified by the commit they are pinned at, which is 
what distinguishes two copies of the same component at different commits.

The documents describe the Ceedling gem as distributed. They do not describe the
C code Ceedling builds, nor the external tools an enabled plugin requires. Those
tools vary by installation and each plugin documents its own.

Each document is signed against the gem it describes. Verification needs the
predicate type named, because `gh attestation verify` looks for SLSA provenance
by default.

```
gh attestation verify ceedling-<version>.gem \
  --repo ThrowTheSwitch/Ceedling \
  --predicate-type https://cyclonedx.org/bom
```

## Automated Security Scanner False Positives

Ceedling is built with Ruby, and Ruby’s package manager (RubyGems/Bundler)
caches a local index of the *entire* public RubyGems.org registry in order
to resolve dependencies (e.g. `~/.gem/specs/rubygems.org%443/specs.4.8`).
That cache lists every gem ever published to RubyGems.org — including many
completely unrelated to Ceedling whose names happen to reference
cryptocurrency, wallets, or mining. An automated scanner that searches this
cache file for such keywords will find matches purely because of what
RubyGems.org hosts, not because of anything in Ceedling’s own code or its
declared dependencies.

If your organization’s security tooling flags a Ceedling installation for
cryptocurrency-related content, check first whether the flagged file
originates from a Ruby/RubyGems package cache rather than from Ceedling’s
own source tree. Ceedling’s actual dependencies are declared in `Gemfile`
and `ceedling.gemspec`, neither of which includes any cryptocurrency,
wallet, or mining related package.

Separately, Ceedling’s core function is compiling and running C test
executables. A scanner that flags a compiled test binary (e.g. a `.out` or
`.exe` file) as a suspicious executable is correctly observing Ceedling
doing its job, not a symptom of a security issue.

See [issue #940](https://github.com/ThrowTheSwitch/Ceedling/issues/940) for
an example of this exact false positive, including the specific package-cache 
evidence.

## Reporting a Bug

The tools from `ThrowTheSwitch.org` are made to collaborate with other tools like compilers, 
simulators, and such, and therefore have very low-level access to the world they live in. 
However, they are typically used in controlled development-centered environments. As such, 
they are typically not directly exposed to security concerns. 

The `ThrowTheSwitch.org` community takes security bugs seriously. Where possible, we will
make every effort to improve our tools safe use. Thank you for improving the security of 
our tools. We appreciate your efforts and responsible disclosure and will make every effort 
to acknowledge your contributions.

Report security bugs using the corresponding
[ThrowTheSwitch project’s](https://github.com/ThrowTheSwitch/) private vulnerability 
reporting feature on GitHub 
[[jump to Ceedling’s private vulnerability reporting](https://github.com/ThrowTheSwitch/Ceedling/security/advisories/new)]:

1. From the project’s repository page, select the **_Security_** tab
2. Then **_Report a vulnerability_**.

This opens a private advisory visible only to maintainers, rather than a public GitHub Issue
that would expose the vulnerability before a fix is available. If a ThrowTheSwitch project 
has not yet enabled this feature, or you would rather not use GitHub, email 
[security@thingamabyte.com](mailto:security@thingamabyte.com) instead.

Report security bugs in third-party modules to the person or team maintaining
the module.

## Disclosure Policy

Each issue will be assigned to a primary handler. This person will coordinate the fix and 
release process, involving the following steps:

  * Confirm the problem and determine the affected versions.
  * Audit code to find any potential similar problems.
  * Prepare fixes for all releases still under maintenance. These fixes will be
    released as fast as possible.

## Comments on this Policy

If you have suggestions on how this process could be improved please submit a
pull request.
