// RelayDeviceClient: connects to the host machine's BLE-to-Emulator relay bridge
// over TCP (10.0.2.2:8765 on Android Emulator, or 127.0.0.1:8765 on desktop).
//
// This streams the REAL physical ESP32-S3 BLE data into the Android Emulator
// seamlessly, bypassing emulator Bluetooth driver limitations.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/packet_codec.dart';

class RelayDeviceClient implements DeviceClient {
  RelayDeviceClient({
    this.host = '10.0.2.2', // Standard Android emulator loopback to host PC
    this.port = 8765,
    this.codec = const PacketCodec(),
  });

  final String host;
  final int port;
  final PacketCodec codec;

  final StreamController<DevicePacket> _packets =
      StreamController<DevicePacket>.broadcast();

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSub;
  final List<int> _buffer = [];
  bool _connected = false;

  @override
  String? get deviceSerial => _connected ? 'RELAY-ESP32-S3' : null;

  @override
  Future<void> connect() async {
    if (_connected) return;

    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _socket = socket;
      _connected = true;

      _socketSub = socket.listen(
        _onBytes,
        onError: (err) {
          disconnect();
        },
        onDone: () {
          disconnect();
        },
      );
    } catch (e) {
      // If 10.0.2.2 fails (e.g. running on Linux Desktop), try 127.0.0.1
      if (host == '10.0.2.2') {
        try {
          final socket = await Socket.connect('127.0.0.1', port,
              timeout: const Duration(seconds: 3));
          _socket = socket;
          _connected = true;
          _socketSub = socket.listen(
            _onBytes,
            onError: (err) => disconnect(),
            onDone: () => disconnect(),
          );
          return;
        } catch (_) {}
      }
      _connected = false;
    }
  }

  void _onBytes(List<int> chunk) {
    _buffer.addAll(chunk);

    // Process all complete 11-byte packets
    while (_buffer.length >= 11) {
      // Align to magic byte 0xA5
      if (_buffer[0] != 0xA5) {
        _buffer.removeAt(0);
        continue;
      }

      final frame = Uint8List.fromList(_buffer.sublist(0, 11));
      _buffer.removeRange(0, 11);

      try {
        final packet = codec.decode(frame);
        _packets.add(packet);
      } on FormatException {
        // Discard malformed packet
      }
    }
  }

  @override
  Stream<DeviceReading> readings(DeviceChannel channel) =>
      _packets.stream.where((p) => p.channel == channel).map((p) => p.reading);

  /// Writes 0x02 over the TCP socket → relay writes to ESP32 control characteristic.
  @override
  Future<void> triggerMeasurement() async {
    _socket?.add([0x02]);
    await _socket?.flush();
  }

  /// Writes 0x01 over the TCP socket → relay tares the load cell and encoder on ESP32.
  @override
  Future<void> tare() async {
    _socket?.add([0x01]);
    await _socket?.flush();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _buffer.clear();
  }
}
