// Single source of truth for the app's identity constants.
//
// Keep [appVersion] in step with pubspec.yaml's `version:` — it's stamped onto
// every saved measurement and shown on the About screen. (We avoid a native
// package_info plugin so the app stays lean and fully offline.)

/// Marketing/semver version, matching pubspec.yaml (without the build number).
const String appVersion = '0.1.0';
