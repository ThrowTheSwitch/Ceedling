# Software Bill of Materials

Every Ceedling release publishes a Software Bill of Materials. The documents list
what a Ceedling gem contains and what it depends on. They exist so you can assess
your own exposure without reading Ceedling’s packaging by hand.

Two documents accompany each release. One is [CycloneDX][cyclonedx] and one is
[SPDX][spdx]. Both are generated from a single description of the gem, so neither
can state a fact the other contradicts.

!!! note "What these documents cover"
    The documents describe **the Ceedling gem as distributed**. They do not describe
    the C code Ceedling builds for you. Your own source, your generated test runners
    and mocks, and your compiler toolchain are all outside their scope.

---

## Scope

The documents describe one artifact, the published Ceedling gem. All else is out of 
scope:

**Your build output is not described.** Ceedling generates C for your project.
Test runners, mocks, and Partials are all produced from your source at build time.
None of that is part of Ceedling’s own distribution, so none of it appears in the 
SBOM.

**Plugin tool requirements are not described.** An enabled plugin may need external
tools that Ceedling never ships. For example, the Gcov, Valgrind, Bullseye, and 
Cppcheck plugins all work this way. Which tools an installation actually needs 
depends on which plugins it enables, so a project-level document cannot state it.
Each plugin documents its own requirements under [Plugins][plugins].

---

## Where to find them

The documents are attached to each release on GitHub. Look for two assets beside
the `.gem` file.

```
ceedling-<version>.cdx.json     CycloneDX
ceedling-<version>.spdx.json    SPDX
```

A gem’s own metadata also carries a pointer. The `sbom_uri` key names the CycloneDX
document for that exact version.

```shell
 > gem specification ceedling metadata
```

The documents are release assets and are never committed to the repository.

!!! warning "A version-specific link is the reliable one"
    `releases/latest/download/` resolves only to the most recent full release, and
    never to a pre-release. Because each filename carries a version, such a link
    stops working as soon as a newer release exists. Link to a version’s individual
    release page instead.

---

## What the documents include

Three kinds of component appear. Each is identified by a [Package URL][purl] (PURL).

### Ruby dependencies

The gem’s declared runtime dependencies appear with the version the release build
resolved. The declared constraint is recorded alongside as a component property.
Ceedling bounds its dependencies rather than pinning them, and recording only a
resolved version would imply otherwise.

```
pkg:gem/rake@13.2.1          declared  >= 12, < 14
```

Licenses for these come from a curated list rather than from the Gem lockfile. A
lockfile records no license at all, and a gem’s own metadata is not reliable. 
Depenencies can have messy licensing and records. The curated list of licenses
that feeds SBOM generation solves this problem. Tooling helps ensure the curated
list is reviewed upon changed to dependencies.

### Vendored C components

Unity, CMock, and CException ship inside the gem. Each is identified by the commit
it is pinned at, not by a version string. A header version appears as well, for
readers.

```
pkg:github/throwtheswitch/unity@2b80d1a357271b20f15c9f2573ddab164a626132
```

A commit is the identifier because a version string cannot always tell two copies
apart. CMock vendors its own Unity, so a Ceedling gem carries two Unity source
trees that may report the same version as different commits.

CException also ships twice, and both copies sit at the same commit. They
therefore share a Package URL. Each occurrence still appears separately, with
its own reference and its own path. A Package URL names a package. It does not
name a location.

### The fff plugin

The fff plugin is a modified descendant of an earlier project, and the documents say
so. Its lineage appears as CycloneDX pedigree and as an SPDX `VARIANT_OF`
relationship.

The plugin layer carries no Package URL of its own. Having been modified, it is no
longer the package it descends from. Pointing an identifier at that package would
invite a scanner to match advisories against code that differs.

The FFF framework itself is a separate component vendored inside the Ceedling plugin
built around it. It began as a snapshot of upstream FFF [v1.1][fff-release].

That origin is recorded here rather than in the SBOM. Nothing in the vendored source 
records a version. There is no version macro and no version file. And the vendored 
`fff.h` is not byte-identical to any upstream release, being a generated file that 
was regenerated rather than copied. Naming a release in the document would therefore 
assert more than the source supports, so the component is identified without a 
version.

---

## What the documents exclude

Development and test dependencies are excluded. RSpec, RuboCop, SimpleCov and the
rest never reach a published gem, so describing them would misstate what a user
installs. The documents name the exclusion rather than leaving it to be inferred.

Upstream fff’s own test apparatus is excluded, because the gem no longer carries it.
That tree included Google Test, which is BSD-3-Clause. Leaving it out keeps every
file in the gem MIT.

---

## Verifying an attestation

Each document is signed against the gem it describes. Verification establishes that
Ceedling’s own release workflow produced that document for that artifact.

```shell
 > gh attestation verify ceedling-<version>.gem \
     --repo ThrowTheSwitch/Ceedling \
     --predicate-type https://cyclonedx.org/bom
```

!!! warning "Name the predicate type"
    `gh attestation verify` looks for SLSA provenance unless told otherwise, and
    reports a 404 when it finds none. Pass `--predicate-type` to verify an SBOM.
    Use `https://cyclonedx.org/bom` for CycloneDX and
    `https://spdx.dev/Document/v2.3` for SPDX.

---

## GitHub’s own export

GitHub generates an SPDX document from its dependency graph, reachable under
Insights. It is a reasonable fallback, but it is not equivalent to these documents.

That export sees Ceedling’s Ruby manifests and nothing else. Unity, CMock,
CException, DIY, and fff are all absent from it, because none of them arrives as a
Ruby dependency. Those are the components most likely to matter to a C project.

[cyclonedx]:    https://cyclonedx.org
[spdx]:         https://spdx.dev
[purl]:         https://github.com/package-url/purl-spec
[plugins]:      ../plugins/index.md
[fff-release]:  https://github.com/meekrosoft/fff/releases/tag/v1.1

<br/><br/>
