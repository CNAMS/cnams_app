import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceMetadata {
  const DeviceMetadata({
    required this.name,
    required this.firmwareVersion,
    required this.hardwareRevision,
    required this.macAddress,
    required this.weightCal,
    required this.lengthCal,
    required this.uptimeSeconds,
  });

  final String name;
  final String firmwareVersion;
  final String hardwareRevision;
  final String macAddress;
  final double weightCal;
  final double lengthCal;
  final int uptimeSeconds;

  factory DeviceMetadata.fromJson(Map<String, dynamic> json) {
    return DeviceMetadata(
      name: json['name'] as String? ?? 'CGMS-ANKUR-S3',
      firmwareVersion: json['fw'] as String? ?? 'v1.3.0',
      hardwareRevision: json['hw'] as String? ?? 'ESP32-S3',
      macAddress: json['mac'] as String? ?? '',
      weightCal: (json['w_cal'] as num?)?.toDouble() ?? 420.0,
      lengthCal: (json['l_cal'] as num?)?.toDouble() ?? 0.5,
      uptimeSeconds: (json['uptime'] as num?)?.toInt() ?? 0,
    );
  }
}

class BleOtaClient {
  static final Guid serviceUuid =
      Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final Guid controlCharUuid =
      Guid('beb5483f-36e1-4688-b7f5-ea07361b26a8');

  static final Guid otaServiceUuid =
      Guid('beb54840-36e1-4688-b7f5-ea07361b26a8');
  static final Guid otaControlCharUuid =
      Guid('beb54841-36e1-4688-b7f5-ea07361b26a8');
  static final Guid otaDataCharUuid =
      Guid('beb54842-36e1-4688-b7f5-ea07361b26a8');

  /// Requests device metadata JSON from ESP32.
  static Future<DeviceMetadata?> fetchDeviceInfo(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == serviceUuid);
      final controlChar = service.characteristics.firstWhere(
        (c) => c.uuid == controlCharUuid,
      );

      final completer = Completer<DeviceMetadata?>();

      final sub = controlChar.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          try {
            final text = utf8.decode(value);
            if (text.startsWith('{') && text.endsWith('}')) {
              final json = jsonDecode(text) as Map<String, dynamic>;
              if (!completer.isCompleted) {
                completer.complete(DeviceMetadata.fromJson(json));
              }
            }
          } catch (_) {}
        }
      });

      await controlChar.setNotifyValue(true);
      await controlChar.write([0x10]);

      final meta = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      await sub.cancel();
      return meta;
    } catch (_) {
      return null;
    }
  }

  /// Renames the scale and stores name to ESP32 Flash memory.
  static Future<void> renameDevice(
      BluetoothDevice device, String newName) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final controlChar = service.characteristics.firstWhere(
      (c) => c.uuid == controlCharUuid,
    );

    final nameBytes = utf8.encode(newName);
    final payload = Uint8List(1 + nameBytes.length);
    payload[0] = 0x11;
    payload.setRange(1, payload.length, nameBytes);
    await controlChar.write(payload);
  }

  /// Writes weight calibration factor to ESP32 Flash.
  static Future<void> setWeightCalibration(
      BluetoothDevice device, double factor) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final controlChar = service.characteristics.firstWhere(
      (c) => c.uuid == controlCharUuid,
    );

    final byteData = ByteData(5);
    byteData.setUint8(0, 0x12);
    byteData.setFloat32(1, factor, Endian.little);
    await controlChar.write(byteData.buffer.asUint8List());
  }

  /// Writes height encoder calibration factor to ESP32 Flash.
  static Future<void> setLengthCalibration(
      BluetoothDevice device, double factor) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final controlChar = service.characteristics.firstWhere(
      (c) => c.uuid == controlCharUuid,
    );

    final byteData = ByteData(5);
    byteData.setUint8(0, 0x13);
    byteData.setFloat32(1, factor, Endian.little);
    await controlChar.write(byteData.buffer.asUint8List());
  }

  /// Restores ESP32 Flash settings to factory defaults.
  static Future<void> factoryReset(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final controlChar = service.characteristics.firstWhere(
      (c) => c.uuid == controlCharUuid,
    );

    await controlChar.write([0x14]);
  }

  /// Flashes binary firmware over Bluetooth Low Energy.
  static Future<void> flashFirmware(
    BluetoothDevice device,
    Uint8List firmwareBytes, {
    required void Function(double progressPct, double speedKb) onProgress,
  }) async {
    final services = await device.discoverServices();
    final otaService = services.firstWhere(
      (s) => s.uuid == otaServiceUuid,
      orElse: () =>
          throw StateError('BLE OTA Service not supported on this scale.'),
    );

    final otaControlChar = otaService.characteristics.firstWhere(
      (c) => c.uuid == otaControlCharUuid,
    );
    final otaDataChar = otaService.characteristics.firstWhere(
      (c) => c.uuid == otaDataCharUuid,
    );

    final totalBytes = firmwareBytes.length;

    // 1. Send OTA Begin command [0x01, 4-byte uint32 size]
    final beginData = ByteData(5);
    beginData.setUint8(0, 0x01);
    beginData.setUint32(1, totalBytes, Endian.little);
    await otaControlChar.write(beginData.buffer.asUint8List());

    // 2. Stream chunks (256 bytes per chunk for BLE MTU compatibility)
    const chunkSize = 256;
    final totalChunks = (totalBytes / chunkSize).ceil();
    final startTime = DateTime.now();

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < totalBytes) ? start + chunkSize : totalBytes;
      final chunk = firmwareBytes.sublist(start, end);

      await otaDataChar.write(chunk, withoutResponse: true);

      final elapsedSec =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final speedKb = elapsedSec > 0 ? (end / 1024.0) / elapsedSec : 0.0;
      final pct = (end / totalBytes) * 100.0;
      onProgress(pct, speedKb);

      // Yield every 4 chunks to let Bluetooth radio buffer drain
      if (i % 4 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    }

    // 3. Send OTA End / Reboot command [0x02]
    await otaControlChar.write([0x02]);
  }
}
