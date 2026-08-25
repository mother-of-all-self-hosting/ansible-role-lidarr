#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<Lidarr version>-<release>`, which is what this repository
# already publishes (`v3.1.0.4875-0`):
#
# - if defaults/main.yml points at a Lidarr version that has never been
#   released, the release counter restarts at 0 (`v3.1.4.5029-0`)
# - otherwise the counter is incremented (`v3.1.0.4875-1`), but only if
#   something that actually affects the role has changed since the last release
#
# `lidarr_version` carries a linuxserver.io tag - `<Lidarr version>-ls<rebuild
# counter>` - and only the part in front of the dash goes into the tag. A
# rebuild that changes nothing but the counter is a new build of the same Lidarr
# and rolls the release counter, exactly like a role change does. Keeping the
# `-ls36` out of the tag also keeps the tag parseable by whatever consumes it:
# the `-<release>` suffix stays the only dash-separated component.
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
# The commit-message approach this replaced never fired once: it looked for a
# renovate[bot] commit whose subject contained "docker tag to", and Renovate has
# never been able to propose a bump for this role at all. It would also have
# tagged `3.1.0.4875-ls36-0`, without the `v` this repository's tags carry and
# with the rebuild counter left in the middle.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `lidarr_version:` so that neither a commented-out example nor
# `lidarr_container_image_tag`, which is derived from it, can be mistaken for it.
version="$(sed -nE 's|^lidarr_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Lidarr version from $defaults_path"
	exit 1
fi

# `3.1.0.4875-ls36` -> `3.1.0.4875`. A value without a dash is left alone.
lidarr_version="${version%%-*}"

# The value carries no leading `v` while the tags do, but tolerate one so that a
# future change of convention does not produce a doubled prefix.
tag_prefix="v${lidarr_version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $lidarr_version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
