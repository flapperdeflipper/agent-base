# Changelog
All notable changes to this project will be documented in this file.

## Unreleased

- **Fixed** — CI: tag builds now publish the GitHub release automatically (notes from the matching changelog section). A missing manual release for v1.1.1 left `update-addons.yml` untriggered, so no roll-up PR opened in `flapperdeflipper/addons`.
- **Fixed** — `update-addons.sh` now also bumps the `build_from` pins in the add-ons' `build.yaml`, which had stayed at 1.0.0 through the 1.1.0 and 1.1.1 roll-ups.

## 1.1.1

- **Changed** — certified OpenCode runtime bumped 1.18.31 → 1.18.32 (upstream patch release, 2026-09-21). No other pin changes.

## 1.1.0

- **Removed** — 37 unused apt packages from the shared toolchain (awscli, rclone, nmap, cmake/autoconf/automake/libtool, irssi, w3m, links, glab, direnv, bats, and other one-shot tools): nothing in the three add-ons, their scripts or the skills snapshot invokes them. Cuts ~333 MB installed.
- **Removed** — chromium (~384 MB net with its Mesa/GTK dependencies) from the shared base. Only the OpenCode add-on's screenshot tool launches a local browser; `ha_opencode` installs its own chromium from its 2.21.0 release, and OpenChamber/Terminal stop shipping it entirely. (The codec/audio libraries stay — ffmpeg keeps them alive.)
- **Kept** — imagemagick and ffmpeg (media/image work in agent sessions), shellcheck, graphviz (`dot` renders graphs in the writing skills), stow (Terminal dotfiles sync), highlight (LSP server), the gcc/g++/make build toolchain and the full interactive unix toolset.

## 1.0.0

- **Initial release** — the shared base image for the `ha_opencode`, `ha_openchamber` and `terminal` Home Assistant add-ons, extracted from the toolchain layers those three add-ons each installed independently.
- **Toolchain** — exact Node `24.21.0` runtime, opencode (certified hard pin, recorded in `/usr/local/share/opencode-certified-version`), prettier, tsx, ppq-private-mode, hab, zigporter, ttyd, yq, 1Password CLI, cosign.
- **Unix toolset** — the merged package set of the three add-ons (editors incl. vim/neovim, fzf, bat, zoxide, shellcheck, bats, network inspection, build toolchain, python venv tooling, archives).
- **ttyd ingress page** — the patched index page (clipboard, touch scrolling, resize-fit) is built into `/opt/ttyd/index.html`, ready for `ttyd -I`.
- **Skills snapshot** — the flapperdeflipper/skills repository is baked into `/opt/skills` at a pinned commit; `skills-update` fast-forwards it interactively.
- **CI** — contract tests + build gate on PRs, `:edge` on master, `:X.Y.Z` + `:latest` on tags, cosign keyless signing, optional Docker Hub mirror.
- **Automation** — on release, `update-addons.yml` opens a PR in `flapperdeflipper/addons` repointing the three add-ons at the new image version.
