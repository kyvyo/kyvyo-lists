# Kyvyo lists

Content blocker lists for the [Kyvyo](https://kyvyo.com) Safari extensions, compiled for Safari and published at `https://lists.kyvyo.com/v1`.

The app downloads the signed manifest, checks it with an Ed25519 public key and only installs lists whose SHA-256 matches. Nothing about the user is sent.

## Contents

| Path | Purpose |
|---|---|
| `lists/annoyances-br.txt` | Kyvyo's own rules: pop-ups and banners the community lists miss (mostly Brazilian and Mexican sites) |
| `lists/ai-overviews.txt` | Kyvyo's own rules that hide Google's AI Overview. Published as a separate list (`aiOverviews`) so the app can turn it off on its own |
| `scripts/build-lists.sh` | Downloads the source lists and compiles one `blockerList.json` per blocker, plus `aiOverviews.json` for the Pop-up Blocker |
| `scripts/check-google-ai.swift` | Opens Google searches as an iPhone and warns if the AI Overview is no longer hidden by Kyvyo's own rules (runs in the publishing workflow) |
| `scripts/publish-lists.sh` | Builds, validates in WebKit, writes and signs `v1/manifest.json` |
| `scripts/lists-tool.swift` | `keygen`, `sign` and `validate` |
| `.github/workflows/update-lists.yml` | Runs on Mondays and Thursdays at 06:00 UTC and deploys to Cloudflare Pages when a list changes |

## Sources

| Blocker | Lists |
|---|---|
| Ad Blocker | EasyList, EasyPrivacy, EasyList Portuguese, EasyList Spanish, EasyList Germany |
| Pop-up Blocker | Fanboy's Annoyance List without the Fanboy Social rules, plus `lists/annoyances-br.txt`; `lists/ai-overviews.txt` is added on top while the app setting is on |

Compiled with [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) (GPL-3.0), used only as a build tool. Each published build includes a `NOTICE.txt` with the source licenses.

## Policy for our own rules

Hide offer pop-ups, app banners, sign-in prompts, empty ad slots and sticky offer bars. Never work around paywalls or anti-adblock walls. Before hiding a pop-up, check that the page still scrolls and responds to touch.

## Local use

```bash
OUTPUT_DIR=/path/to/output ./scripts/build-lists.sh
```

```bash
swift scripts/lists-tool.swift keygen
LISTS_SIGNING_KEY=<secret> ./scripts/publish-lists.sh
```

Requires macOS with Xcode. The repository secrets are `LISTS_SIGNING_KEY`, `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

## License

Scripts, `lists/annoyances-br.txt` and `lists/ai-overviews.txt`: MIT. The compiled lists keep the licenses of their sources.
