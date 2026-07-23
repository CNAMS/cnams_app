// Device packet framing + CRC.
//
// The real device's GATT frame spec is frozen separately; this is a clean,
// self-consistent framing the real client uses to (de)serialise a reading, with
// a CRC so a corrupted BLE frame is rejected rather than misread as a
// measurement. Pure Dart.
//
// Frame (11 bytes, big-endian):
//   [0]      start marker 0xA5
//   [1]      channel      (0 = weight, 1 = length)
//   [2]      flags        (bit0 = stable)
//   [3..6]   value        int32 (grams or mm)
//   [7..8]   sequence     uint16
//   [9..10]  CRC-16/CCITT over bytes [0..8]
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:typed_data';

import 'package:cgms_app/core/ble/device_client.dart';

/// A decoded frame: which channel it came from and the reading it carried.
class DevicePacket {
  const DevicePacket(this.channel, this.reading);

  final DeviceChannel channel;
  final DeviceReading reading;
}

class PacketCodec {
  const PacketCodec();

  static const int startMarker = 0xA5;
  static const int frameLength = 11;

  Uint8List encode({
    required DeviceChannel channel,
    required DeviceReading reading,
  }) {
    final bytes = Uint8List(frameLength);
    final view = ByteData.view(bytes.buffer);
    view.setUint8(0, startMarker);
    view.setUint8(1, channel.index);
    view.setUint8(2, reading.stable ? 0x01 : 0x00);
    view.setInt32(3, reading.valueRaw);
    view.setUint16(7, reading.sequence ?? 0);
    view.setUint16(9, crc16(bytes.sublist(0, 9)));
    return bytes;
  }

  /// Decode a frame. Throws [FormatException] on a wrong length, bad start
  /// marker, or CRC mismatch — a corrupt frame must never look like a reading.
  DevicePacket decode(Uint8List bytes) {
    if (bytes.length != frameLength) {
      throw const FormatException('bad frame length');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    if (view.getUint8(0) != startMarker) {
      throw const FormatException('bad start marker');
    }
    final expected = crc16(bytes.sublist(0, 9));
    if (view.getUint16(9) != expected) {
      throw const FormatException('CRC mismatch');
    }

    final channel = DeviceChannel.values[view.getUint8(1)];
    final reading = DeviceReading(
      valueRaw: view.getInt32(3),
      stable: (view.getUint8(2) & 0x01) != 0,
      sequence: view.getUint16(7),
    );
    return DevicePacket(channel, reading);
  }
}

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF).
int crc16(List<int> data) {
  var crc = 0xFFFF;
  for (final byte in data) {
    crc ^= (byte & 0xFF) << 8;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc;
}
