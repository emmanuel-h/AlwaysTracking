# Releasing

Releases are automated: pushing a version tag runs [the release workflow](.github/workflows/release.yml),
which packages the addon with the [BigWigs packager](https://github.com/BigWigsMods/packager), uploads
the zip to [CurseForge](https://www.curseforge.com/wow/addons) (project 1798191) and creates a GitHub
release with the same zip.

## 1. Before tagging

1. Test the change in game. With the junction from the README in place, a `/reload` loads the working
   copy; changes to the `.toc` need a full game restart.
2. If WoW Forever has had a patch, update `## Interface:` in `AlwaysTracking.toc` to the new number
   (it is `16001` for 1.60.1). The packager picks the CurseForge game version from it.
3. Commit and push everything to `main`. Keep commits small and their first lines clear: the
   changelog shown on CurseForge is built from the commit messages since the previous tag.

## 2. Tag and push

Pick the next version ([semantic versioning](https://semver.org): `v1.0.1` for a fix, `v1.1.0` for
a new feature, `v2.0.0` for a breaking change), then:

```bash
git tag -a v1.1.0 -m "Always Tracking 1.1.0"
git push origin v1.1.0
```

Don't edit `## Version:` in the toc: it stays `@project-version@` and the packager fills in the tag.

## 3. Check the release

```bash
gh run watch --repo emmanuel-h/AlwaysTracking
```

A good run ends with `Uploading AlwaysTracking-vX.Y.Z-forever.zip ... Success!` for both CurseForge
and GitHub. The file then shows on the project's Files tab on CurseForge, possibly after CurseForge's
review.

## If a release fails

- **Packaging or upload error that isn't in the code** (expired token, CurseForge outage): fix the
  cause, then re-run the same run. The tag stays as it is.

  ```bash
  gh run rerun <run-id> --repo emmanuel-h/AlwaysTracking
  ```

- **Bug in the release itself**: fix it on `main` and release the next patch version. Don't move a tag
  that CurseForge has already received.

### Common errors

| Error in the log | Cause | Fix |
| --- | --- | --- |
| `Error fetching game version info from https://wow.curseforge.com/api/game/versions` | CurseForge rejected the API token | Replace the `CF_API_TOKEN` secret (see below) and re-run |
| `Addon TOC interface version ... is not compatible` | `## Interface:` doesn't match a Forever version | Fix the number in the toc and release a new patch version |

## One-time setup (already done)

- **CurseForge project ID**: `## X-Curse-Project-ID: 1798191` in the toc.
- **CurseForge upload token**: the `CF_API_TOKEN` repository secret. Create the token at
  <https://authors.curseforge.com/#/settings/api-tokens> (not an API key from the CurseForge developer
  console, which can't upload), then store it:

  ```bash
  gh secret set CF_API_TOKEN --repo emmanuel-h/AlwaysTracking
  ```

  To rotate it, create a new token, set the secret again, and delete the old token on CurseForge.
- **GitHub releases** use the workflow's built-in `GITHUB_TOKEN`; nothing to set up.
