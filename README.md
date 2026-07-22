# CGMS Mobile App

Field data-capture application for the **Child Growth Management System (CGMS)** — the Track B mobile
component used by Anganwadi Workers (AWWs) to measure, classify, and track child growth offline.

Parent project: https://github.com/PranavShukla2/cgms

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
