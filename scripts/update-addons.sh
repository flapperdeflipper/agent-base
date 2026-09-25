#!/usr/bin/env bash
# ==============================================================================
# update-addons.sh — point the Home Assistant add-ons layered on agent-base at
# a new image version, bumping their patch versions and changelogs per repo
# convention (flapperdeflipper/addons).
#
# Usage, from the root of a flapperdeflipper/addons checkout:
#     scripts/update-addons.sh 1.2.3
# Idempotent: an add-on already on that version is left untouched.
# ==============================================================================
set -euo pipefail

VERSION="${1:?usage: update-addons.sh <agent-base-version-without-v>}"
ADDONS="${ADDONS:-ha_opencode ha_openchamber terminal}"
IMAGE="ghcr.io/flapperdeflipper/agent-base:${VERSION}"

command -v yq >/dev/null 2>&1 || { echo "yq (mikefarah) is required" >&2; exit 1; }

updated=()

for addon in ${ADDONS}; do
    dir="${addon}"
    dockerfile="${dir}/Dockerfile"
    build_yaml="${dir}/build.yaml"

    [ -f "${dockerfile}" ] || { echo "skip ${addon}: no Dockerfile"; continue; }

    # Add-on not (yet) layered on agent-base, or already at this version.
    grep -q '^ARG AGENT_BASE=' "${dockerfile}" || { echo "skip ${addon}: no AGENT_BASE pin"; continue; }
    grep -q "^ARG AGENT_BASE=.*:${VERSION}\$" "${dockerfile}" && { echo "skip ${addon}: already ${VERSION}"; continue; }

    sed -i -E "s|^(ARG AGENT_BASE=ghcr\.io/flapperdeflipper/agent-base):.*\$|\1:${VERSION}|" "${dockerfile}"
    yq -i ".args.AGENT_BASE = \"${IMAGE}\"" "${build_yaml}"
    # build_from must stay aligned with the Dockerfile ARG (build.yaml's own
    # header requires it); bump every arch entry.
    yq -i ".build_from[] = \"${IMAGE}\"" "${build_yaml}"

    # Repo rule: every add-on change ships with a version bump + changelog entry.
    current=$(yq '.version' "${dir}/config.yaml")
    new=$(python3 - "${current}" <<'PY'
import sys
major, minor, patch = sys.argv[1].split(".")
print(f"{major}.{minor}.{int(patch) + 1}")
PY
)
    yq -i ".version = \"${new}\"" "${dir}/config.yaml"

    entry="- **Changed** — base image pin \`ghcr.io/flapperdeflipper/agent-base\` -> \`${VERSION}\` (automated base-image update)."
    if [ "$(sed -n '3p' "${dir}/CHANGELOG.md")" = "## ${new}" ]; then
        # Section for the bumped version already exists (re-run): prepend the line.
        awk -v ver="## ${new}" -v line="${entry}" '
            $0 == ver { print; print ""; print line; printed = 1; next }
            { print }
        ' "${dir}/CHANGELOG.md" > "${dir}/CHANGELOG.md.tmp" && mv "${dir}/CHANGELOG.md.tmp" "${dir}/CHANGELOG.md"
    else
        printf '## %s\n\n%s\n\n%s\n' "${new}" "${entry}" "$(cat "${dir}/CHANGELOG.md")" > "${dir}/CHANGELOG.md"
    fi

    updated+=("${addon} (${current} -> ${new})")
done

if [ "${#updated[@]}" -eq 0 ]; then
    echo "nothing to do"
    exit 0
fi

printf 'updated %s\n' "${updated[*]}"
