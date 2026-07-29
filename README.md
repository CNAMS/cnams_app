# Ankur — Child Growth Management System

> **Ankur** (अंकुर, "sprout") — every child, growing well.

Field data-capture application for the **Child Growth Management System (CGMS)** — the Track B mobile
component used by Anganwadi Workers (AWWs) to measure, classify, and track child growth offline.
Ankur is the product name and the planned multi-role experience layer (AWW · Supervisor · Doctor ·
Parent · Admin) on top of this core.

Parent project: https://github.com/PranavShukla2/cgms

<img src="assets/branding/ankur_logo.svg" alt="Ankur logo" width="96" height="96" />

## What this app does

- Registers children and captures informed consent, fully offline.
- Reads weight/length from a BLE measuring device (with manual-entry fallback) and MUAC manually.
- Computes WHO LMS z-scores (WAZ / HAZ / WHZ / MUAC-for-age) **on-device** and classifies growth
  status (normal / MAM / SAM / overweight / indeterminate).
- Presents a colour + Hindi-word result the worker can act on, and advises referral where indicated.
- Shows per-child growth curves and generates a parent growth card (share / print).
- Syncs durably to the server in the background without ever blocking the UI, and exports CSV in
  Poshan Tracker column order.

## Stack

Flutter 3.x · Riverpod · drift (SQLite / SQLCipher) · flutter_blue_plus · fl_chart · workmanager ·
printing · flutter_secure_storage

## Architecture

```
lib/
├── main.dart
├── core/          db · ble · sync · zscore · auth · l10n   (no dependency on features/)
├── features/      roster · measure · history · centre · referral · export
└── shared/        widgets · theme · formatters
```

**Layering rule:** `features/` may depend on `core/`, never the reverse, and nothing in
`core/zscore/` may import Flutter — the engine is pure Dart so it can be tested headlessly and diffed
against the reference implementation.

## Documentation

- [Rough roadmap](02-Mobile-App-Roadmap.md) — original sprint-level plan.
- [Production roadmap](docs/PRODUCTION_ROADMAP.md) — detailed phase-wise production plan (P0–P6).
- [Ankur experience roadmap](docs/ANKUR_EXPERIENCE_ROADMAP.md) — brand, landing, role-based auth +
  Google OAuth, dashboards, theme (EX0–EX5).
- [Leftover / backlog](docs/LEFTOVER.md) — everything still outstanding across all phases.
- [Updates & cross-team handoff](docs/UPDATES.md) — what's done and what the Data,
  IoT/Hardware, Backend and Clinical tracks need to deliver (with the exact code seams).

## Getting started

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter run          # on the target device
```

## Localisation

Hindi is the **primary and default** locale (`hi.arb`); English (`en.arb`) is the fallback. Hardcoded
user-facing strings fail the build (`NFR-16`).

## Status

Early scaffold. See the [production roadmap](docs/PRODUCTION_ROADMAP.md) for phase and gate status.
