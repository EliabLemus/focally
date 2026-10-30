# SPEC-002: Developer ID Signing & Notarized DMG for Focally

> Status: ready-for-implementation · Date: 2026-10-30 · Target: first signed release AFTER v0.10.0 (v0.10.0 stays untouched)
> Owner: Human Owner (credentials) + Automation (pipeline implementation, separate task)
> Scope: direct-distribution DMG only. No App Store track, no feature changes.

---

## 1. Overview

Focally is currently distributed as a **direct-download DMG that is unsigned, unnotarized, and unstapled**. On any modern macOS, Gatekeeper blocks first launch ("app can't be opened because Apple cannot check it for malicious software") and users must right-click → Open or override in System Settings.

This spec defines the change from that state to:

1. `Focally.app` signed with a **Developer ID Application** certificate, **Hardened Runtime enabled**, **secure timestamp** included.
2. The release DMG built **from the signed app**, **notarized** with `notarytool` (App Store Connect API key auth), and **stapled**.
3. A CI pipeline that **fails closed**: if signing, notarization, stapling, or Gatekeeper verification fails, no GitHub Release asset is uploaded and the Homebrew tap is not mutated.
4. Published SHA-256 computed **after stapling** and identical across local artifact, GitHub Release asset, and Homebrew cask.

**Non-goals:** App Store distribution, sandboxing, Sparkle/auto-update, changing app behavior, republishing v0.10.0.

## 2. Current State (verified at base `4d2bd8a`)

### 2.1 Signing is explicitly disabled in the build script

`scripts/build-release.sh` lines 51–60:

```bash
xcodebuild \
    -project Focally.xcodeproj \
    -scheme Focally \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
```

`CODE_SIGNING_ALLOWED=NO` / `CODE_SIGNING_REQUIRED=NO` / empty `CODE_SIGN_IDENTITY` produce an ad-hoc/unsigned app. Lines 81–96 then stage the raw app (`cp -R` + `/Applications` symlink) and `hdiutil create` an **unsigned UDZO DMG** (`Focally-vX.Y.Z.dmg`), ending with `shasum -a 256` on that unsigned DMG.

### 2.2 Release orchestration has no signing gate

`.github/workflows/release.yml` (tag trigger `v*`, `macos-15`, `permissions: contents: write`):

- `Build DMG` step calls `scripts/build-release.sh` directly.
- `Upload to Release` step **immediately** deletes/recreates the release and uploads `build/Focally-${{ github.ref_name }}.dmg` — no verification between build and publication. *(Current-state fact only: this delete-then-recreate behavior is replaced by D4/D5 — idempotent create-if-missing plus `--clobber` upload only after all pre-publication gates; `gh release delete` is forbidden per R-6.)*
- `Update Homebrew Tap` step computes `DMG_SHA` locally, clones `EliabLemus/homebrew-focally`, writes `Casks/focally.rb` with that sha256, commits and pushes. Uses existing secrets `GITHUB_TOKEN` and `TAP_TOKEN`.

### 2.3 Project configuration

`project.yml`: `PRODUCT_BUNDLE_IDENTIFIER: app.focally.mac`, `MARKETING_VERSION: "0.10.0"`, `CURRENT_PROJECT_VERSION: "83"`, `CODE_SIGN_STYLE: Automatic`, `CODE_SIGN_ENTITLEMENTS: Sources/Focally/Focally.entitlements`, **plus** an xcodegen `entitlements:` block (path `Focally/Focally.entitlements`, property `com.apple.security.automation.apple-events: true`). Both entitlements files exist on disk and are currently identical (Apple Events automation only; **not** sandboxed).

### 2.4 Runtime capabilities that signing must not regress

- `Sources/Focally/Services/PermissionService.swift` — `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions` (Accessibility prompting).
- `Sources/Focally/Services/NotificationCenterPresenter.swift` — synthetic Fn-N `CGEvent` (posts Notification Center shortcut via `CGEventSource`).
- Slack status updates via the **Slack Web API** (HTTPS); focus mode via `/usr/bin/shortcuts` run as a `Process`; DND toggling via a **CFPreferences/system mechanism**. Current code sends **no Apple Events**; entitlement `com.apple.security.automation.apple-events` is present in both entitlements files and retained defensively (§6 C3).
- Menu-bar-only app (`LSUIElement` in `Sources/Focally/Info.plist`, `NSStatusItem` in `Sources/Focally/OnItFocusApp.swift`), DND toggling, relaunch behavior.
- Local notifications (`UNUserNotificationCenter`) incl. task reminders.

### 2.5 Documented & environmental facts

- `Documentation/releases/RELEASE_NOTES_v0.10.0.md` (Known limitations): "The DMG is **not code-signed or notarized** … pre-existing distribution characteristic."
- `security find-identity -v -p codesigning` on the local Mac reports **0 valid identities** → certificate acquisition is a **Human Owner prerequisite**, not an automated task.
- v0.10.0 is a local release candidate, **not yet published**; this spec must not silently mutate or republish it. The signed pipeline applies from the **next** tag onward.

## 3. Signing & Notarization Policy Decision (required explicit recommendation)

**Chosen policy — App-first, DMG-final:**

| Step | Artifact | Action |
|---|---|---|
| 1 | `Focally.app` | Sign with **Developer ID Application** certificate, **Hardened Runtime** (`--options runtime`), **secure timestamp** (`--timestamp`), existing entitlements embedded |
| 2 | `Focally.app` | Local judge gates: `codesign --verify`, `codesign -dv`, `codesign -d --entitlements :-` (G1–G3 — codesign evidence only; **no** `spctl`/Gatekeeper assessment before notarization) |
| 3 | DMG | Create from the **already-signed** app (staging dir unchanged otherwise) |
| 4 | DMG *(optional, P1 — R-11)* | If adopted: `codesign --sign "<Developer ID Application identity>" Focally-vX.Y.Z.dmg` — **after DMG creation, BEFORE notarytool submission** |
| 5 | DMG | `xcrun notarytool submit … --wait --timeout 60m` (ASC API key profile) |
| 6 | DMG | `xcrun stapler staple` (offline ticket) + `xcrun stapler validate` |
| 7 | DMG | SHA-256 **only now**, after staple |
| 8 | Release | Publish asset + Homebrew cask pinned to that exact SHA |

**DMG code signing** (codesigning the DMG file itself) is **optional (P1)**: Apple does not require it because Gatekeeper evaluates the notarization ticket of the disk image and then the signed app inside. If adopted, it **must** run **after DMG creation and BEFORE `notarytool submit`**; the pipeline is then: create DMG → sign DMG → notarize → staple → validate → final SHA. **Never sign the DMG after stapling** — re-signing invalidates the stapled notarization ticket. DMG signing is **never a substitute for signing the inner `.app`**; signing the DMG but not the app is an explicit non-acceptable state.

App-signing verification (G1–G3, codesign evidence only), DMG notarization/stapling (G4–G5), and the post-notarization Gatekeeper assessment (G7, `spctl` → `Notarized Developer ID`) are **distinct checks and all are mandatory gates** (see §9).

## 4. Requirements (numbered)

- **R-1 (P0) Certificate & credentials.** Human Owner obtains a `Developer ID Application` certificate (and its private key) plus an App Store Connect API key with Developer or Admin role (notarization access). Exported as `.p12` (base64 for CI) and `.p8`. Stored as GitHub secrets only. No credential material may ever be committed, printed to logs, or pasted into issues/PRs.
- **R-2 (P0) Build signing.** `scripts/build-release.sh` stops passing `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=NO` for release builds and instead signs `Focally.app` with the Developer ID identity, Hardened Runtime, secure timestamp, and `Sources/Focally/Focally.entitlements` semantics preserved (single entitlements source verified — see OQ-2).
- **R-3 (P0) Verify app before packaging.** The signed app must pass all three codesign app-level gates (§9 G1–G3: signature, hardened-runtime/timestamp metadata, entitlements) **before** the DMG is created. Failure aborts before `hdiutil`. There is deliberately **no** `spctl`/Gatekeeper acceptance gate at this stage — Gatekeeper assessment is only meaningful after notarization+stapling and runs in G7 on the mounted DMG.
- **R-4 (P0) Notarize the DMG.** `xcrun notarytool submit <dmg> --keychain-profile focally-notary --wait --timeout 60m` (bounded wait; a timeout expiry fails closed and the tag can be re-run). `altool` is obsolete and forbidden. Preferred auth: ASC API key. Apple ID + app-specific password is a documented fallback only (§7).
- **R-5 (P0) Staple the DMG.** `xcrun stapler staple <dmg>` then `xcrun stapler validate <dmg>`. Both must succeed.
- **R-6 (P0) Fail closed in CI.** `.github/workflows/release.yml` runs all gates between `Build DMG` and `Upload to Release`. Any failure ⇒ workflow exits non-zero ⇒ no `gh release` mutation, no `gh release upload`, no Homebrew push. **Release retry semantics (resolved — see §13):** publication is idempotent **create-if-missing** (`gh release create` only when `gh release view` shows no release for the tag) and the asset upload uses `gh release upload --clobber` **only after all pre-publication gates (G1–G7) pass**; `gh release delete` is forbidden — an existing release is never deleted before the gates pass or because they failed. Absent/empty secrets ⇒ immediate, explicit failure **before** build (not a silent unsigned fallback).
- **R-7 (P0) Deterministic artifact & SHA discipline.** Exactly one DMG path per tag. SHA-256 is computed **once, after stapling**, and reused (env/summary file) by both the Release upload and Homebrew steps. The Homebrew step must additionally **download the uploaded asset** and verify byte-for-byte SHA equality against the local artifact before pushing the cask.
- **R-8 (P0) Ephemeral keychain hygiene (CI).** Create a temp keychain, import the P12, `set-key-partition-list` for unattended codesign, store the notary profile in it, and `trap`-delete it on exit. No persistent runner state.
- **R-9 (P0) Secret hygiene.** All secret **values** referenced as `[REDACTED]` everywhere in docs/logs; secrets masked (`add-mask`) where a value could leak via error output. Workflow secrets scoped to a protected `release` **GitHub Environment** with required approval.
- **R-10 (P0) v0.10.0 immutability.** The pipeline change lands before the next tag; the already-built v0.10.0 candidate is either published as-is (unsigned, explicitly documented) or re-tagged **only** by explicit Human Owner decision — never silently.
- **R-11 (P1) DMG signing (optional).** Per §3 step 4: if adopted, sign the DMG **after DMG creation and BEFORE `notarytool submit`**; the pipeline is then create DMG → sign DMG → notarize → staple → validate → final SHA. **Never sign the DMG after stapling** — re-signing invalidates the stapled notarization ticket. Adopt only if macOS 14+ clean-machine testing (G8) shows a concrete benefit; otherwise document as intentionally skipped (OQ-4).
- **R-12 (P0) Documentation sync.** `Documentation/guides/RELEASE_GUIDE.md`, `Documentation/guides/PROCEDIMIENTO_RELEASE.md`, and the release-notes template drop the "unsigned/unnotarized" disclaimer from the first signed release onward and document the new gates + secret prerequisites.

## 5. Technical Constraints

1. **Tools:** `codesign`, `hdiutil`, `spctl`, `xcrun notarytool`, `xcrun stapler` — all present on `macos-15` runners (Xcode 16.x). `altool` is deprecated/obsolete; not allowed.
2. **Auth preference:** App Store Connect API key (`--key`/`--key-id`/`--issuer` via stored keychain profile). Apple ID + app-specific password (`--apple-id`/`--password`/`--team-id`) documented as explicit fallback with justification: smaller orgs without an ASC API key. Fallback secrets are additional, not replacements.
3. **Trigger surface:** workflow is tag-release-only (`on: push: tags: v*`). GitHub does **not** expose secrets to fork PRs; even so, every gate must assume empty secrets and fail closed (`set -euo pipefail` + explicit presence checks).
4. **Identity pinning:** the expected identity string is injected from secret/config as `MACOS_SIGNING_IDENTITY` and validated against `security find-identity` output; the build fails if the keychain holds no matching valid `Developer ID Application` identity. The literal identity value never appears in the repo.
5. **Hardened Runtime:** enabled via `--options runtime` (or `ENABLE_HARDENED_RUNTIME=YES` in xcodebuild). No `com.apple.security.cs.disable-*` entitlements are added; any future request for one requires a new spec decision.
6. **Entitlements:** the app stays **non-sandboxed**; `com.apple.security.automation.apple-events` must remain embedded in the final signature while retained (verified by gate G3: `codesign -d --entitlements :- "${STAGED_APP}"`). Current code sends no Apple Events (§6 C3) — the entitlement is kept as a compatibility defense unless OQ-2 removes it deliberately.
7. **Timestamp:** mandatory secure timestamp (default for Developer ID via `codesign`/xcodebuild with `--timestamp`); signature must remain valid after cert expiry.
8. **Gatekeeper model:** Gatekeeper on macOS 14/15 evaluates the quarantined DMG ticket → mounted app signature. Both layers verified independently.
9. **No external actions beyond current set** without explicit approval: keychain import/notarization implemented in shell within the existing workflow steps (no third-party signing actions).

## 6. Hardened Runtime Compatibility Matrix

Hardened Runtime does **not** remove TCC permissions; it restricts executable memory, dylib loading, and task-port access. Focally uses none of those. Matrix of behaviors that must not regress (each verified on a clean machine in §9 G8):

| # | Capability | Implementation | Hardened-Runtime / signing interaction | Expected behavior after signing | Risk |
|---|---|---|---|---|---|
| C1 | **Accessibility trust & prompting** | `PermissionService.swift` (`AXIsProcessTrustedWithOptions([promptKey: true])`) | Unaffected by hardened runtime; TCC grant persists per app identity. Changing signature identity invalidates prior TCC grants from *unsigned* builds (expected one-time re-prompt for upgraders) | Prompt appears on first run; grant persists across relaunches | Low |
| C2 | **CGEvent synthetic Fn-N (Notification Center shortcut)** | `NotificationCenterPresenter.swift` (`CGEventSource(.hidSystemState)` + `maskSecondaryFn` key events) | CGEvent posting gated by **Accessibility TCC**, not by hardened runtime entitlements | Works once Accessibility granted; no extra entitlement needed | Medium — must be E2E-tested on clean machine (G8); if a future macOS blocks synthetic Fn-N from hardened apps, that is an app bug to escalate, not a signing bypass |
| C3 | **Automation entitlement (retained as defense-in-depth)** | `com.apple.security.automation.apple-events` present in both entitlements file paths today. **Current code sends no Apple Events** and prompts for none: Slack status → Slack Web API, focus → `/usr/bin/shortcuts` launched as a `Process`, DND → CFPreferences/system mechanism | Entitlement is unexercised by current code; under hardened runtime it is retained so any future Apple Events use keeps working without an emergency re-sign. Removal only as a deliberate OQ-2 outcome | No Apple Events TCC prompt (none triggered today); Slack status, focus, and DND behavior unchanged | Medium — duplicated entitlements paths (see OQ-2); gate G3 asserts the entitlement is actually embedded in the signed binary while retained |
| C4 | **Slack status, focus mode & DND toggling** | Slack status via the **Slack Web API** (outgoing HTTPS); focus via `/usr/bin/shortcuts` (`Process`); DND via **CFPreferences/system DND mechanism** | Hardened runtime does not restrict outgoing network. No sandbox ⇒ no network client entitlement needed. None of these paths sends Apple Events | Identical behavior | Low |
| C5 | **Launch/relaunch & menu-bar startup** | `LSUIElement`, `NSStatusItem` (OnItFocusApp.swift); relaunch flows | None; hardened runtime adds no launch restriction | Menu bar item appears at login/launch exactly as before | Low |
| C6 | **Local notifications** | `UNUserNotificationCenter` (session end, task reminders) | Unaffected | Prompts once, delivers normally | Low |

**Rollback for C-regressions:** if any C1–C6 fails on the signed build but passes on unsigned, stop the release, capture `Console.app` TCC/hardened-runtime logs, and do **not** ship. Entitlement/disabling-runtime "fixes" require a spec amendment.

## 7. Credentials & Secrets (names only — values are `[REDACTED]`)

Provisioning of the underlying artifacts is a **Human Owner task** (R-1). CI secrets (all values `[REDACTED]`, scoped to the protected `release` GitHub Environment):

| GitHub secret | Purpose | Format |
|---|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | Developer ID Application cert + private key, base64 of `.p12` | `[REDACTED]` |
| `MACOS_CERTIFICATE_PASSWORD` | Password of that `.p12` | `[REDACTED]` |
| `MACOS_SIGNING_IDENTITY` | Exact codesigning identity string, e.g. `Developer ID Application: [REDACTED] ([REDACTED])` | `[REDACTED]` |
| `MACOS_TEAM_ID` | Apple Team ID used for identity validation & notarytool | `[REDACTED]` |
| `NOTARY_API_KEY_P8_BASE64` | App Store Connect API key `.p8`, base64 | `[REDACTED]` |
| `NOTARY_API_KEY_ID` | ASC API key ID | `[REDACTED]` |
| `NOTARY_API_KEY_ISSUER_ID` | ASC issuer ID | `[REDACTED]` |
| `TAP_TOKEN` | Existing Homebrew tap token (already in workflow) | `[REDACTED]` |

Fallback-only (Apple ID auth, justified only if ASC API key is unavailable — see Constraint 2): `NOTARY_APPLE_ID`, `NOTARY_APPLE_ID_PASSWORD` (app-specific password), `NOTARY_TEAM_ID` — all `[REDACTED]`.

Non-secrets: keychain password is **generated at runtime** (`uuidgen`/`openssl rand`), never stored; keychain profile name is the fixed literal `focally-notary`; `GITHUB_TOKEN` is workflow-provided.

**Handling rules:** never echo values; `gh secret set` from operator machine, not from repo; rotate on exposure; GitHub Environment `release` with required reviewers and restricted to `main`/tag refs.

## 8. Implementation Plan (ordered; detail in DELTAS.md)

- **Phase 0 — Prerequisites (Human Owner, P0):** enroll Apple Developer Program (org), create Developer ID Application cert, create ASC API key, upload 7 secrets + environment protection. Blocks all else.
- **Phase 1 — Build & signing (P0):** modify `scripts/build-release.sh`: remove the three signing-disable overrides, add keychain import contract + identity validation, sign app, run gates G1–G3, then create DMG. Local-runnable on a cert-equipped Mac.
- **Phase 2 — Notarization & stapling (P0):** new `scripts/notarize-release.sh` (store-credentials profile from env, submit `--wait --timeout 60m`, staple, validate, post-staple SHA into `build/sha256.txt`, mount-verify DMG contents G7 incl. `spctl` → `Notarized Developer ID`).
- **Phase 3 — CI fail-closed wiring (P0):** `.github/workflows/release.yml`: secret presence check → keychain setup → build (Phase 1) → notarize (Phase 2) → re-verify uploaded asset SHA → only then `Upload to Release` and `Update Homebrew Tap` (with asset-SHA equality assertion R-7).
- **Phase 4 — Documentation (P1):** update `RELEASE_GUIDE.md`, `PROCEDIMIENTO_RELEASE.md`, release-notes template; record signed-distribution instructions & secret runbook.
- **Phase 5 — E2E validation (P0 gate for first signed release):** clean VM (no Xcode, fresh profile): download Release asset → verify SHA vs cask & vs `build/sha256.txt` → `brew install --cask EliabLemus/focally/focally` (or `brew fetch --cask` SHA check) → launch → walk matrix C1–C6.

## 9. Judge Gates (verification — all mandatory; any failure ⇒ fail closed)

**App-level (on staged `Focally.app`, before DMG creation — codesign evidence only; no Gatekeeper/`spctl` assessment pre-notarization):**

- **G1** `codesign --verify --deep --strict --verbose=2 "${STAGED_APP}"`
- **G2** `codesign -dv --verbose=4 "${STAGED_APP}"` — assert `TeamIdentifier=[REDACTED]` matches expected team, hardened runtime enabled (match the `flags=` line on the `(runtime)` suffix robustly; the literal is `flags=0x10000(runtime)` — do not depend on the exact hex), `Timestamp=…` present
- **G3** `codesign -d --entitlements :- "${STAGED_APP}"` — entitlements dump must contain `com.apple.security.automation.apple-events` (retention gate while the entitlement is kept — §6 C3 / OQ-2)

**Artifact-level (DMG):**

- **G4** `xcrun notarytool submit "${DMG_PATH}" --keychain-profile focally-notary --wait --timeout 60m` — exit 0 with `status: Accepted`; a `--timeout` expiry is a hard failure (fail closed, re-run the tag — T6); retain full submit JSON + `xcrun notarytool history --keychain-profile focally-notary` and `xcrun notarytool info <submission-id> …` output as workflow step summary (evidence artifact).
- **G5** `xcrun stapler staple "${DMG_PATH}"` then **G5b** `xcrun stapler validate "${DMG_PATH}"` — `The validate action worked!`
- **G6** `shasum -a 256 "${DMG_PATH}"` — computed **only after G5**, written to `build/sha256.txt`; this is the single published SHA.
- **G7** DMG mount verification (runs **after** notarization+stapling): `hdiutil attach -readonly -nobrowse` → gate re-run of G1–G3 against `/Volumes/Focally/Focally.app` → `spctl --assess --type execute --verbose=4 "/Volumes/Focally/Focally.app"` — must report `accepted` with `source=Notarized Developer ID` (Gatekeeper assessment is only valid post-notarization; there is deliberately no pre-notarization `spctl` gate) → `hdiutil detach`. Confirms the *inner* app survives packaging with a valid signature + entitlements and that Gatekeeper accepts the notarized, stapled image.
- **G8** Clean-machine E2E (first signed release + matrix C1–C6): download published asset, SHA == G6 == Homebrew cask `sha256` stanza; app launches via plain double-click with **no** Gatekeeper override.
- **G9** Post-publication equality: re-download the Release asset in-workflow (`gh release download`) and assert `shasum -a 256` equals `build/sha256.txt` **before** the Homebrew cask commit+push.

## 10. Test Matrix (CI & failure-mode coverage)

| # | Scenario | Injection | Expected result |
|---|---|---|---|
| T1 | Missing/empty secrets | Unset `MACOS_CERTIFICATE_P12_BASE64` etc. on a tag build | Workflow fails at the pre-build presence check with explicit message listing missing names; **no** build, no release, no tap push |
| T2 | Invalid P12 password | Wrong `MACOS_CERTIFICATE_PASSWORD` | `security import` fails; job stops before codesign; no release |
| T3 | Wrong identity in keychain | P12 is "Mac App Distribution" or "Apple Development" instead of Developer ID Application | Identity validation (expected-prefix + `security find-identity -p codesigning` match) fails closed; no unsigned fallback |
| T4 | Wrong team ID | `MACOS_TEAM_ID` ≠ cert's team | G2 assertion fails; no DMG creation |
| T5 | Notarization rejected | Tamper app after signing (or invalid entitlements) | `notarytool submit --wait --timeout 60m` returns `status: Invalid`; G4 exit ≠ 0; full JSON logged; no release |
| T6 | Notarization timeout | Service unavailability | `--wait --timeout 60m` expires; job fails closed (never publishes an unnotarized/unstapled DMG; never deletes an existing release); tag can be re-run |
| T7 | Staple failure | Corrupt/unnotarized DMG passed to stapler | `stapler staple` non-zero; G5b absent; no release |
| T8 | Malformed DMG | Truncate DMG before verify | G5/G7 (`hdiutil attach`/stapler validate) fail; no release |
| T9 | No downstream publication on any failure | Any of T1–T8 | Assert in test runs: zero Release assets created/modified, zero commits on homebrew tap (steps ordered after all pre-publication gates; workflow uses `set -euo pipefail`); publication is create-if-missing + `--clobber` upload only — assert zero `gh release delete` invocations and that any pre-existing release/assets are untouched on failure |
| T10 | SHA drift | Tamper DMG after G6 | G9 asset-download equality check fails before tap push |

## 11. Success Criteria

1. Tag `v*` build produces `Focally-vX.Y.Z.dmg` whose inner app passes the codesign gates G1–G3 pre-package and again inside G7's mount verification, whose DMG passes G4–G6, and whose mounted app shows `spctl` `source=Notarized Developer ID` (G7) — evidenced in the workflow summary (notarytool history/info JSON, gate transcripts).
2. Published GitHub Release asset SHA-256 == `build/sha256.txt` (G6) == Homebrew cask `sha256` (G9) — exact equality, no manual edits.
3. Clean macOS 14+ machine (fresh profile, no override): double-click install from DMG **and** `brew install --cask` both launch Focally with standard first-run TCC prompts only (matrix C1–C6 all pass).
4. Negative tests T1–T10 demonstrate zero publication on failure.
5. Release notes/guides for the signed version contain no "unsigned/unnotarized" claims (R-12).

## 12. Risks & Rollback

| Risk | Likelihood | Impact | Mitigation / Rollback |
|---|---|---|---|
| Developer ID cert not obtained (0 identities on the verified local Mac today, §2.5) | High until Phase 0 done | Blocks everything | R-10: v0.10.0 may ship unsigned by explicit decision; pipeline merges behind feature readiness |
| TCC re-prompt for existing users after identity change (unsigned → Developer ID) | Certain (one-time) | Low | Release note: users re-grant Accessibility once |
| Apple Events entitlement lost due to entitlements-path duplication (`Sources/Focally/…` vs `Focally/…`) | Medium | Future Apple Events use loses its entitlement (current code sends none — §6 C3) | G3 asserts embedded entitlement; OQ-2 resolves single source before merge |
| Notary service outage on release day | Low | Delayed release | Fail closed (T6); re-run tag workflow when service recovers |
| Bad release published anyway (process bug) | Low | Users get blocked app | Rollback: delete Release asset, revert tap commit (`git revert` in homebrew-focally), re-run; comms note. Tag is immutable ⇒ prefer re-tag `vX.Y.Z-1` after fixing |
| Homebrew cask `livecheck`/version mismatch | Low | Install failures | Cask rewrite is fully derived from tag + G6 SHA; no manual sha editing |
| Hardened runtime regression in C1–C6 | Low–Medium | Feature breakage | §6 rollback rule: stop release, no entitlement hacks, escalate |

## 13. Open Questions

- **OQ-1:** Does the org already have an Apple Developer Program membership with Developer ID issuance rights, or must enrollment (wait time) be scheduled? → Human Owner, blocks Phase 0.
- **OQ-2:** Which entitlements path is authoritative — `CODE_SIGN_ENTITLEMENTS: Sources/Focally/Focally.entitlements` or the xcodegen `entitlements:` block generating `Focally/Focally.entitlements`? Consolidate to one before Phase 1 (they are identical today; duplication invites drift).
- **OQ-3:** Should the first signed release be a patch bump of v0.10.0 content (e.g. v0.10.1, recommended) so release notes stay accurate, with v0.10.0 never published? → Human Owner.
- **OQ-4:** Adopt DMG signing (R-11/P1) or document it as intentionally skipped? Default: skip unless G8 shows a concrete need.
- **OQ-5:** Notarization auth fallback: is an ASC API key definitely available (preferred), or must the Apple ID/app-specific-password fallback (§7) be wired in Phase 3 from day one?

### Resolved decisions

- **Release retry semantics (formerly OQ-4; resolved at spec correction, 2026-10-30):** idempotent **create-if-missing** release (`gh release view` first, `gh release create` only when absent) + explicit **`gh release upload --clobber`** executed **only after all pre-publication gates (G1–G7) pass**. **Never** delete an existing release before the gates pass or because they failed — `gh release delete` is forbidden. Normative text: R-6, T9, DELTAS D4/D5.

## 14. Deltas

Implementation deltas for this spec are tracked in [`Documentation/product-specs/DELTAS.md`](DELTAS.md) (D1–D7, P0/P1, dependencies, exact file scopes, verification commands). No delta is implemented by this commit; all are `Ready` or `Blocked` pending Phase 0 credentials.
