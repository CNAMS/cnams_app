// The capture flow: weight -> length (with position check) -> MUAC + oedema ->
// result. Drives the (mock) device for live weight/length, takes MUAC by hand,
// runs the engine, shows the result, and saves.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/app_info.dart';
import 'package:cgms_app/core/auth/auth_controller.dart';
import 'package:cgms_app/core/ble/device_client.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/l10n/generated/app_localizations.dart';
import 'package:cgms_app/core/providers.dart';
import 'package:cgms_app/features/measure/capture_controller.dart';
import 'package:cgms_app/features/measure/result_view.dart';

class CaptureFlowScreen extends ConsumerStatefulWidget {
  const CaptureFlowScreen({required this.child, super.key});

  final Child child;

  @override
  ConsumerState<CaptureFlowScreen> createState() => _CaptureFlowScreenState();
}

class _CaptureFlowScreenState extends ConsumerState<CaptureFlowScreen> {
  late final DeviceClient _device;
  CaptureController? _controller;
  int _step = 0;
  late bool _measuredLying;

  @override
  void initState() {
    super.initState();
    _device = ref.read(deviceClientProvider)..connect();
  }

  @override
  void dispose() {
    _device.disconnect();
    _controller?.dispose();
    super.dispose();
  }

  CaptureController _ensureController() {
    final engine = ref.read(zscoreEngineProvider).requireValue;
    // Attribute the measurement to the signed-in user; fall back to a device
    // label if somehow unauthenticated.
    final workerId =
        ref.read(authControllerProvider).valueOrNull?.userId ?? 'local-device';
    return _controller ??= CaptureController(
      child: widget.child,
      engine: engine,
      repository: ref.read(measurementRepositoryProvider),
      workerId: workerId,
      appVersion: appVersion,
      deviceSerial: _device.deviceSerial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final engine = ref.watch(zscoreEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.captureTitle} · ${widget.child.name}', // i18n-ignore: composed
        ),
      ),
      body: engine.when(
        loading: () => _Connecting(message: l10n.captureConnecting),
        error: (e, _) => Center(child: Text('$e')), // i18n-ignore: diagnostic
        data: (_) {
          final controller = _ensureController();
          _measuredLying =
              _step == 0 ? controller.recumbentExpected : _measuredLying;
          return _buildStep(controller, l10n);
        },
      ),
    );
  }

  Widget _buildStep(CaptureController controller, AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _DeviceCaptureStep(
          key: const ValueKey('weight'),
          device: _device,
          channel: DeviceChannel.weight,
          title: l10n.captureStepWeight,
          unit: l10n.unitKg,
          divisor: 1000,
          fractionDigits: 2,
          onConfirm: (raw) {
            controller.setWeight(raw);
            setState(() => _step = 1);
          },
        );
      case 1:
        return _DeviceCaptureStep(
          key: const ValueKey('length'),
          device: _device,
          channel: DeviceChannel.length,
          title: l10n.captureStepLength,
          unit: l10n.unitCm,
          divisor: 10,
          fractionDigits: 1,
          header: _PositionPicker(
            expectedLying: controller.recumbentExpected,
            measuredLying: _measuredLying,
            onChanged: (v) => setState(() => _measuredLying = v),
            l10n: l10n,
          ),
          onConfirm: (raw) {
            controller.setLength(raw, recumbent: _measuredLying);
            setState(() => _step = 2);
          },
        );
      case 2:
        return _MuacStep(
          l10n: l10n,
          onConfirm: (muacMm, oedema) {
            controller
              ..setMuac(muacMm)
              ..setOedema(oedema)
              ..computeResult();
            setState(() => _step = 3);
          },
        );
      default:
        return _ResultStep(controller: controller, l10n: l10n);
    }
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

/// A live device reading step: shows the streamed value and a stability
/// indicator, and enables Confirm only once the reading is stable.
class _DeviceCaptureStep extends StatefulWidget {
  const _DeviceCaptureStep({
    required this.device,
    required this.channel,
    required this.title,
    required this.unit,
    required this.divisor,
    required this.fractionDigits,
    required this.onConfirm,
    this.header,
    super.key,
  });

  final DeviceClient device;
  final DeviceChannel channel;
  final String title;
  final String unit;
  final double divisor;
  final int fractionDigits;
  final ValueChanged<int> onConfirm;
  final Widget? header;

  @override
  State<_DeviceCaptureStep> createState() => _DeviceCaptureStepState();
}

class _DeviceCaptureStepState extends State<_DeviceCaptureStep> {
  StreamSubscription<DeviceReading>? _sub;
  DeviceReading? _reading;

  @override
  void initState() {
    super.initState();
    _sub = widget.device
        .readings(widget.channel)
        .listen((r) => setState(() => _reading = r));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reading = _reading;
    final stable = reading?.stable ?? false;
    final display = reading == null
        ? '—'
        : (reading.valueRaw / widget.divisor).toStringAsFixed(
            widget.fractionDigits,
          );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.header != null) ...[
            const SizedBox(height: 16),
            widget.header!,
          ],
          const Spacer(),
          Center(
            child: Text(
              '$display ${widget.unit}', // i18n-ignore: numeric value + unit
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Chip(
              avatar: Icon(
                stable ? Icons.check_circle : Icons.sync,
                color: stable ? const Color(0xFF2E7D32) : null,
              ),
              label: Text(stable ? l10n.stabilityStable : l10n.stabilityHold),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed:
                stable ? () => widget.onConfirm(reading!.valueRaw) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _PositionPicker extends StatelessWidget {
  const _PositionPicker({
    required this.expectedLying,
    required this.measuredLying,
    required this.onChanged,
    required this.l10n,
  });

  final bool expectedLying;
  final bool measuredLying;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expectedLying
                    ? l10n.positionExpectedLying
                    : l10n.positionExpectedStanding,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.measuredPosition),
        const SizedBox(height: 4),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.positionLying)),
            ButtonSegment(value: false, label: Text(l10n.positionStanding)),
          ],
          selected: {measuredLying},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _MuacStep extends StatefulWidget {
  const _MuacStep({required this.l10n, required this.onConfirm});

  final AppLocalizations l10n;
  final void Function(int muacMm, bool oedema) onConfirm;

  @override
  State<_MuacStep> createState() => _MuacStepState();
}

class _MuacStepState extends State<_MuacStep> {
  final _muac = TextEditingController();
  bool _oedema = false;

  @override
  void dispose() {
    _muac.dispose();
    super.dispose();
  }

  int? get _muacMm {
    final cm = double.tryParse(_muac.text.trim());
    return cm == null ? null : (cm * 10).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final canConfirm = _muacMm != null || _oedema;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.captureStepMuac,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _muac,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.muacLabel,
              suffixText: l10n.unitCm,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _oedema,
            onChanged: (v) => setState(() => _oedema = v),
            title: Text(l10n.oedemaLabel),
            subtitle: Text(l10n.oedemaHelp),
          ),
          const Spacer(),
          FilledButton(
            onPressed: canConfirm
                ? () => widget.onConfirm(_muacMm ?? 0, _oedema)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  const _ResultStep({required this.controller, required this.l10n});

  final CaptureController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final result = controller.session.result!;
    return ResultView(
      classification: result.classification,
      waz: result.waz,
      haz: result.haz,
      whz: result.whz,
      footer: FilledButton(
        onPressed: () async {
          await controller.save();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.measurementSaved)),
          );
          Navigator.of(context).pop();
        },
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
        ),
        child: Text(l10n.saveMeasurement),
      ),
    );
  }
}
