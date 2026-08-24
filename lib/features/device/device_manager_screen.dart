// Device Manager Screen for ESP32-S3 Smart Anthropometry Scale.
//
// Enables Anganwadi supervisors and workers to inspect device metadata,
// rename the scale, view real-time live sensor telemetry, calibrate weight
// and height sensors (with Back & Revert to Factory options), and flash firmware over BLE OTA.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'package:cgms_app/core/ble/ble_ota_client.dart';
import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/ble/packet_codec.dart';
import 'package:cgms_app/core/ble/scale_pairing_controller.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/shared/theme/design_tokens.dart';

class DeviceManagerScreen extends ConsumerStatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  ConsumerState<DeviceManagerScreen> createState() =>
      _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends ConsumerState<DeviceManagerScreen> {
  BluetoothDevice? _connectedDevice;
  DeviceMetadata? _metadata;

  // Real-time live telemetry stream from ESP32
  double? _liveWeightKg;
  bool _isWeightStable = false;
  double? _liveHeightCm;
  bool _isHeightStable = false;
  StreamSubscription<List<int>>? _measureSub;

  // Calibration state
  int _weightStep = 1;
  final TextEditingController _weightCalCtrl =
      TextEditingController(text: '5.00');
  int _lengthStep = 1;
  final TextEditingController _lengthCalCtrl =
      TextEditingController(text: '50.0');

  // OTA state
  Uint8List? _firmwareBytes;
  String? _firmwareFileName;
  bool _isFlashing = false;
  double _flashProgress = 0.0;
  double _flashSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _connectToScale();
  }

  @override
  void dispose() {
    _measureSub?.cancel();
    _weightCalCtrl.dispose();
    _lengthCalCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectToScale() async {
    try {
      final pairedInfo = ref.read(scalePairingProvider);
      final pairedId = pairedInfo.id;

      BluetoothDevice? device;

      // 1. Instant check: Is the scale already connected?
      final alreadyConnected = FlutterBluePlus.connectedDevices.where(
        (d) =>
            d.platformName.startsWith('CGMS') ||
            (pairedId != null && d.remoteId.str == pairedId),
      );
      if (alreadyConnected.isNotEmpty) {
        device = alreadyConnected.first;
      } else if (pairedId != null && pairedId.isNotEmpty) {
        // 2. Direct instant connect using paired MAC ID without scanning
        device = BluetoothDevice.fromId(pairedId);
        await device.connect(timeout: const Duration(seconds: 3));
      } else {
        // 3. Fast scan with short 3-second timeout
        await FlutterBluePlus.startScan(
          withServices: [BleOtaClient.serviceUuid],
          timeout: const Duration(seconds: 3),
        );
        final match = await FlutterBluePlus.scanResults
            .expand((r) => r)
            .firstWhere((r) => r.device.platformName.startsWith('CGMS'))
            .timeout(const Duration(seconds: 3));
        await FlutterBluePlus.stopScan();
        device = match.device;
        await device.connect(timeout: const Duration(seconds: 3));
      }

      _connectedDevice = device;

      // 4. Fetch DIS metadata & configure live stream
      final meta = await BleOtaClient.fetchDeviceInfo(device);

      final services = await device.discoverServices();
      final primaryService = services.firstWhere(
        (s) => s.uuid == BleOtaClient.serviceUuid,
      );
      final measureChar = primaryService.characteristics.firstWhere(
        (c) => c.uuid == BleOtaClient.measureCharUuid,
      );

      await _measureSub?.cancel();
      _measureSub = measureChar.lastValueStream.listen((data) {
        if (data.length == 11) {
          try {
            final packet = const PacketCodec().decode(Uint8List.fromList(data));
            if (mounted) {
              setState(() {
                if (packet.channel == DeviceChannel.weight) {
                  _liveWeightKg = packet.reading.valueRaw / 1000.0;
                  _isWeightStable = packet.reading.stable;
                } else {
                  _liveHeightCm = packet.reading.valueRaw / 10.0;
                  _isHeightStable = packet.reading.stable;
                }
              });
            }
          } catch (_) {}
        }
      });
      await measureChar.setNotifyValue(true);

      if (mounted) {
        setState(() {
          _metadata = meta;
        });
      }
    } catch (_) {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> _renameDeviceDialog() async {
    if (_connectedDevice == null) return;
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl =
        TextEditingController(text: _metadata?.name ?? 'CGMS-ANKUR-S3');

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deviceRenameTitle),
        content: TextField(
          controller: nameCtrl,
          maxLength: 24,
          decoration: InputDecoration(
            labelText: l10n.deviceRenameLabel,
            hintText: 'CGMS-ROOM-1', // i18n-ignore: placeholder example
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text(l10n.deviceSave),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await BleOtaClient.renameDevice(_connectedDevice!, newName);
        final deviceId = _connectedDevice!.remoteId.str;
        await ref.read(scalePairingProvider.notifier).pair(deviceId, newName);
        final updatedMeta =
            await BleOtaClient.fetchDeviceInfo(_connectedDevice!);
        setState(() {
          _metadata = updatedMeta;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deviceRenameSuccess)),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$err'), // i18n-ignore: debug error
            ),
          );
        }
      }
    }
  }

  Future<void> _pickFirmwareFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _firmwareBytes = result.files.single.bytes;
          _firmwareFileName = result.files.single.name;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deviceFilePickError)),
        );
      }
    }
  }

  Future<void> _startOtaFlashing() async {
    if (_connectedDevice == null || _firmwareBytes == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isFlashing = true;
      _flashProgress = 0.0;
      _flashSpeed = 0.0;
    });

    try {
      await BleOtaClient.flashFirmware(
        _connectedDevice!,
        _firmwareBytes!,
        onProgress: (pct, speed) {
          setState(() {
            _flashProgress = pct;
            _flashSpeed = speed;
          });
        },
      );

      setState(() {
        _isFlashing = false;
        _firmwareBytes = null;
        _firmwareFileName = null;
      });

      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deviceOtaCompleteTitle),
            content: Text(l10n.deviceOtaCompleteBody),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(l10n.deviceOk),
              ),
            ],
          ),
        );
      }
    } catch (err) {
      setState(() {
        _isFlashing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.deviceOtaFailed}: $err', // i18n-ignore: debug error
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleWeightZero() async {
    if (_connectedDevice == null) return;
    final services = await _connectedDevice!.discoverServices();
    final service =
        services.firstWhere((s) => s.uuid == BleOtaClient.serviceUuid);
    final control = service.characteristics.firstWhere(
      (c) => c.uuid == BleOtaClient.controlCharUuid,
    );
    await control.write([0x01]);
    setState(() => _weightStep = 2);
  }

  Future<void> _handleWeightSave() async {
    if (_connectedDevice == null) return;
    final kg = double.tryParse(_weightCalCtrl.text) ?? 5.0;
    final factor = (kg > 0) ? (420.0 * (kg / 5.0)) : 420.0;
    await BleOtaClient.setWeightCalibration(_connectedDevice!, factor);
    setState(() => _weightStep = 3);
  }

  Future<void> _handleWeightRevert() async {
    if (_connectedDevice == null) return;
    await BleOtaClient.setWeightCalibration(_connectedDevice!, 420.0);
    setState(() => _weightStep = 1);
  }

  Future<void> _handleLengthZero() async {
    if (_connectedDevice == null) return;
    final services = await _connectedDevice!.discoverServices();
    final service =
        services.firstWhere((s) => s.uuid == BleOtaClient.serviceUuid);
    final control = service.characteristics.firstWhere(
      (c) => c.uuid == BleOtaClient.controlCharUuid,
    );
    await control.write([0x01]);
    setState(() => _lengthStep = 2);
  }

  Future<void> _handleLengthSave() async {
    if (_connectedDevice == null) return;
    final cm = double.tryParse(_lengthCalCtrl.text) ?? 50.0;
    final factor = (cm > 0) ? (0.5 * (cm / 50.0)) : 0.5;
    await BleOtaClient.setLengthCalibration(_connectedDevice!, factor);
    setState(() => _lengthStep = 3);
  }

  Future<void> _handleLengthRevert() async {
    if (_connectedDevice == null) return;
    await BleOtaClient.setLengthCalibration(_connectedDevice!, 0.5);
    setState(() => _lengthStep = 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isConnected = _connectedDevice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectToScale,
            tooltip: l10n.bleScalePairAction,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Device Overview Card
          Card(
            elevation: 1,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.allMd,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? theme.colorScheme.primaryContainer
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                          color: isConnected
                              ? theme.colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _metadata?.name ??
                                  _connectedDevice?.platformName ??
                                  l10n.deviceNoDevice,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              isConnected
                                  ? l10n.bleScalePaired(
                                      _connectedDevice?.remoteId.str ?? '')
                                  : l10n.bleScaleNotPaired,
                              style: TextStyle(
                                fontSize: 12,
                                color: isConnected
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isConnected)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 14),
                          label: Text(l10n.deviceRenameBtn),
                          onPressed: _renameDeviceDialog,
                        ),
                    ],
                  ),
                  if (isConnected) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoTile(
                          l10n.deviceFirmware,
                          _metadata?.firmwareVersion ?? 'v1.3.0',
                        ),
                        _infoTile(
                          l10n.deviceHardware,
                          _metadata?.hardwareRevision ?? 'ESP32-S3',
                        ),
                        _infoTile(
                          l10n.deviceUptime,
                          _metadata != null
                              ? '${_metadata!.uptimeSeconds ~/ 60}m'
                              : 'Active',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Sensor Diagnostics & Calibration Cards
          if (isConnected) ...[
            Text(
              l10n.deviceCalibrationTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // ── WEIGHT CALIBRATION CARD ──
            Card(
              elevation: 1,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.scale,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.deviceWeightCalTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Real-Time Weight Gauge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.deviceLiveSensorReading,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _liveWeightKg != null
                                    ? '${_liveWeightKg!.toStringAsFixed(2)} kg'
                                    : '0.00 kg',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isWeightStable
                                  ? Colors.green.shade100
                                  : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isWeightStable
                                        ? Colors.green.shade700
                                        : Colors.amber.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isWeightStable
                                      ? l10n.deviceStableLock
                                      : l10n.deviceLiveStream,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isWeightStable
                                        ? Colors.green.shade900
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Weight Stepper
                    if (_weightStep == 1) ...[
                      Text(
                        l10n.deviceWeightCalStep1,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l10n.deviceZeroScale),
                        onPressed: _handleWeightZero,
                      ),
                    ] else if (_weightStep == 2) ...[
                      Text(
                        l10n.deviceWeightCalStep2,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _weightCalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                suffixText: 'kg',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _handleWeightSave,
                            child: Text(l10n.deviceSaveFactor),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => setState(() => _weightStep = 1),
                            child: Text(l10n.deviceCancelBack),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.deviceCalSaved,
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _weightStep = 1),
                            child: Text(l10n.deviceRecalibrate),
                          ),
                          TextButton(
                            onPressed: _handleWeightRevert,
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700),
                            child: Text(l10n.deviceRevertDefault),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── HEIGHT / STADIOMETER CALIBRATION CARD ──
            Card(
              elevation: 1,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.deviceLengthCalTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Real-Time Height Gauge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.deviceLiveHeightReading,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _liveHeightCm != null
                                    ? '${_liveHeightCm!.toStringAsFixed(1)} cm'
                                    : '0.0 cm',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isHeightStable
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isHeightStable
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isHeightStable
                                      ? l10n.deviceStableLock
                                      : l10n.deviceEncoderOnline,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isHeightStable
                                        ? Colors.green.shade900
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Height Stepper
                    if (_lengthStep == 1) ...[
                      Text(
                        l10n.deviceLengthCalStep1,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l10n.deviceZeroHeight),
                        onPressed: _handleLengthZero,
                      ),
                    ] else if (_lengthStep == 2) ...[
                      Text(
                        l10n.deviceLengthCalStep2,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _lengthCalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                suffixText: 'cm',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _handleLengthSave,
                            child: Text(l10n.deviceSaveFactor),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => setState(() => _lengthStep = 1),
                            child: Text(l10n.deviceCancelBack),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.deviceCalSaved,
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _lengthStep = 1),
                            child: Text(l10n.deviceRecalibrate),
                          ),
                          TextButton(
                            onPressed: _handleLengthRevert,
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700),
                            child: Text(l10n.deviceRevertDefault),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. BLE OTA Firmware Update Card
            Text(
              l10n.deviceOtaSectionTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Card(
              elevation: 1,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.deviceOtaDescription,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    if (_firmwareFileName != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.file_present,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _firmwareFileName!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '${((_firmwareBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_isFlashing) ...[
                      LinearProgressIndicator(
                        value: _flashProgress / 100.0,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_flashProgress.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_flashSpeed.toStringAsFixed(1)} KB/s',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_upload, size: 16),
                            label: Text(l10n.deviceSelectBin),
                            onPressed: _pickFirmwareFile,
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.bolt, size: 16),
                            label: Text(l10n.deviceFlashOta),
                            onPressed: (_firmwareBytes != null)
                                ? _startOtaFlashing
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
