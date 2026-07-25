// Real BLE device client (flutter_blue_plus) behind the DeviceClient interface.
//
// This implements the same surface as the mock: scan for the device advertising
// the frozen GATT service, connect, subscribe to the measurement characteristic,
// and decode each notification through the packet codec into readings. The
// service/characteristic UUIDs come from the frozen GATT spec and are injected
// so they can be set without touching this code.
//
// NOTE: this cannot be exercised without hardware, so it carries no unit tests;
// the mock client is the schedule protection and remains the default. Wire this
// in (deviceClientProvider) once a bench unit is available — Phase P3.
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
    this.deviceNamePrefix = 'CGMS',
    this.codec = const PacketCodec(),
    this.scanTimeout = const Duration(seconds: 15),
  });

  final Guid serviceUuid;
  final Guid measurementCharUuid;
  final String deviceNamePrefix;
  final PacketCodec codec;
  final Duration scanTimeout;

  final StreamController<DevicePacket> _packets =
      StreamController<DevicePacket>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  BluetoothDevice? _device;
  String? _serial;

  @override
  String? get deviceSerial => _serial;

  @override
  Future<void> connect() async {
    await FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: scanTimeout,
    );
    final result = await FlutterBluePlus.scanResults
        .expand((results) => results)
        .firstWhere((r) => r.device.platformName.startsWith(deviceNamePrefix));
    await FlutterBluePlus.stopScan();

    final device = result.device;
    await device.connect();
    _device = device;
    _serial = device.remoteId.str;

    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final characteristic = service.characteristics.firstWhere(
      (c) => c.uuid == measurementCharUuid,
    );

    await characteristic.setNotifyValue(true);
    _subs.add(characteristic.onValueReceived.listen(_onBytes));
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

  @override
  Future<void> disconnect() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _device?.disconnect();
    _device = null;
    _serial = null;
  }
}
