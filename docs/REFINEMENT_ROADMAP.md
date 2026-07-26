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

## R1 — Finish P5 field features

- ⬜ **Centre view** (`FR-APP-14`): the AWW's own rollup — screened this month,
  flagged (SAM/MAM), overdue — computed from the local DB. Screen stub exists.
- ⬜ **Referral flow** (`FR-APP-9`): raise a referral from a SAM/MAM result
  (ANM/PHC/NRC) and record its outcome (`pending`/`attended`/`not_attended`/
  `unknown`) on a later visit. `ReferralsDao` + repository exist; add repo methods,
  a raise-referral action on the result, and a follow-up list.
- ⬜ Show referrals + outcomes in the child history.

## R2 — Child lifecycle completeness

- ⬜ **Edit child** — a screen reusing `ChildRepository.updateChild` (already
  built, currently unreachable from the UI).
- ⬜ **Consent withdrawal** UI — trigger `ChildRepository.withdrawConsent` from the
  child detail with a confirm dialog (soft-delete + queued server delete).
- ⬜ Child detail header (name, age, sex, consent status, ICDS id).

## R3 — The Result screen as a first-class screen

- ⬜ Extract the capture result into a reusable, polished **Result screen**
  (colour band + word first, z-scores below, referral advised) used by both the
  capture flow and history, with a **raise-referral** call to action (feeds R1).

## R4 — UI / frontend polish (the small stuff)

- ⬜ **About** screen — app version, a proper **licenses** page (`showLicensePage`).
- ⬜ **Empty states** everywhere they're missing (measurements list, referrals,
  centre view, dashboards) with a friendly sprout + one line.
- ⬜ **Roster**: sort (name / overdue), a latest-result badge on each tile,
  pull-to-refresh, search field clear button.
- ⬜ Consistent **loading** and **error** states across the async screens.
- ⬜ Optional **onboarding intro** slides after language (EX1 nicety).
- ⬜ Snackbar/confirm consistency; larger tap targets audit on dense rows.
- ⬜ Number/date formatters centralised (kg/cm/date), Devanagari-digit ready.

## R5 — Accessibility & dark mode

- ⬜ Semantics labels on icon-only controls; every colour paired with text/icon
  (audit the dashboards).
- ⬜ **Dark-mode audit** across all screens/roles (contrast, custom colours).
- ⬜ Honour system text scaling on the dense dashboards.
- ⬜ Reduce-motion respected beyond the splash.

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
