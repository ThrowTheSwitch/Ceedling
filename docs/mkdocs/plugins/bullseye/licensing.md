# Licensing

Bullseye Coverage is commercial software. You need your own licensed
installation to use this plugin.

This plugin does not install, activate, or manage licenses. Bullseye's own
installer and tooling do that, independently of Ceedling. The plugin reads
license state and reports it. It never changes it.

This page covers what you need, how Bullseye's two licensing mechanisms differ,
and the one plugin setting relevant to licensing.

## What you need

You need two things.

1. A licensed installation of Bullseye Coverage for your platform.
2. Its tools on your `PATH`. Those tools are `covc`, `covsrc`, `covfn`,
   `covbr`, `covxml`, `covhtml`, `covselect`, `covlmgr`, and optionally
   `CoverageBrowser`. Ceedling's
   [`:environment`](../../configuration/reference/environment.md) settings can
   also supply the path.

Obtain an installer from [Bullseye's download page][bullseye-download].

## Checking license status

Run this task at any time to report your license state.

```shell
 > ceedling utils:bullseye_license
```

It reports your license number, its expiry date, and license manager
utilization.

```
------------------------
BULLSEYE: LICENSE STATUS
------------------------
BullseyeCoverage License Manager Administration 9.25.9 Linux-x64 License 123456 License will expire 2028-04-06
License manager disabled
```

`License manager disabled` is the expected result for an unlimited license.
Those licenses cannot use the license manager at all. It is not a problem to
fix.

This task is the first thing to try when a Bullseye tool fails for no obvious
reason. An expired or missing license surfaces only as an opaque tool failure.
Ceedling points you here when one of its own Bullseye report tools fails.

## Bullseye's two licensing mechanisms

Bullseye licenses activate two different ways. Which one applies depends on the
license you were issued. This plugin does not choose between them.

### Node-locked and unlimited licenses

These activate once, at installation. Pass your license key to Bullseye's
installer.

```shell
 > sudo ./install --key <licenseKey> --search "$PATH"
```

Activation state is written into the installation itself. Every user on that
machine can then run Bullseye's tools. Nothing per-project or per-build is
involved, and no plugin setting applies.

`--prefix <dir>` installs somewhere other than `/opt`. That avoids needing
root.

```shell
 > ./install --prefix ~/bullseye --key <licenseKey> --search "$PATH"
```

### Floating and evaluation licenses

These share a limited pool of concurrent licenses. The pool is tracked in a
single shared file called the license manager file. Bullseye's `covlmgr` tool
administers it.

Bullseye states that the license manager cannot be used with an unlimited
license. It works with floating and evaluation licenses only.

A license administrator creates the file once, on a network location that
supports file locking.

```shell
 > ./install --key <licenseKey> --create /server/BullseyeCoverageLicenseManager
```

Each client then points at that existing file.

```shell
 > covlmgr --file /server/BullseyeCoverageLicenseManager --use
```

Other useful `covlmgr` actions follow.

| Command | Purpose |
|---|---|
| `covlmgr --status` | Report current license utilization |
| `covlmgr --add <key>` | Add a license key to the file |
| `covlmgr --create --file <path>` | Create a license manager file |
| `covlmgr --use --file <path>` | Point this client at an existing file |
| `covlmgr --clear` | Reset utilization and release all licenses |

See [Bullseye's license manager documentation][bullseye-license-manager] for
full detail.

#### Configuring the license manager file

Set `:license_manager_file` to your shared file's path. The plugin sets the
`COVLM` environment variable to this value for every Bullseye tool it invokes.

```yaml
:bullseye:
  :license_manager_file: /path/to/shared/bullseye.lmgr
```

**Default:** unset

Leave this unset for a node-locked or unlimited license. It has no effect on
those.

#### Recovering a license after a killed build

A license is consumed for the duration of each Bullseye program. It is released
when that program exits. A program that is killed holds its license for 10
minutes before automatic release.

Interrupting a build can therefore leave a license checked out. Run
`covlmgr --clear` to release everything immediately, or wait out the 10 minutes.

## Using Bullseye in a container

Ceedling's `madsciencelab-plugins` Docker images do not include Bullseye. It is
commercial software requiring a license, so it cannot be bundled into a freely
distributable image. Install it into a running container yourself.

Mount your Bullseye installer into the container and install with `--prefix`,
which avoids needing root.

```shell
 > docker run -it --rm \
     -v /path/to/your/project:/home/dev/project \
     -v /path/to/BullseyeCoverage-9.25.9:/opt/bullseye-installer:ro \
     throwtheswitch/madsciencelab-plugins:1.1.0
```

Inside the container, install and put the tools on `PATH`.

```shell
 > /opt/bullseye-installer/install \
     --prefix /home/dev/bullseye \
     --key "$BULLSEYE_LICENSE_KEY" \
     --search "/usr/bin:/usr/local/bin"
 > export PATH=/home/dev/bullseye/bin:$PATH
 > ceedling utils:bullseye_license
```

!!! warning "Never commit a license key"
    Supply your key through an environment variable or a secret. Passing
    `-e BULLSEYE_LICENSE_KEY` to `docker run` keeps it out of your project
    files. A key committed to a repository is a key you have to rotate.

Installing into a running container means reinstalling each time you start a
fresh one. Building your own image layer avoids that. Treat any image carrying
an activated license as private to your organization.

## What this plugin does not do

This plugin invokes Bullseye's tools with the coverage and license environment
variables described here. It also reports license status on request.

Installing and activating Bullseye is a host or CI setup concern. The plugin
never creates a license manager file, adds a key, or releases a license.
Ceedling's generic
[`:environment`](../../configuration/reference/environment.md) configuration
can set any other environment variable a given Bullseye installation needs.

[bullseye-download]:         https://www.bullseye.com/cgi-bin/download
[bullseye-license-manager]:  https://www.bullseye.com/help/licenseManager.html

<br/><br/>
