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

Ceedling's `madsciencelab-plugins` Docker images do not include Bullseye. No
Ceedling image can. Bullseye is commercial software, and distributing its
executables requires a license that a freely available image cannot carry.
Shipping the tools unlicensed is not possible either.

Download Bullseye yourself and add it to a container. There are two ways to do
that. Extend the image when you want a reusable environment. Install into a
running container when you want a one-off.

!!! note "Check the image's Ceedling version"
    Adding Bullseye to an image is only half of what you need. This plugin
    requires Ceedling 1.2.0 or newer. Releases before that ship it disabled and
    refuse to load it. Run `ceedling version` against your image to check.

!!! warning "Never commit a license key"
    Supply your key through a build argument, an environment variable, or a
    secret. A key committed to a repository is a key you have to rotate. Treat
    any image carrying an activated Bullseye license as private to your
    organization, and never push one to a public registry.

### Extending the image

Build your own layer on top of `madsciencelab-plugins`. This is the better
option for repeated use and for CI, because the install happens once at image
build time rather than on every container start.

Place your downloaded Bullseye installer beside this `Dockerfile`.

```dockerfile
FROM throwtheswitch/madsciencelab-plugins:latest

# Your downloaded, unpacked Bullseye installer directory
COPY --chown=dev:nonroot BullseyeCoverage-9.25.9 /tmp/bullseye-installer

# Supplied at build time, never baked into the Dockerfile itself
ARG BULLSEYE_LICENSE_KEY

RUN /tmp/bullseye-installer/install \
      --prefix /home/dev/bullseye \
      --key "$BULLSEYE_LICENSE_KEY" \
      --search "/usr/bin:/usr/local/bin" \
    && rm -rf /tmp/bullseye-installer

ENV PATH="/home/dev/bullseye/bin:${PATH}"
```

Build it with your key passed in.

```shell
 > docker build --build-arg BULLSEYE_LICENSE_KEY="$BULLSEYE_LICENSE_KEY" -t my-ceedling-bullseye .
```

Then run your project against the image you built.

```shell
 > docker run --rm -v /path/to/your/project:/home/dev/project my-ceedling-bullseye ceedling bullseye:all
```

!!! note "Build arguments are recorded in image history"
    `docker build --build-arg` leaves the value visible in the built image's
    metadata. Use BuildKit secrets instead if that matters to you, or build the
    image somewhere its history stays private.

### Installing into a running container

Mount your installer into a stock `madsciencelab-plugins` container and install
it there. Nothing persists after the container exits, so this suits a quick
experiment rather than repeated use.

`--prefix` installs somewhere writable, which avoids needing root.

```shell
 > docker run -it --rm \
     -e BULLSEYE_LICENSE_KEY \
     -v /path/to/your/project:/home/dev/project \
     -v /path/to/BullseyeCoverage-9.25.9:/opt/bullseye-installer:ro \
     throwtheswitch/madsciencelab-plugins:latest
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
