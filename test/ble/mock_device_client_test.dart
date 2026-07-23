// MockDeviceClient tests: connect gate, jitter-then-settle, and the stable
// value equalling the target.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/mock_device_client.dart';

MockDeviceClient _client() => MockDeviceClient(
      targets: const {DeviceChannel.weight: 8500},
      stabilizeAfter: 3,
      noiseAmplitude: 10,
      tickInterval: Duration.zero,
      random: Random(1),
    );

void main() {
  test('reading before connect throws', () {
    expect(
      () => _client().readings(DeviceChannel.weight).first,
      throwsStateError,
    );
  });

  test('deviceSerial is null until connected', () async {
    final client = _client();
    expect(client.deviceSerial, isNull);
    await client.connect();
    expect(client.deviceSerial, 'MOCK-0001');
  });

  test('emits unstable readings, then a stable one at the target', () async {
    final client = _client();
    await client.connect();

    final readings =
        await client.readings(DeviceChannel.weight).take(4).toList();

    // First three jitter and are unstable.
    expect(readings.take(3).every((r) => !r.stable), isTrue);
    for (final r in readings.take(3)) {
      expect((r.valueRaw - 8500).abs(), lessThanOrEqualTo(10));
    }

    // The fourth has settled exactly on the target.
    expect(readings.last.stable, isTrue);
    expect(readings.last.valueRaw, 8500);
  });

  test('sequence numbers increase monotonically', () async {
    final client = _client();
    await client.connect();
    final readings =
        await client.readings(DeviceChannel.weight).take(5).toList();
    final seqs = readings.map((r) => r.sequence).toList();
    expect(seqs, [0, 1, 2, 3, 4]);
  });
}
