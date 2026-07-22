// BLE device abstraction.
//
// The DeviceClient interface is implemented by both a real flutter_blue_plus
// client (P3) and a MockDeviceClient (P2). The mock is *schedule protection*:
// it is built in P2 and kept working to handover so the team is never blocked
// by a broken load cell.
//
// See docs/PRODUCTION_ROADMAP.md — Phases P2 and P3.

/// A live reading streamed from the device, with a stability hint.
class DeviceReading {
  const DeviceReading({
    required this.valueRaw,
    required this.stable,
    this.sequence,
  });

  final int valueRaw; // grams or millimetres depending on channel
  final bool stable; // UI shows "hold steady" until stable
  final int? sequence; // device_sequence, for de-duplication
}

enum DeviceChannel { weight, length }

/// Abstract client. Real and mock implementations share this surface so the
/// entire capture flow can run on synthetic data without hardware.
abstract class DeviceClient {
  Future<void> connect();
  Future<void> disconnect();

  /// Live values for the given channel. The capture screen subscribes, shows a
  /// stability indicator, and confirms on a stable reading.
  Stream<DeviceReading> readings(DeviceChannel channel);

  /// Serial of the connected device, stored on the measurement row.
  String? get deviceSerial;
}
