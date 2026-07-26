# Release build & configuration notes (Ankur mobile app)

The codeable half of Production **P6**: how to produce a release build, what
still needs real credentials, and the pre-release checks. The field half (the
2-week zero-crash window, the signed store submission, crash telemetry) needs a
backend and a device fleet — tracked in [UPDATES.md](UPDATES.md).

---

## 1. Versioning

One version lives in two places — keep them in step:

- `pubspec.yaml` → `version: 0.1.0+1` (`<semver>+<build>`).
- `lib/core/app_info.dart` → `appVersion = '0.1.0'` (shown on the About screen
  and stamped onto every saved measurement).

Bump the build number (`+N`) on every store upload; bump the semver on a
user-visible change. A future step can generate `app_info.dart` from pubspec so
they can't drift.

## 2. Android release APK / App Bundle

```bash
flutter build apk --release          # a single APK, easy to sideload for pilots
flutter build appbundle --release    # .aab for the Play Store
```

**Signing (placeholder — needs the real keystore).** Create
`android/key.properties` (git-ignored) and wire it in `android/app/build.gradle`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Generate the upload keystore once:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Until the keystore exists the release build is **debug-signed** — fine for
internal pilots, not for the Play Store.

## 3. iOS release

```bash
flutter build ipa --release
```

Needs an Apple Developer team, a bundle id, and a provisioning profile set in
Xcode (Runner → Signing & Capabilities). Not required for the Android-first
pilot.

## 4. Data-at-rest encryption

The DB layer ships with the SQLCipher dependency and an encryption seam, but the
key is a placeholder. Before a real deployment the passphrase must come from the
device keystore (see the `flutter_secure_storage` seam) — documented for the
Backend/Security track in [UPDATES.md](UPDATES.md).

## 5. Endpoints

`AuthApi`, `SyncApi` and `DeviceClient` are mock implementations. A release
build for the field needs the real base URLs and TLS pinning wired at the
provider layer (`lib/core/providers.dart`). No code change beyond swapping the
implementation — the seams are in place.

## 6. Pre-release checklist (run green before any build)

```bash
flutter gen-l10n
dart analyze lib                       # zero issues
dart run tool/check_hardcoded_strings.dart   # NFR-16: no hardcoded UI strings
flutter test                           # full suite green
```

Then a manual smoke pass on a low-end Android device: splash → language →
sign-in → register a child → measure → result → export CSV → toggle airplane
mode and confirm the app still measures and queues.

## 7. Known placeholders that must be real before production

- WHO LMS reference tables (`assets/who_reference/tables.json` ships empty; the
  engine returns *indeterminate* as a fail-safe) — **Data track**.
- Real BLE/GATT device profile + hardware — **IoT track**.
- Sync / identity / telemetry servers — **Backend track**.
- Signing keystore + store listing — **release owner**.

See [UPDATES.md](UPDATES.md) for the exact code seam each one plugs into.
