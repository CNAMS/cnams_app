# Bug & Security Audit

A pass over the app after the Ankur experience layer landed. Covers the issues
reported from device testing plus others found by review — correctness,
usability, and security. Each is tagged **Fixed** (in this pass) or **Deferred**
(with why / where it's tracked).

Severity: 🔴 high · 🟠 medium · 🟡 low.

---

## Reported from device testing

### 1. 🔴 Can't sign out / return to login — and sign-out left unsafe state — **Fixed**
`AuthController.signOut()` cleared the session but left `sessionUnlockedProvider`
`true` and `currentRoleProvider` stale. Two problems:
- **Usability:** the build on the device predated the Settings sign-out; there
  was no way back to the login screen.
- **Security (🔴):** after a sign-out, signing in as a *different* user whose
  account had a PIN would skip the PIN gate, because "unlocked" was never reset —
  one user could reach another's session without the PIN.

Fix: sign-out now resets `sessionUnlockedProvider = false` and
`currentRoleProvider = aww`, and a **sign-out escape is added to the PIN unlock
screen** so a user is never trapped there.

### 2. 🟠 No email + password sign-in — **Fixed**
Only Google / phone-OTP / email-OTP were offered. Added **email + password**
(sign in / create) to the mock `AuthApi`, with the password hashed (PBKDF2, the
same primitive as the PIN) rather than compared in plaintext, and a screen to
enter it.

### 3. 🟠 DOB calendar hard to use (changing months is painful) — **Fixed**
The registration date picker opened in calendar mode, so reaching a birth month
1–2 years back meant many taps. Now it opens in **input mode** (type the date),
still lets you switch to the calendar, and the valid range is DOB-appropriate
(0–6 years). This also fits rural DOBs, which are often typed/estimated.

---

## Found by review

### 4. 🟠 Home dashboard showed fake numbers — **Partly fixed**
The AWW home tiles (12 / 3 / 5) and the sync badge were hardcoded. The **sync
backlog now shows the real outbox count**; the three stat tiles are relabelled
as illustrative until per-day roster aggregates are wired (small follow-up).

### 5. 🔴 No PIN brute-force protection — **Fixed**
`PinAuth.verify` accepted unlimited attempts, so a 4-digit PIN was trivially
brute-forceable on a stolen device. Added an **attempt counter with a lockout**
(a growing cooldown after repeated failures), stored in secure storage.

### 6. 🟡 CSV export temp file never cleaned up — **Fixed**
`Settings._exportCsv` wrote `cgms_export.csv` to the temp dir and left it. It is
now written per-export and the temp copy is best-effort deleted after sharing.

### 7. 🟡 Captured measurement's `worker_id` was a constant — **Fixed**
Capture stored `worker_id: 'local-worker'`. It now uses the signed-in user's id
from the session, so measurements are attributable.

---

## Deferred (tracked, not fixed here)

- 🟠 **SQLCipher not actually keying the DB** — structural seam only; needs the
  Android open-override + open-after-unlock. Tracked in [LEFTOVER.md](LEFTOVER.md) #8.
- 🟠 **Mock auth trusts the role picked at sign-in** — by design until the real
  identity service enforces role approval (EX2 backend).
- 🟡 **OTP has no expiry / resend / attempt cap** — mock behaviour; real limits
  come with the backend.
- 🟡 **WHO reference tables absent** → z-scores are `indeterminate` (fail-safe);
  Gate G2 data drop-in, LEFTOVER #1.
- 🟡 **Parent–child linking not built** — parent dashboard shows a sample child;
  open decision in the experience roadmap.

---

## Verification

Every fix above ships with a unit or widget test (see `test/`), and the full
suite stays green. Analyze, formatting and the NFR-16 hardcoded-string check all
pass.
