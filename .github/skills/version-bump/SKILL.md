# Version Bump Skill

Use this skill when preparing a new release by bumping the library version.

## Steps

1. **`mix.exs`** — Update the `@version` module attribute to the new version string.

2. **`lib/swoosh.ex`** — Update the `@version` module attribute to match `mix.exs`.

3. **`CHANGELOG.md`** — Get the changelog content from the GitHub draft release (`gh release view <tag>`). Adapt the heading levels to use `###` (the draft uses `##`). Exclude the `⛓️ Dependency` section (deps bumps). Add the new entry at the top of the changelog below the `# Changelog` heading.

4. **`README.md`** — Update the dependency version in the installation snippet **only for minor or major version bumps** (i.e. when the minor or major component changes). Do **not** update `README.md` for patch releases.

   Example: bumping `1.22.1 → 1.23.0` (minor bump) requires updating `~> 1.22` to `~> 1.23` in `README.md`. Bumping `1.22.0 → 1.22.1` (patch) does not.

5. **Commit and push** — Commit all changed files and push to `main`.

6. **Wait for Release Drafter** — Poll `gh run list` until the Release Drafter workflow run triggered by the push completes.

7. **Update draft release** — Edit the GitHub draft release to match the new version tag and title (e.g. `v1.23.1 🚀`). Do **not** publish the release.
