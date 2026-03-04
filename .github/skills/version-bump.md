# Version Bump Skill

Use this skill when preparing a new release by bumping the library version.

## Steps

1. **`mix.exs`** — Update the `@version` module attribute to the new version string.

2. **`lib/swoosh.ex`** — Update the `@version` module attribute to match `mix.exs`.

3. **`CHANGELOG.md`** — Add a new entry at the top for the new version with a summary of the changes included in the release.

4. **`README.md`** — Update the dependency version in the installation snippet **only for minor or major version bumps** (i.e. when the minor or major component changes). Do **not** update `README.md` for patch releases.

   Example: bumping `1.22.1 → 1.23.0` (minor bump) requires updating `~> 1.22` to `~> 1.23` in `README.md`. Bumping `1.22.0 → 1.22.1` (patch) does not.
