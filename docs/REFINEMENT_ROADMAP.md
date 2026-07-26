# Refinement & Completion Roadmap (mobile app)

Everything the **mobile app itself** can still build — the remaining P5/P6 code,
plus the smaller UI/UX refinements not tracked elsewhere. Scoped to work that
needs **no other track** (Data / IoT / Backend / Field); those dependencies live
in [UPDATES.md](UPDATES.md) and [LEFTOVER.md](LEFTOVER.md).

Organised as phases **R1–R6**, done in order, each tested and pushed to both repos.

Status: ⬜ todo · 🚧 in progress · ✅ done · 🔗 blocked by another track.

---

## Where the two roadmaps stand

- **Ankur experience (EX0–EX5):** ✅ complete in code.
- **Production (P0–P4):** ✅ code complete (on placeholders for WHO data / hardware
  / server).
- **Production P5:** partly — **referral flow** and **centre view** are codeable now
  (below); the validation study & usability sessions are field work (🔗).
- **Production P6:** partly — empty states, Hindi errors, dark-mode audit, release
  config are codeable; the 2-week zero-crash window & signed-store release are
  release/field work (🔗).

---

## R1 — Finish P5 field features ✅

- ✅ **Centre view** (`FR-APP-14`): the AWW's own rollup — screened this month,
  flagged (SAM/MAM), overdue — computed live from the local DB, with the lists
  behind each count. Replaced the dev "Result demo" tab.
- ✅ **Referral flow** (`FR-APP-9`): `ReferralRepository` (raise ANM/PHC/NRC +
  record outcome + per-child query, outbox-queued); a "Refer" action on a SAM/MAM
  result and a **Referrals** section with a record-outcome picker in the history.
- ✅ Referrals + outcomes shown in the child history.

_Also fixed here:_ ✅ the DOB entry (calendar month was unusable) → year/month/day
dropdowns.

## R2 — Child lifecycle completeness

- ⬜ **Edit child** — a screen reusing `ChildRepository.updateChild` (already
  built, currently unreachable from the UI).
- ⬜ **Consent withdrawal** UI — trigger `ChildRepository.withdrawConsent` from the
  child detail with a confirm dialog (soft-delete + queued server delete).
- ⬜ Child detail header (name, age, sex, consent status, ICDS id).

## R3 — The Result screen as a first-class screen ✅

- ✅ Extracted the capture result into a reusable, polished **Result view**
  (`ResultView`): colour band + word first, the three z-scores below (tabular
  figures), a referral-advised note only for SAM/MAM. The capture flow embeds it
  with a Save footer; the history embeds it (via `ResultScreen`) with a
  **raise-referral** CTA that feeds the R1 referral flow.
- ✅ The history's latest-classification banner is tappable and opens the full
  `ResultScreen` for that measurement.

## R4 — UI / frontend polish (the small stuff) ✅ (core items)

- ✅ **About** screen — Ankur mark, product name, tagline, app version (from a
  shared `app_info` constant), and a proper **licenses** page (`showLicensePage`).
- ✅ **Shared `EmptyState`** (sprout + one line + optional CTA); wired into the
  roster (add-child CTA) and history (take-measurement CTA).
- ✅ **Roster**: sort menu (name / overdue-first / flagged-first), a latest-result
  classification badge (colour + icon) on each tile, pull-to-refresh, and a
  search-field clear button.
- ⬜ Consistent **loading** and **error** states across the async screens.
- ⬜ Optional **onboarding intro** slides after language (EX1 nicety).
- ⬜ Snackbar/confirm consistency; larger tap targets audit on dense rows.
- ⬜ Number/date formatters centralised (kg/cm/date), Devanagari-digit ready.

## R5 — Accessibility & dark mode ✅

- ✅ **Semantics labels** on icon-only controls: roster clear-search + the
  latest-classification icon, the history overflow menu + tappable result banner
  (announced as a button), the password show/hide toggle.
- ✅ **Dark mode** is wired app-wide (`themeMode: system`, light + dark
  `forRole`); components read theme tokens, so surfaces/contrast adapt. The
  clinical classification palette stays fixed by design and is always paired
  with a word/icon (never colour alone).
- ✅ System text scaling is honoured (no `textScaler` clamp; base font 16).
- ✅ **Reduce-motion** now respected beyond the splash — the loading dots hold
  still when the OS setting is on.

## R6 — Release prep (codeable parts of P6)

- ⬜ **All error/empty copy in Hindi** (+ English), no raw diagnostic text on
  user-facing paths.
- ⬜ A top-level **error boundary** so an unexpected exception shows a friendly
  screen, not a red box.
- ⬜ **Release build** config notes (signing placeholder, `--release` APK from CI).
- ⬜ Draft the **Hindi user-manual** sections (install, sign-in, register, measure,
  result, sync).
- 🔗 2-week zero-crash field window, store release, crash telemetry (needs backend).

---

## Not in scope here (other tracks — see UPDATES.md)

WHO reference tables, real BLE/GATT + hardware, the sync/identity/telemetry
servers, the agreement study and AWW usability sessions.
