# Ankur — Experience Roadmap

**Ankur** (अंकुर) means *sprout / seedling* — a child, like a young plant, thrives with the right care
at the right time. This document plans the **experience layer** on top of the functional core (P0–P6):
the brand, an animated landing/splash, role-based sign-in/sign-up with Google OAuth, per-role
dashboards, and a refreshed theme.

> **Tagline:** *हर बच्चा, स्वस्थ विकास* — "Every child, growing well."

It is organised as its own phase track **EX0–EX5** so it can proceed alongside the functional roadmap.
Nothing here is built yet.

---

## 0. Why a rename and an experience layer

The functional app is Anganwadi-Worker-centric and offline-first. Ankur widens it into a small
**multi-role product**: the same growth data, seen through the lens each role needs. That means an
identity layer (who are you, what may you see), role-aware navigation, and dashboards — without
compromising the field app's offline, Hindi-first, low-tap core.

**Design principles carried over:** Hindi first; colour never the only signal; 48 dp targets; outdoor
legibility; the AWW's field flow stays fast and offline. **Added:** a warm, calm brand; motion that
informs, never decorates; strict role-based access to a child's data (consent still governs).

---

## 1. The five roles

| Role | Who | Primarily | Connectivity | Sees |
|---|---|---|---|---|
| **AWW** (आंगनवाड़ी कार्यकर्ता) | Field worker | Measures children | **Offline** (PIN) | Their centre's roster, capture, their own rollup |
| **Supervisor** (पर्यवेक्षक) | Sector/block supervisor | Oversees centres | Mostly online | Multi-centre rollup, flagged cases, referral status, exports |
| **Doctor** (चिकित्सक) | ANM / PHC / NRC clinician | Handles referrals | Online | Referred SAM/MAM cases, clinical detail, growth curves, outcomes |
| **Parent** (अभिभावक) | Guardian | Follows their child | Online | Only their own child(ren): growth card, next visit, status |
| **Admin** (प्रशासक) | Project team (you + group) | Runs the system | Online | Users, centres, config, analytics, audit |

**Access rule:** a parent sees only their linked child; an AWW only their centre; a supervisor their
sector; a doctor only cases referred to them; admin everything. Enforced server-side and mirrored in
the UI.

---

## 2. Brand & theme

- **Logo:** a two-leaf sprout rising from a seed/curve, in a rounded-square app tile. Ships as
  [`assets/branding/ankur_logo.svg`](../assets/branding/ankur_logo.svg). Monochrome and greyscale
  variants for print.
- **Wordmark:** "Ankur" / "अंकुर" with the sprout as the dot/accent.
- **Palette (brand):** deep teal `#00695C` (primary, carried over), sprout green `#2E7D32`, warm sand
  `#F4EEE2` surfaces, amber `#F9A825` accent. **Classification colours are untouched** (green / amber /
  red / blue / grey) — they're clinical, not brand.
- **Typography:** Noto Sans Devanagari + a clean Latin companion; base 16 sp, large numerals for
  measurements.
- **Motion:** one signature — a sprout that "grows" (stem then leaves, ~900 ms, eased) on the splash;
  elsewhere, quiet fades and 150–200 ms transitions. Respect reduce-motion.
- **Dark theme:** first-class (closes leftover #13).

---

## Phase EX0 — Brand & Theme Foundation

**Goal:** the app *looks* like Ankur, in light and dark, with the logo and tokens in place.

- Rename product to **Ankur** (`appTitle`, launcher name, README, store metadata); keep the package id.
- Add the logo asset + adaptive launcher icons + splash image.
- Design-token pass: brand colours, typography scale, spacing, elevation, shape — as a single source
  the theme reads. Extend `AppTheme` with `dark()`.
- Keep classification colours and the "colour + word + icon" rule intact.

**DoD:** logo and name everywhere; light+dark themes pass contrast; classification banner unchanged;
existing tests still green.

---

## Phase EX1 — Landing / Splash & Onboarding

**Goal:** a first impression and a first-run path.

- **Splash:** the sprout-grow animation over the wordmark, then route to the landing or the app.
- **Landing screen:** Ankur mark + tagline, and two actions — **Sign in** / **Create account** —
  plus the language toggle (Hindi/English) available before login.
- **First-run onboarding:** 2–3 quiet slides (what Ankur does, choose language, pick your role) — skip
  allowed. AWW onboarding ends at PIN setup for offline use.

**DoD:** cold start shows the animated splash (honours reduce-motion) then the landing; language can be
switched pre-login; onboarding shown once.

---

## Phase EX2 — Auth & Identity

**Goal:** know who the user is and what role they hold.

- **Sign-in / sign-up** with:
  - **Google OAuth** ("Sign in with Google") — for Supervisor / Doctor / Parent / Admin, and for AWW
    provisioning where a Google account exists.
  - **Email + password** fallback, and the existing **PIN** for AWW day-to-day offline unlock.
- **Role assignment:** on first sign-up a user requests a role; Admin (or an invite link) approves and
  binds them to a centre/sector/child as appropriate. No self-granted Admin.
- **Session:** short-lived access token + refresh, stored in secure storage; AWW keeps an offline
  session gated by PIN after first online provisioning.
- **Backend contract:** define the identity API (`/v1/auth/*`: OAuth exchange, profile, role, refresh).
  With no server yet, ship a **mock auth** for development behind the same interface (mirrors the
  `SyncApi` pattern), so screens and guards can be built and tested now.

**Offline note:** AWWs must work offline; OAuth is for initial provisioning and the online roles. Once
provisioned, the field flow never blocks on the network (`CON-7`).

**Privacy note:** OAuth tokens and PII handled per the consent model; a parent account is linked to a
child only via a verified invite, never by self-claim.

**DoD:** each role can sign in (mock backend), lands on their dashboard, and cannot reach another
role's data; AWW can still unlock offline with a PIN; tokens in secure storage; auth guard unit-tested.

---

## Phase EX3 — Role Dashboards

**Goal:** each role opens to what they need first.

- **AWW** — today's list, screened / flagged / overdue tiles, big "New measurement", sync backlog.
  (Essentially today's Home, rebranded.)
- **Supervisor** — sector rollup: children screened this month across centres, SAM/MAM counts,
  overdue centres, referral follow-up status, per-AWW activity, and CSV export.
- **Doctor** — inbox of referred cases (SAM/MAM), each with the child's growth curve, measurement
  detail, and a control to record the referral outcome; filter by severity.
- **Parent** — their child front and centre: latest growth card, the growth curve, next-visit
  reminder, and a plain-language status ("growing well" / "please visit the ANM"). Minimal, reassuring.
- **Admin** — users & role approvals, centres & sectors, reference-data / config, analytics
  (coverage, SAM/MAM trends), and an audit view.

Each dashboard is a composition of existing data (roster, measurements, referrals, outbox) filtered by
the role's scope — most of the data layer already exists.

**DoD:** every role has a distinct dashboard reading only its permitted data; deep-links respect
permissions; empty and loading states are localised.

---

## Phase EX4 — Role-Aware Navigation & Permissions

**Goal:** one app, five shapes.

- Adaptive shell: the bottom-nav / rail changes per role (AWW: Home/Children/Measure/Settings;
  Supervisor: Overview/Centres/Referrals/Export; Doctor: Cases/Search/Settings; Parent: Child/Card;
  Admin: Users/Centres/Analytics/Config).
- Route guards: every screen checks the role + scope; a denied route explains, never leaks data.
- Account switch / sign-out; multi-child support for parents.

**DoD:** navigation and guards are role-driven from one source; guard logic unit-tested; no route
exposes out-of-scope data.

---

## Phase EX5 — Polish & Motion

**Goal:** it feels finished.

- Micro-interactions (tile press, chart reveal, save confirmation), consistent 150–200 ms transitions,
  reduce-motion honoured.
- Accessibility pass across all roles (contrast, targets, screen-reader labels, greyscale check).
- Dark-theme finalisation; empty/error states in Hindi everywhere.

**DoD:** motion is consistent and optional; accessibility checks pass in light and dark for all roles.

---

## How this maps to the functional roadmap

| Ankur phase | Builds on |
|---|---|
| EX0 Brand/theme | P0 theme + l10n |
| EX1 Landing/onboarding | P1 language switch |
| EX2 Auth/identity | P4 PIN + secure storage; new identity backend |
| EX3 Dashboards | P1 roster, P2/P3 measurements & history, P4 sync/export |
| EX4 Nav/permissions | the app shell |
| EX5 Polish/motion | P6 polish (shared) |

## Open decisions (need a call before building)

1. **Auth provider:** Google OAuth only, or also email/password + phone OTP (rural parents may lack
   Google accounts)?
2. **Backend owner:** is the identity service part of the existing server track, or new?
3. **Parent onboarding:** how is a parent verified and linked to a child (AWW-issued invite code?).
4. **Admin scope:** analytics depth for v1 (counts + trends) vs later (per-child drill-down).
5. **Offline for non-AWW roles:** read-only cache, or online-only?
