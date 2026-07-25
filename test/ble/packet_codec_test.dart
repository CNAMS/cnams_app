// Packet codec + CRC tests: round-trip, corrupted frame rejection, and the
// age-calculation boundary at 24 months (via the anthropometry helper).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/packet_codec.dart';
import 'package:cgms_app/core/zscore/anthropometry.dart';

void main() {
  const codec = PacketCodec();

  test('round-trips a reading through encode/decode', () {
    const reading = DeviceReading(valueRaw: 8543, stable: true, sequence: 42);
    final frame = codec.encode(
      channel: DeviceChannel.weight,
      reading: reading,
    );
    final decoded = codec.decode(frame);

    expect(decoded.channel, DeviceChannel.weight);
    expect(decoded.reading.valueRaw, 8543);
    expect(decoded.reading.stable, isTrue);
    expect(decoded.reading.sequence, 42);
  });

  test('a flipped byte fails the CRC check', () {
    final frame = codec.encode(
      channel: DeviceChannel.length,
      reading: const DeviceReading(valueRaw: 720, stable: false, sequence: 1),
    );
    frame[4] ^= 0xFF; // corrupt a value byte
    expect(() => codec.decode(frame), throwsFormatException);
  });

  test('a bad start marker is rejected', () {
    final frame = codec.encode(
      channel: DeviceChannel.weight,
      reading: const DeviceReading(valueRaw: 9000, stable: true, sequence: 0),
    );
    frame[0] = 0x00;
    expect(() => codec.decode(frame), throwsFormatException);
  });

  test('a wrong-length frame is rejected', () {
    expect(
      () => codec.decode(Uint8List.fromList([0xA5, 0x00])),
      throwsFormatException,
    );
  });

  test('age boundary at 24 months selects the length/height mode', () {
    // 24 months = 731 days: below is recumbent (length), at/above is standing.
    expect(isRecumbentExpected(730), isTrue);
    expect(isRecumbentExpected(731), isFalse);
  });
}
