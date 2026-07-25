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

**Two more principles from review:**
- **Per-role theming.** Ankur has one brand but each role gets a tuned theme (see §2.1) — the AWW's
  outdoor field theme, a clinical theme for the doctor, a light "console" theme for the admin, and so
  on. The classification palette never changes.
- **Never cramp a page.** When a screen has more than it can hold, split it — a "see all" link, a
  sub-page, a tab — rather than shrinking everything. But a page must never look empty either: show a
  meaningful summary and route the depth elsewhere.

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

### 2.1 Per-role themes

One brand, one set of tokens, five tuned skins. Each role's theme changes the **primary/accent and
surface temperature only** — the sprout logo, the type, the spacing, and (critically) the clinical
classification colours stay identical everywhere.

| Role | Primary | Surface mood | Why |
|---|---|---|---|
| **AWW** | Deep teal `#00695C` | Warm sand, high-contrast | The current field theme — outdoor-legible, calm. Keep it. |
| **Supervisor** | Sprout green `#2E7D32` | Warm neutral | Oversight of growth across centres. |
| **Doctor** | Clinical blue `#1565C0` | Clean, cool white | Reads as medical; calm and precise. |
| **Parent** | Warm amber `#E68A00` | Friendly cream | Reassuring and approachable, not clinical. |
| **Admin** | Slate + indigo `#4B5563` / `#5B4B8A` | Light "console" grey (**not** dark) | A developer/dashboard feel — dense, data-first, still light. |

Each role theme has a light and a dark variant. Implementation: a single `AppTheme.forRole(role,
brightness)` that reads shared tokens and swaps the primary/surface set — so a new role is a few
values, not a new theme.

---

## Phase EX0 — Brand & Theme Foundation

**Goal:** the app *looks* like Ankur, in light and dark, with the logo, tokens, and per-role themes.

- Rename product to **Ankur** (`appTitle`, launcher name, README, store metadata); keep the package id.
- Add the logo asset + adaptive launcher icons + splash image.
- Design-token pass: brand colours, typography scale, spacing, elevation, shape — as a single source
  the theme reads. `AppTheme.forRole(role, brightness)` for the five role skins (§2.1), each with a
  light and dark variant; AWW light stays the current theme.
- Keep classification colours and the "colour + word + icon" rule intact.

**DoD:** logo and name everywhere; every role theme passes contrast in light and dark; classification
banner unchanged; existing tests still green.

---

## Phase EX1 — Landing / Splash & Language-first Onboarding

**Goal:** a first impression, then the user picks a language, then signs in — in that language.

**Flow (in order):**
1. **Splash** — the sprout-grow animation over the wordmark, then route on.
2. **Choose language** — a dedicated screen: हिन्दी / English (large, tappable, each shown in its own
   script). This is the first decision, before any account UI. The choice persists (P1 locale store)
   and can be changed later in Settings.
3. **Sign in / Create account** — rendered entirely in the chosen language (§EX2).

- **First-run only:** the language screen shows on first launch (and on demand from Settings);
  returning users go splash → their role's home (or the unlock/sign-in gate).
- Optional 1–2 quiet onboarding slides after language for first-timers (skippable).

**DoD:** cold start shows the animated splash (honours reduce-motion) → the language screen → sign-in
in the chosen language; the choice persists; returning users skip the language screen.

---

## Phase EX2 — Auth & Identity

**Goal:** know who the user is and what role they hold.

- **Sign-in / sign-up — all three methods:**
  - **Google OAuth** ("Continue with Google") — for any role with a Google account.
  - **Phone OTP** — enter a mobile number, receive a 6-digit code (SMS). The primary path for parents
    and many field users who don't use Google.
  - **Email OTP / magic code** — enter an email, receive a code. For office roles.
  - **PIN** — the existing offline unlock for the AWW's day-to-day field use, after first provisioning.
- **Role assignment:** on first sign-up a user requests a role; Admin (or an invite link) approves and
  binds them to a centre/sector/child as appropriate. No self-granted Admin.
- **Session:** short-lived access token + refresh, stored in secure storage; AWW keeps an offline
  session gated by PIN after first online provisioning.
- **Backend contract (placeholder for now):** define the identity API — `/v1/auth/oauth/google`,
  `/v1/auth/otp/request`, `/v1/auth/otp/verify`, `/v1/auth/profile`, `/v1/auth/refresh`. **The server
  is not built yet**, so ship an `AuthApi` interface with a **mock/in-memory implementation** for
  development (same pattern as `SyncApi`) — real OTP delivery and OAuth exchange are wired when the
  backend exists. Screens, role guards and session handling are all built and tested against the mock.

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
- **Admin** — users & role approvals, centres & sectors, reference-data / config, **two** analytics
  surfaces, and an audit view:
  - **Program analytics** — coverage, SAM/MAM trends (child-health outcomes).
  - **App analytics** — *system health, not children*: adoption / active users by role, sync health
    (backlog, dead-letters, success rate), crash-free rate, API latency & error rate, app-version
    spread, offline-vs-online usage. This is the operations view for the project team.

Because the Admin surface holds a lot, it follows the **never-cramp** rule: the dashboard shows summary
cards, and each (Users, Centres, Program analytics, App analytics, Config, Audit) opens its own page —
no single scroll tries to hold everything.

Each dashboard is a composition of existing data (roster, measurements, referrals, outbox) filtered by
the role's scope — most of the program data already exists; app-analytics needs the telemetry from P6
(crash reporting) plus the sync counts already in the outbox.

**DoD:** every role has a distinct dashboard reading only its permitted data; Admin's program vs app
analytics are separate pages; long surfaces split into sub-pages rather than cramming; deep-links
respect permissions; empty and loading states are localised.

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

## Decisions taken (from review)

- **Auth:** support **all** of Google OAuth, phone OTP, and email OTP (plus the AWW PIN). ✔
- **Backend:** not built yet — build against a **mock `AuthApi`** now; wire the real server later. ✔
- **Per-role themes:** yes — AWW keeps the current theme; Admin is a light "console"; each role tuned
  (§2.1). ✔
- **Flow:** landing/splash → **choose language** → sign-in in that language. ✔
- **Admin analytics:** two surfaces — program health *and* app/system performance. ✔
- **Layout:** never cramp; split long pages into sub-pages, but keep pages meaningful. ✔

## Still open

1. **Parent onboarding:** how is a parent verified and linked to a child (AWW-issued invite code?).
2. **Program-analytics depth for v1:** counts + trends vs per-child drill-down.
3. **Offline for non-AWW roles:** read-only cache, or online-only?
4. **Backend ownership/timeline:** who builds the identity + telemetry services, and when.
