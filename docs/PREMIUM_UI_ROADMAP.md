# Premium UI Roadmap — production-ready interface (Ankur)

Everything the functional app does is built (P0–P6, R1–R6, EX0–EX5). This roadmap
takes the **look and feel** from "clean Material" to a **premium, production-ready
product** — for the landing experience and for every role (AWW, Supervisor,
Doctor, Parent, Admin) — without touching the clinical logic, the offline-first
core, or the Hindi-first / colour-never-alone rules.

Organised as phases **U1–U7**, each tested, committed granularly, and pushed to
both repos (`PranavShukla2/cgms` `main`, `CNAMS/cnams_app` `Pranav`).

Status: ⬜ todo · 🚧 in progress · ✅ done.

---

## Design direction — "grows with care"

Ankur is a health tool for the field, not a flashy consumer app. **Premium here
means craft and restraint**, not decoration: a considered type scale, generous
spacing, soft layered depth, and one quiet botanical motif — so it reads as
trustworthy and calm on a cheap phone in bright sun, and polished on a tablet.

**What stays (non-negotiable):** the clinical classification palette
(green/amber/red/blue/grey), the "colour + word + icon" rule, 48 dp targets,
Hindi-first copy, offline-first, and per-role theming.

**What we add:**

- **A design-token layer.** One source of truth for spacing, corner radius,
  elevation/shadow, gradients and the type scale — so every screen is spaced and
  shaped identically. (`lib/shared/theme/design_tokens.dart`.)
- **Depth, done gently.** Soft, low-opacity shadows and layered surfaces (a card
  sits on a tinted section sits on the scaffold) instead of hard Material
  elevation. Generous 16–20 corner radii.
- **Role-tinted gradient headers.** Each dashboard opens with a hero band in a
  subtle gradient keyed to the role's primary — greeting, identity, and the one
  number that matters — so every role feels tailored yet part of one brand.
- **Premium metric cards.** Big tabular numerals, an icon chip, a label, and a
  trend/among-total hint — the summary reads at a glance.
- **A real landing/welcome moment** before the language choice.
- **Micro-motion.** Staggered card fade-in on a dashboard, pressed-tile feedback,
  a chart reveal — all ≤200 ms and all reduce-motion aware.

**Palette per role (unchanged from EX §2.1):** AWW deep teal `#00695C`,
Supervisor sprout green `#2E7D32`, Doctor clinical blue `#1565C0`, Parent warm
amber `#E68A00`, Admin slate/indigo `#4B5570`.

---

## U1 — Design-token foundation & premium components ⬜

- **`design_tokens.dart`** — `AppSpacing` (4/8/12/16/20/24/32), `AppRadius`
  (sm/md/lg/xl + pill), `AppShadows` (soft/lifted, theme-aware), and a
  `roleGradient(role, brightness)` helper.
- **Shared premium widgets** (`lib/shared/widgets/`):
  - `GradientHeader` — the role-tinted hero band (title, subtitle, trailing).
  - `MetricCard` — icon chip + big number + label + optional hint, tappable.
  - `PremiumCard` — the soft-shadow surface used everywhere in place of raw `Card`.
  - `SectionTitle` — consistent section header with optional "see all".
- Wire the tokens into `AppTheme.forRole` (card theme, input theme, radii) so
  even un-migrated screens inherit the softer shapes.

## U2 — Landing / welcome & onboarding polish ⬜

- A premium **welcome screen** (shown first-run, before language): the sprout
  mark, wordmark + tagline *हर बच्चा, स्वस्थ विकास*, a soft botanical gradient,
  and a single "Get started" CTA → language screen.
- Refine the **language screen** into elegant selectable cards (script shown in
  its own script, a check, a subtle gradient).
- Splash stays; confirm the grow-motion + reduce-motion path still holds.

## U3 — Sign-in premium polish ⬜

- Role picker as refined segmented cards with role colour + icon; the auth
  methods grouped with clear primary (Google) vs secondary hierarchy; a soft
  header; better spacing and a trust footer.

## U4 — AWW home (the most-used screen) ⬜

- Replace the sample stat tiles with a `GradientHeader` + live `MetricCard`s wired
  to **real centre stats** (screened / flagged / overdue from the DB) — drop the
  `SampleChip`.
- A prominent, premium "New measurement" CTA and a live sync-status card.

## U5 — Supervisor / Doctor / Parent dashboards ⬜

- **Supervisor** — sector rollup hero + metric cards (centres, screened, SAM/MAM,
  overdue), a flagged-cases list, wired to real roster/referral data where it
  exists (sample only where the multi-centre server data isn't yet available,
  clearly marked).
- **Doctor** — a clinical inbox: gradient hero with SAM/MAM counts, premium case
  cards with severity stripe and growth hint; wire to real referrals when present.
- **Parent** — a warm, reassuring single-child card: hero with the child, a big
  status line, the growth curve, and the next-visit reminder.

## U6 — Admin console & app-analytics ⬜

- A light "console" hero + summary metric cards that route to sub-pages
  (Users / Centres / Program analytics / App analytics / Config / Audit) —
  honouring never-cramp.
- **App-analytics** surface gets premium charts/among-total bars for sync health,
  adoption, crash-free rate (on the telemetry seams; sample where the server data
  isn't wired, marked).

## U7 — Motion & final polish ⬜

- Staggered dashboard card entrance, pressed-tile scale, chart reveal — all
  reduce-motion aware.
- Full accessibility + dark-mode sweep across the new components in every role.
- Empty/error/loading states use the shared premium widgets everywhere.

---

## Out of scope (other tracks — see UPDATES.md)

Real multi-centre / referral / telemetry **server data** (Backend), WHO tables
(Data), and hardware (IoT). Where a dashboard needs data a server would provide,
it shows a clearly-marked sample until the seam is wired — the UI is built and
ready.
