# Branching & releases

Ceedling keeps two long-lived branches and publishes from Git tags. The branch you
work from depends on whether you are fixing a released version or building the next
one. The tag you push determines whether a release is a pre-release or a full
release.

## Branches

`master` holds the latest patch release. `next_version` holds the next minor or
major release.

### Patch work

Branch from `master` for a patch fix. Open the pull request against `master`.

Short-lived topic branches are the norm. Delete the branch once the pull request
merges.

### Ongoing development

Branch from `next_version` for everything else. Open the pull request against
`next_version`.

`rake lint:changed` assumes this. It compares against `next_version` unless you
name another branch or revision.

```shell
 > rake lint:changed
 > rake "lint:changed[master]"
```

## Tags drive releases

Pushing a tag publishes. Nothing else does.

Full releases are tagged on `master`. Pre-releases are tagged on `next_version`.
Neither workflow checks which branch a tag points at, so the convention is yours
to keep.

| Tag | Workflow | Result |
|---|---|---|
| `v1.2.0` | `release.yml` | GitHub release |
| `v1.2.0-pre.1` | `prerelease.yml` | GitHub pre-release |

A hyphenated suffix becomes a dot in the gem version, which is RubyGems
pre-release notation. Tag `v1.2.0-pre.1` builds `ceedling-1.2.0.pre.1.gem`.

!!! warning
    Neither workflow runs the test suite. Both build and publish directly from the
    tagged commit. Confirm CI is green on that commit before pushing a tag.

### Version reporting and the `.dev` marker

A published gem is the only build that reports a bare version. A gem built locally
reports a `.dev` suffix, so `ceedling version` says plainly which kind of install
it is.

`lib/version.rb` composes the reported version from two constants.

| Constant | Role |
|---|---|
| `BASE` | Target version for the current release cycle, maintained by hand |
| `DEV` | The marker, `.dev` in the repository and empty in a published gem |

RubyGems reads a `.dev` version as a prerelease. A locally built gem therefore
sorts below the release it precedes and never satisfies a plain
`gem install ceedling`.

### Version stamping

The publishing workflow stamps both constants before it builds. It derives the
release version from the Git tag and writes it into `BASE`, then empties `DEV`.
Neither line is ever hand-edited to match a release tag.

Bump `BASE` in `lib/version.rb` to the next cycle's target version after a 
release, then commit and continue development.

### A release cycle

1. Push `v1.2.0-pre.1` from `next_version`. CI creates a GitHub-available pre-release.
2. Iterate with `-pre.2` and onward as needed.
3. Bring the work onto `master` once the release is ready.
4. Push `v1.2.0` from `master`. CI creates the GitHub-available release.
5. A maintainer with RubyGems permissions downloads the Ceedling gem from (4) and manually pushes to RubyGems.org.
6. Bump `lib/version.rb` and continue development.

## Documentation deployment

Documentation versions are deployed by hand, separately from the gem. These tasks
take a bare version number rather than a tag.

```shell
 > rake docs:deploy:prerelease[1.2.0]
 > rake docs:deploy:release:latest[1.2.0]
```

The full task list is in the [documentation section][docs-tasks] of the development
workflow guide.

[docs-tasks]: workflow.md#documentation

<br/><br/>
