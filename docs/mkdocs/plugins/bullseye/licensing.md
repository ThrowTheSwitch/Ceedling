# Licensing

!!! warning "Placeholder — expanded guidance coming later"
    This page is a placeholder. Ceedling's Bullseye plugin does not install,
    activate, or manage Bullseye licenses itself — that happens entirely
    through Bullseye's own installer and tooling, independent of Ceedling.
    More detailed guidance here (license types, floating vs. node-locked
    seats, CI considerations) is planned as Bullseye's licensing model is
    investigated further with the vendor.

## What you need

Bullseye Coverage is commercial software. To use this plugin you need:

1. A licensed installation of Bullseye Coverage for your platform.
2. That installation's tools (`covc`, `covsrc`, `covfn`, `covhtml`,
   `covselect`, and optionally `CoverageBrowser`) available on your `PATH`,
   or reachable via Ceedling's [`:environment`](../../configuration/reference/environment.md)
   settings.

See [Bullseye's downloads page][bullseye-download] to obtain an installer and
[Bullseye's licensing documentation][bullseye-license-manager] for
installation and activation details, including options for node-locked and
floating (license manager) licenses.

[bullseye-download]:         https://www.bullseye.com/cgi-bin/download
[bullseye-license-manager]:  https://www.bullseye.com/help/licenseManager.html

## What this plugin does not do (yet)

Earlier, unmaintained versions of this plugin experimented with an automatic
license enable/disable toggle tied to Bullseye's `cov01` tool. That mechanism
is not present in the current plugin. Whether an equivalent — or a different
approach suited to Bullseye's present licensing options — is worth adding
back is an open question pending further investigation.

<br/><br/>
