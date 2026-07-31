# Licensing

Bullseye Coverage is commercial software. Ceedling's Bullseye plugin does not
install, activate, or manage Bullseye licenses itself — that happens entirely
through Bullseye's own installer and tooling, independent of Ceedling. This
page covers what you need to get a licensed installation working, and the one
configuration option this plugin offers that's relevant to licensing.

## What you need

To use this plugin you need:

1. A licensed installation of Bullseye Coverage for your platform.
2. That installation's tools (`covc`, `covsrc`, `covfn`, `covhtml`,
   `covselect`, and optionally `CoverageBrowser`) available on your `PATH`,
   or reachable via Ceedling's [`:environment`](../../configuration/reference/environment.md)
   settings.

See [Bullseye's downloads page][bullseye-download] to obtain an installer and
[Bullseye's licensing documentation][bullseye-license-manager] for
installation and activation details.

[bullseye-download]:         https://www.bullseye.com/cgi-bin/download
[bullseye-license-manager]:  https://www.bullseye.com/help/licenseManager.html

## Bullseye's two licensing mechanisms

Bullseye supports two distinct ways of licensing an installation. Which one
applies depends on the type of license you were issued — this plugin doesn't
choose between them for you.

**Node-locked / unlimited licenses** are activated once, at installation
time, by running Bullseye's own installer with your license key (for example,
`install --key <KEY> --search "$PATH"` on Unix-like systems). This writes
activation state into the installation itself (under the install prefix),
readable by every user on that machine. There is no per-build or per-project
setting involved — once a machine's Bullseye installation is activated this
way, every invocation of `covc` and friends on that machine just works.
Nothing in this plugin needs to know about it.

**Floating / evaluation licenses** work differently: multiple users or
machines share a limited pool of concurrent licenses tracked in a *license
manager file*, managed by Bullseye's `covlmgr` tool. Every Bullseye tool
invocation locates that shared file via the `COVLM` environment variable.
Note that per Bullseye's own documentation, `covlmgr` cannot be used with a
node-locked/unlimited license — this mechanism is specific to floating and
evaluation licenses.

## Configuring a floating license manager file

If your organization uses a floating/evaluation license, set
`:license_manager_file` to the path of your shared license manager file. The
plugin sets `COVLM` to this value for every Bullseye tool invocation it makes.

```yaml
:bullseye:
  :license_manager_file: /path/to/shared/bullseye.lmgr
```
**Default:** unset (no `COVLM` override — Bullseye falls back to its own
default resolution, or works unconditionally for a node-locked/unlimited
license)

This setting has no effect for node-locked/unlimited licenses; leave it unset
in that case.

For anything this option doesn't cover, Ceedling's generic
[`:environment`](../../configuration/reference/environment.md) configuration
can set any other environment variable a given Bullseye installation needs.

## What this plugin does not do

This plugin's job stops at invoking Bullseye's tools with the coverage- and
license-related environment variables described above; installing and
activating Bullseye is entirely a host or CI setup concern.

!!! note "Docker image distribution"
    Ceedling's `madsciencelab-plugins` Docker images ship Bullseye's tools
    installed but unlicensed — baking a persisted license activation into an
    image distributed this widely isn't appropriate. Licensing strategy for
    these images is still being worked out with the vendor and isn't
    something this plugin or its documentation solves.

<br/><br/>
