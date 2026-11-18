// Controller for managing dedicated Bluetooth Scale pairing per worker.
// Persists the paired device ID and Name in SharedPreferences so the app
// only ever connects to the assigned scale in multi-worker environments.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cgms_app/core/providers.dart';

const _kPairedScaleIdKey = 'paired_ble_scale_id';
const _kPairedScaleNameKey = 'paired_ble_scale_name';

class PairedScaleInfo {
  const PairedScaleInfo({this.id, this.name});

  final String? id;
  final String? name;

  bool get isPaired => id != null && id!.isNotEmpty;
}

class ScalePairingNotifier extends StateNotifier<PairedScaleInfo> {
  ScalePairingNotifier(this._prefs)
      : super(
          PairedScaleInfo(
            id: _prefs.getString(_kPairedScaleIdKey),
            name: _prefs.getString(_kPairedScaleNameKey),
          ),
        );

  final SharedPreferences _prefs;

  Future<void> pair(String id, String name) async {
    await _prefs.setString(_kPairedScaleIdKey, id);
    await _prefs.setString(_kPairedScaleNameKey, name);
    state = PairedScaleInfo(id: id, name: name);
  }

  Future<void> unpair() async {
    await _prefs.remove(_kPairedScaleIdKey);
    await _prefs.remove(_kPairedScaleNameKey);
    state = const PairedScaleInfo(id: null, name: null);
  }
}

final scalePairingProvider =
    StateNotifierProvider<ScalePairingNotifier, PairedScaleInfo>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ScalePairingNotifier(prefs);
});
