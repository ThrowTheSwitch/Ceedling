# Branching & releases

Ceedling keeps two long-lived branches and publishes from Git tags. The branch you
work from depends on whether you are fixing a released version or building the next
one. The tag you push determines whether a release is a pre-release or a full
release.

## Branches

* `master` holds the latest release and subsequent patch releases.
* `next_version` holds the next minor or major release.

Both branches are protected by a GitHub ruleset. Changes reach them only through
pull requests, and a pull request merges only once the **CI Gate** check passes.
Direct pushes, force-pushes, and branch deletion are blocked. Only a maintainer
merges a pull request.

CI Gate reduces every CI job to one result. A pull request that changes only
documentation skips the test suites and still passes CI Gate, so it is ready to
merge in minutes. The development workflow guide describes [what counts as
documentation][ci-workflows].

Maintainers squash-merge community pull requests, so each lands as one commit
attributed to its author. Maintainers may merge their own branches with a merge
commit to keep their history.

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

Only repository administrators can create, move, or delete `v` tags. A pushed
release tag is left where it is, so a published version always points at the code
it was built from.

| Tag | Workflow | Result |
|---|---|---|
| `v1.2.0` | `release.yml` | GitHub release, and the gem published to RubyGems.org |
| `v1.2.0-pre.1` | `prerelease.yml` | GitHub pre-release only |

A hyphenated suffix becomes a dot in the gem version, which is RubyGems
pre-release notation. Tag `v1.2.0-pre.1` builds `ceedling-1.2.0.pre.1.gem`.

A full release reaches RubyGems.org through [trusted publishing]. The release
workflow exchanges its own GitHub identity for a short-lived RubyGems credential
and pushes the gem it built. No maintainer holds or handles an API key.
Pre-release gems are attached to the GitHub pre-release and never pushed to
RubyGems.org.

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
4. Date the release’s sections in `docs/Changelog.md`, `docs/BreakingChanges.md`, and `docs/KnownIssues.md`.
5. Push `v1.2.0` from `master`. CI creates the GitHub-available release and publishes the gem to RubyGems.org.
6. Bump `lib/version.rb` and continue development. Open the next release’s sections:
   - `docs/Changelog.md`: a new, empty section.
   - `docs/KnownIssues.md`: a copy of the released section. Remove each issue the next release resolves, and close the released section by naming it.
   - `docs/BreakingChanges.md`: a section only once the next release breaks something.

## Documentation deployment

Documentation versions are deployed by hand, separately from the gem. These tasks
take a bare version number rather than a tag.

```shell
 > rake docs:deploy:prerelease[1.2.0]
 > rake docs:deploy:release:latest[1.2.0]
```

The full task list is in the [documentation section][docs-tasks] of the development
workflow guide.

### Revising an earlier version’s documentation

Once a newer release becomes `latest`, its `docs/mkdocs/` content is the primary
source of the published site. An earlier version’s published documentation can
still need an occasional revision. A `docs-` tag records the source of each such
version’s published documentation.

1. Branch from the version’s `docs-<version>` tag, or from its release tag if it
   has no `docs-` tag yet.
1. Revise `docs/mkdocs/`.
1. Deploy without changing `latest`, for example `rake docs:deploy:release[1.1.0]`.
1. Point the annotated `docs-<version>` tag at the deployed commit, with a message
   naming what was deployed. `docs-1.1.0` is an example.

The branch need not merge anywhere. The tag is the record of what the published
documentation was built from. Only repository administrators can create, move, or
delete `docs-` tags.

[docs-tasks]: workflow.md#documentation
[ci-workflows]: https://github.com/ThrowTheSwitch/Ceedling/blob/master/.github/WORKFLOWS.md

[trusted publishing]: https://guides.rubygems.org/trusted-publishing/

<br/><br/>
