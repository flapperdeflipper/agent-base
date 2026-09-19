# Changelog
All notable changes to this project will be documented in this file.

## 1.0.0

- **Initial release** — the shared base image for the `ha_opencode`, `ha_openchamber` and `terminal` Home Assistant add-ons, extracted from the toolchain layers those three add-ons each installed independently.
- **Toolchain** — exact Node `24.21.0` runtime, opencode (certified hard pin, recorded in `/usr/local/share/opencode-certified-version`), prettier, tsx, ppq-private-mode, hab, zigporter, ttyd, yq, 1Password CLI, cosign.
- **Unix toolset** — the merged package set of the three add-ons (editors incl. vim/neovim, fzf, bat, zoxide, shellcheck, bats, network inspection, build toolchain, python venv tooling, archives).
- **ttyd ingress page** — the patched index page (clipboard, touch scrolling, resize-fit) is built into `/opt/ttyd/index.html`, ready for `ttyd -I`.
- **Skills snapshot** — the flapperdeflipper/skills repository is baked into `/opt/skills` at a pinned commit; `skills-update` fast-forwards it interactively.
- **CI** — contract tests + build gate on PRs, `:edge` on master, `:X.Y.Z` + `:latest` on tags, cosign keyless signing, optional Docker Hub mirror.
- **Automation** — on release, `update-addons.yml` opens a PR in `flapperdeflipper/addons` repointing the three add-ons at the new image version.
