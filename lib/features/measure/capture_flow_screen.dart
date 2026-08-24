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
import 'package:cgms_app/shared/widgets/error_view.dart';

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
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(zscoreEngineProvider),
        ),
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

/// A live device reading step: shows the streamed value with a stability
/// indicator, Take Measurement / Zero buttons, and auto-confirm when stable.
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
  DeviceReading? _lockedReading; // non-zero stable reading, protected from zero-glitch
  bool _autoConfirm = true;      // auto-advance when stable
  bool _triggering = false;
  bool _taring = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.device.readings(widget.channel).listen(_onReading);
  }

  void _onReading(DeviceReading r) {
    setState(() {
      _reading = r;

      // Guard: once we have a non-zero stable lock, don't overwrite with
      // a subsequent zero-stable packet (firmware ADC glitch protection).
      if (r.stable && r.valueRaw > 0) {
        _lockedReading = r;
      } else if (!r.stable) {
        // New measurement cycle started — clear the old lock
        _lockedReading = null;
      }
    });

    // Auto-confirm: if stable and non-zero and toggle is on, advance
    if (_autoConfirm && r.stable && r.valueRaw > 0) {
      widget.onConfirm(r.valueRaw);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _triggerMeasurement() async {
    setState(() => _triggering = true);
    await widget.device.triggerMeasurement();
    if (mounted) setState(() => _triggering = false);
  }

  Future<void> _tare() async {
    setState(() => _taring = true);
    await widget.device.tare();
    if (mounted) setState(() => _taring = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Prefer locked (protected) reading for display; fall back to live reading
    final displayReading = _lockedReading ?? _reading;
    final stable = displayReading?.stable ?? false;
    final hasValue = (displayReading?.valueRaw ?? 0) > 0;

    final display = displayReading == null
        ? '—'
        : (displayReading.valueRaw / widget.divisor)
            .toStringAsFixed(widget.fractionDigits);

    final Color statusColor = stable && hasValue
        ? const Color(0xFF2E7D32)   // green — locked
        : stable
            ? const Color(0xFFF57F17) // amber — stable but zero
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.header != null) ...[
            const SizedBox(height: 16),
            widget.header!,
          ],

          const Spacer(),

          // ── Live value display ──────────────────────────────────────────
          Center(
            child: Text(
              '$display ${widget.unit}', // i18n-ignore: numeric value + unit
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: stable && hasValue ? const Color(0xFF2E7D32) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Stability badge ─────────────────────────────────────────────
          Center(
            child: Chip(
              avatar: Icon(
                stable && hasValue
                    ? Icons.lock
                    : stable
                        ? Icons.sync_problem
                        : Icons.sync,
                size: 18,
                color: statusColor,
              ),
              label: Text(
                stable && hasValue
                    ? l10n.stabilityStable   // "Stable" / locked
                    : l10n.stabilityHold,    // "Hold steady"
                style: TextStyle(color: statusColor),
              ),
              side: BorderSide(color: statusColor.withOpacity(0.4)),
            ),
          ),

          const Spacer(),

          // ── Auto-confirm toggle ─────────────────────────────────────────
          SwitchListTile(
            value: _autoConfirm,
            onChanged: (v) => setState(() => _autoConfirm = v),
            title: const Text('Auto-fill on stable lock'),
            subtitle: const Text('Advances automatically when reading locks'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          // ── Take Measurement + Zero buttons ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _taring ? null : _tare,
                  icon: _taring
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.exposure_zero),
                  label: const Text('Zero'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.tonalIcon(
                  onPressed: _triggering ? null : _triggerMeasurement,
                  icon: _triggering
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Take Measurement'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Use this value / Confirm ────────────────────────────────────
          FilledButton.icon(
            onPressed: hasValue
                ? () => widget.onConfirm(displayReading!.valueRaw)
                : null,
            icon: const Icon(Icons.check),
            label: Text(hasValue
                ? 'Use ${display} ${widget.unit}'   // i18n-ignore: composed
                : l10n.confirm),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
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
