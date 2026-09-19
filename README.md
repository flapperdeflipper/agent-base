# agent-base

The shared base container image for the
[`ha_opencode`](https://github.com/flapperdeflipper/addons/tree/master/ha_opencode),
[`ha_openchamber`](https://github.com/flapperdeflipper/addons/tree/master/ha_openchamber)
and [`terminal`](https://github.com/flapperdeflipper/addons/tree/master/terminal)
Home Assistant add-ons. Everything the three used to install independently
lives here once; the add-ons layer only their s6 services and app code on top.

## What is in the image

| Layer | Contents |
|---|---|
| Base | `ghcr.io/home-assistant/base-debian:trixie` (s6-overlay + Bashio, Supervisor-compatible) |
| Runtime | Node (exact pin, copied from the official image), npm globals: opencode (certified hard pin), prettier, tsx, ppq-private-mode |
| CLI tooling | hab, zigporter, yq (mikefarah), 1Password CLI (`op`), cosign, gh, glab, awscli, rclone |
| Unix toolset | The merged package set of the three add-ons: vim/neovim, tmux, fzf, bat, zoxide, shellcheck, bats, direnv, stow, jq, sqlite3, network inspection (nmap, mtr, ngrep), build toolchain (gcc/g++/make/cmake/autoconf), python venv tooling, archives, chromium |
| ttyd | ttyd + the patched ingress index page at `/opt/ttyd/index.html` (clipboard, touch scrolling, resize-fit) |
| Skills | [`flapperdeflipper/skills`](https://github.com/flapperdeflipper/skills) snapshot at `/opt/skills`, pinned to a commit (`SKILLS_REF`) |

Consumers pin it like this:

```dockerfile
ARG AGENT_BASE=ghcr.io/flapperdeflipper/agent-base:1.0.0
FROM ${AGENT_BASE}
```

## Image tags

| Tag | Meaning |
|---|---|
| `X.Y.Z` | Release builds, published on `vX.Y.Z` git tags |
| `latest` | Last released version |
| `edge` | Last push to `master` |

Images are published to `ghcr.io/flapperdeflipper/agent-base` and cosign-signed
(keyless). An optional Docker Hub mirror at `flapperdeflipper/agent-base` is
enabled by setting the repo variable `DOCKERHUB_MIRROR=true` plus the
`DOCKERHUB_USERNAME` / `DOCKERHUB_PASSWORD` secrets (same names as the addons
repository).

## Keeping the pins in sync

Publishing a release (tag `vX.Y.Z`) automatically opens a pull request in
[`flapperdeflipper/addons`](https://github.com/flapperdeflipper/addons) that
repoints the three add-ons at the new image version and bumps their patch
versions and changelogs (`.github/workflows/update-addons.yml`, needs the
`ADDONS_REPO_TOKEN` secret). Dependabot in the addons repo covers the passive
path. Dependabot here bumps the build's own pins (Node image, actions).

## Skills snapshot

The skills repository is cloned at build time to a **pinned commit** so builds
are reproducible. Pick up skills changes by bumping `SKILLS_REF` and
releasing, or interactively inside a running container with `skills-update`.

## Releasing

1. Merge changes via PR (contract tests + build gate run on every PR).
2. Bump the changelog, tag `vX.Y.Z`, push the tag.
3. CI builds, pushes, signs the image; the release automation opens the
   add-on roll-up PR.

## Architecture

`linux/amd64` today, matching the addons repository build matrix. The
Dockerfile is `TARGETARCH`-aware end to end, so enabling `linux/arm64` is a
one-line platforms change when needed.

## License

MIT — see [LICENSE](LICENSE).
