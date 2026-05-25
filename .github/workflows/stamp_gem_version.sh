#!/usr/bin/env bash
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Derive a RubyGems version string from a Git tag and stamp it into version.rb.
#
# Usage: stamp_gem_version.sh <tag> <version_file>
#
#   <tag>           Git tag (e.g. v1.1.0-pre.1 or v1.1.0)
#   <version_file>  Path to the version.rb file to patch in place
#
# Exits 0 on success. Exits 1 if the version file is missing.
#
# Tag-to-gem-version conversion:
#   v1.1.0-pre.1  →  1.1.0.pre.1  (hyphen becomes dot: RubyGems pre-release notation)
#   v1.1.0        →  1.1.0         (no suffix; substitution is a no-op)
#
# Local testing examples:
#   bash stamp_gem_version.sh v1.1.0 ../../lib/version.rb && grep GEM ../../lib/version.rb
#   bash stamp_gem_version.sh v1.1.0-pre.1 ../../lib/version.rb && grep GEM ../../lib/version.rb

set -euo pipefail

TAG="${1:?tag argument required}"
VERSION_FILE="${2:?version file path argument required}"

if [ ! -f "$VERSION_FILE" ]; then
  echo "Version file not found at '${VERSION_FILE}'."
  exit 1
fi

# Strip leading 'v' from the Git tag (e.g. v1.1.0-pre.1 → 1.1.0-pre.1)
GEM_VERSION="${TAG#v}"
# Replace the first hyphen with a dot (RubyGems pre-release notation)
# e.g. 1.1.0-pre.1 → 1.1.0.pre.1 ; 1.1.0 → 1.1.0 (no-op for release tags)
GEM_VERSION="${GEM_VERSION/-/.}"

sed -i "s/GEM = '.*'/GEM = '${GEM_VERSION}'/" "${VERSION_FILE}"
echo "Stamped gem version: ${GEM_VERSION}"
