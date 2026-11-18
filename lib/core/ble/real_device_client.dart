// Real BLE device client (flutter_blue_plus) behind the DeviceClient interface.
//
// This implements the same surface as the mock: scan for the device advertising
// the frozen GATT service, connect, subscribe to the measurement characteristic,
// and decode each notification through the packet codec into readings. The
// service/characteristic UUIDs come from the frozen GATT spec and are injected
// so they can be set without touching this code.
//
// NOTE: this cannot be exercised without hardware, so it carries no unit tests;
// the mock client is the schedule protection. It is the default mode on a
// physical phone (see deviceClientProvider).
//
// See docs/PRODUCTION_ROADMAP.md — Phase P3 (FR-APP-3, FR-APP-4).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/packet_codec.dart';

class RealDeviceClient implements DeviceClient {
  RealDeviceClient({
    required this.serviceUuid,
    required this.measurementCharUuid,
    this.controlCharUuid,
    this.targetDeviceId,
    this.deviceNamePrefix = 'CGMS',
    this.codec = const PacketCodec(),
    this.scanTimeout = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 15),
  });

  final Guid serviceUuid;
  final Guid measurementCharUuid;

  /// Optional control characteristic UUID (BEB5483F-...).
  /// When present, triggerMeasurement() and tare() write to it.
  final Guid? controlCharUuid;

  /// Dedicated paired device Remote ID (MAC address / UUID).
  /// When provided, only connects to this specific assigned hardware.
  final String? targetDeviceId;

  final String deviceNamePrefix;
  final PacketCodec codec;
  final Duration scanTimeout;
  final Duration connectTimeout;

  final StreamController<DevicePacket> _packets =
      StreamController<DevicePacket>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  BluetoothDevice? _device;
  String? _serial;
  BluetoothCharacteristic? _controlChar;
  final StreamController<bool> _connection = StreamController<bool>.broadcast();

  /// True while [disconnect] runs, so a deliberate disconnect is not reported
  /// as a lost link.
  bool _closing = false;

  @override
  String? get deviceSerial => _serial;

  @override
  Stream<bool> get connectionChanges => _connection.stream;

  @override
  Future<void> connect() async {
    _closing = false;
    final ScanResult result;
    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: scanTimeout,
      );
      result = await _findScale();
    } finally {
      // Always stop scanning, including when no scale was found: a scan left
      // running drains the battery and blocks the next attempt.
      await FlutterBluePlus.stopScan();
    }

    final device = result.device;
    _device = device;
    try {
      await device.connect(timeout: connectTimeout);
      _serial = device.remoteId.str;

      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == serviceUuid);

      // Subscribe to measurement notifications
      final measureChar = service.characteristics.firstWhere(
        (c) => c.uuid == measurementCharUuid,
      );
      await measureChar.setNotifyValue(true);
      _subs.add(measureChar.onValueReceived.listen(_onBytes));

      // Hold a ref to the control characteristic if the UUID was provided
      final ctlUuid = controlCharUuid;
      if (ctlUuid != null) {
        _controlChar = service.characteristics.firstWhere(
          (c) => c.uuid == ctlUuid,
          orElse: () => throw StateError(
            'Control characteristic $ctlUuid not found on device',
          ),
        );
      }

      // Report a link that drops on its own (scale off, out of range, flat
      // battery). Subscribed only once connected: the stream replays the
      // current state on listen, which is "connected" at this point.
      _subs.add(
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected && !_closing) {
            _connection.add(false);
          }
        }),
      );
    } catch (_) {
      // Don't leave a half-open link holding the scale.
      await disconnect();
      rethrow;
    }
  }

  /// Waits for the paired scale, or failing that the closest scale with the
  /// CGMS name prefix, for at most [scanTimeout].
  ///
  /// The scan-results stream never closes, so `firstWhere(orElse: …)` on it
  /// would wait forever when no scale is in range. This listens explicitly
  /// and gives up after the timeout.
  Future<ScanResult> _findScale() async {
    final pairedId = targetDeviceId;
    final completer = Completer<ScanResult>();
    final sub = FlutterBluePlus.scanResults.listen(
      (results) {
        if (completer.isCompleted) return;
        final ScanResult? match;
        if (pairedId != null && pairedId.isNotEmpty) {
          match = results
              .where((r) => r.device.remoteId.str == pairedId)
              .firstOrNull;
        } else {
          final matching = results
              .where((r) => r.device.platformName.startsWith(deviceNamePrefix))
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
          match = matching.firstOrNull;
        }
        if (match != null) completer.complete(match);
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );
    try {
      return await completer.future.timeout(
        scanTimeout,
        onTimeout: () => throw StateError(
          pairedId != null && pairedId.isNotEmpty
              ? 'Paired scale $pairedId not found nearby.'
              : 'No $deviceNamePrefix scale found nearby.',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  void _onBytes(List<int> bytes) {
    try {
      _packets.add(codec.decode(Uint8List.fromList(bytes)));
    } on FormatException {
      // A corrupt frame is dropped, not surfaced as a reading.
    }
  }

  @override
  Stream<DeviceReading> readings(DeviceChannel channel) =>
      _packets.stream.where((p) => p.channel == channel).map((p) => p.reading);

  /// Writes 0x02 to the control characteristic → triggers one capture cycle
  /// on the ESP32 (jitter → stable lock), same as pressing the BOOT button.
  @override
  Future<void> triggerMeasurement() async {
    await _controlChar?.write([0x02], withoutResponse: false);
  }

  /// Writes 0x01 to the control characteristic → tares the load cell and
  /// resets the encoder to zero on the ESP32.
  @override
  Future<void> tare() async {
    await _controlChar?.write([0x01], withoutResponse: false);
  }

  @override
  Future<void> disconnect() async {
    _closing = true;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _controlChar = null;
    final device = _device;
    _device = null;
    _serial = null;
    try {
      await device?.disconnect();
    } catch (_) {
      // Already gone; nothing left to release.
    }
  }
}
