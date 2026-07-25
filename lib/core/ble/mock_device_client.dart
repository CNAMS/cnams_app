// MockDeviceClient: synthetic weight/length streams that jitter, then settle.
//
// This is schedule protection, not just a test convenience (roadmap §6): built
// in P2 and kept working to handover so the mobile team is never blocked by a
// broken load cell. The capture flow runs against this exactly as it runs
// against the real device — same DeviceClient interface.
//
// A reading stream emits `stabilizeAfter` unstable readings (value jittering
// around the target) and then stable readings equal to the target, until the
// subscriber stops listening or the client disconnects.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:math';

import 'package:cgms_app/core/ble/device_client.dart';

class MockDeviceClient implements DeviceClient {
  MockDeviceClient({
    Map<DeviceChannel, int>? targets,
    this.serial = 'MOCK-0001',
    this.stabilizeAfter = 5,
    this.noiseAmplitude = 20,
    this.tickInterval = const Duration(milliseconds: 200),
    Random? random,
  })  : _targets = {..._defaults, ...?targets},
        _random = random ?? Random();

  static const Map<DeviceChannel, int> _defaults = {
    DeviceChannel.weight: 9000, // grams
    DeviceChannel.length: 720, // mm
  };

  final Map<DeviceChannel, int> _targets;
  final String serial;

  /// How many jittering readings before the value settles.
  final int stabilizeAfter;

  /// Peak jitter (in the channel's raw units) during the unstable phase.
  final int noiseAmplitude;

  final Duration tickInterval;
  final Random _random;

  bool _connected = false;

  @override
  String? get deviceSerial => _connected ? serial : null;

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  Stream<DeviceReading> readings(DeviceChannel channel) async* {
    if (!_connected) {
      throw StateError('MockDeviceClient.readings called before connect()');
    }
    final target = _targets[channel]!;
    var seq = 0;

    for (var i = 0; i < stabilizeAfter; i++) {
      final jitter = _random.nextInt(2 * noiseAmplitude + 1) - noiseAmplitude;
      yield DeviceReading(
          valueRaw: target + jitter, stable: false, sequence: seq++);
      await Future<void>.delayed(tickInterval);
    }

    while (_connected) {
      yield DeviceReading(valueRaw: target, stable: true, sequence: seq++);
      await Future<void>.delayed(tickInterval);
    }
  }
}
