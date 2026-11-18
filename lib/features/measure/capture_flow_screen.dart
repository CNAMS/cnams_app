// The capture flow: weight + length (one page) -> MUAC + oedema -> result.
//
// The scale reports weight and length in the same cycle, so both are read on
// one page: one "Take measurement" fills both boxes. Values can always be
// typed by hand, every box is range-checked, and the phone's back button
// steps back through the flow instead of throwing the visit away.
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

/// Clinical "normal" green: a locked, non-zero reading.
const _lockedColour = Color(0xFF2E7D32);

/// Amber: the scale says stable but reads zero (nothing on it yet).
const _emptyLockColour = Color(0xFFF57F17);

const _motion = Duration(milliseconds: 200);

enum _Link { connecting, connected, failed, lost }

class CaptureFlowScreen extends ConsumerStatefulWidget {
  const CaptureFlowScreen({required this.child, super.key});

  final Child child;

  @override
  ConsumerState<CaptureFlowScreen> createState() => _CaptureFlowScreenState();
}

class _CaptureFlowScreenState extends ConsumerState<CaptureFlowScreen> {
  static const _stepCount = 3;

  late final DeviceClient _device;
  StreamSubscription<bool>? _linkSub;
  CaptureController? _controller;
  int _step = 0;
  _Link _link = _Link.connecting;
  bool? _measuredLying;
  bool _autoFill = true;
  bool _saving = false;

  // Plausible ranges for an under-five. They catch a slipped decimal point
  // (105 kg for 10.5 kg) before it reaches the engine or the server.
  final _weight = _ValueField(divisor: 1000, digits: 2, min: 500, max: 40000);
  final _length = _ValueField(divisor: 10, digits: 1, min: 400, max: 1300);
  final _muac = _ValueField(divisor: 10, digits: 1, min: 70, max: 250);
  bool _oedema = false;

  @override
  void initState() {
    super.initState();
    _device = ref.read(deviceClientProvider);
    _linkSub = _device.connectionChanges.listen((up) {
      if (!up && mounted) setState(() => _link = _Link.lost);
    });
    unawaited(_connect());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    unawaited(_device.disconnect());
    _controller?.dispose();
    _weight.dispose();
    _length.dispose();
    _muac.dispose();
    super.dispose();
  }

  /// Connects to the scale. A failure is shown, never thrown: the worker can
  /// still type every value by hand.
  Future<void> _connect() async {
    setState(() => _link = _Link.connecting);
    try {
      await _device.connect();
      if (mounted) setState(() => _link = _Link.connected);
    } catch (_) {
      if (mounted) setState(() => _link = _Link.failed);
    }
  }

  Future<void> _reconnect() async {
    await _device.disconnect();
    if (mounted) await _connect();
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
    );
  }

  bool get _hasProgress =>
      _step > 0 ||
      !_weight.isEmpty ||
      !_length.isEmpty ||
      !_muac.isEmpty ||
      _oedema;

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  /// Back steps through the flow; on the first page it asks before dropping
  /// values already entered.
  Future<void> _onBack() async {
    if (_step > 0) {
      _goTo(_step - 1);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardCaptureTitle),
        content: Text(l10n.discardCaptureBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepMeasuring),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardCaptureConfirm),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _save(CaptureController controller) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // "device" only when every scale value came from the scale untouched;
    // anything typed by hand makes the row manual.
    controller.deviceSerial =
        _weight.fromDevice && _length.fromDevice ? _device.deviceSerial : null;
    setState(() => _saving = true);
    try {
      await controller.save();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.measurementSaved)));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final engine = ref.watch(zscoreEngineProvider);
    final stepLabels = [
      l10n.captureStepMeasurements,
      l10n.captureStepMuac,
      l10n.captureStepResult,
    ];
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final motion = reduceMotion ? Duration.zero : _motion;

    return PopScope(
      canPop: !_hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${l10n.captureTitle} · ${widget.child.name}', // i18n-ignore: composed
          ),
          bottom: _StepProgress(
            step: _step,
            count: _stepCount,
            label: stepLabels[_step],
            motion: motion,
          ),
        ),
        body: engine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(zscoreEngineProvider),
          ),
          data: (_) {
            final controller = _ensureController();
            _measuredLying ??= controller.recumbentExpected;
            return AnimatedSwitcher(
              duration: motion,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _buildStep(controller, l10n),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep(CaptureController controller, AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _buildMeasureStep(controller, l10n);
      case 1:
        return _buildMuacStep(controller, l10n);
      default:
        final result = controller.session.result!;
        return ResultView(
          classification: result.classification,
          waz: result.waz,
          haz: result.haz,
          whz: result.whz,
          footer: FilledButton.icon(
            onPressed: _saving ? null : () => _save(controller),
            icon: _saving
                ? const _ButtonSpinner()
                : const Icon(Icons.save_outlined),
            label: Text(l10n.saveMeasurement),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        );
    }
  }

  Widget _buildMeasureStep(
    CaptureController controller,
    AppLocalizations l10n,
  ) {
    final live = _link == _Link.connected;
    final canNext = _weight.isValid && _length.isValid;

    return _StepLayout(
      action: FilledButton.icon(
        onPressed: canNext
            ? () {
                controller
                  ..setWeight(_weight.raw!)
                  ..setLength(_length.raw!, recumbent: _measuredLying!);
                _goTo(1);
              }
            : null,
        icon: const Icon(Icons.arrow_forward),
        label: Text(l10n.next),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      ),
      children: [
        _LinkBanner(link: _link, onReconnect: _reconnect, l10n: l10n),
        const SizedBox(height: 16),
        _ReadingCard(
          device: _device,
          channel: DeviceChannel.weight,
          field: _weight,
          title: l10n.captureStepWeight,
          unit: l10n.unitKg,
          icon: Icons.monitor_weight_outlined,
          live: live,
          autoFill: _autoFill,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _ReadingCard(
          device: _device,
          channel: DeviceChannel.length,
          field: _length,
          title: l10n.captureStepLength,
          unit: l10n.unitCm,
          icon: Icons.straighten,
          live: live,
          autoFill: _autoFill,
          onChanged: () => setState(() {}),
          header: _PositionPicker(
            expectedLying: controller.recumbentExpected,
            measuredLying: _measuredLying!,
            onChanged: (v) => setState(() => _measuredLying = v),
            l10n: l10n,
          ),
        ),
        const SizedBox(height: 16),
        _DeviceControls(device: _device, enabled: live, l10n: l10n),
        const SizedBox(height: 4),
        SwitchListTile(
          value: _autoFill,
          onChanged: (v) => setState(() => _autoFill = v),
          title: Text(l10n.autoFillOnLock),
          subtitle: Text(l10n.autoFillOnLockHelp),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildMuacStep(CaptureController controller, AppLocalizations l10n) {
    // MUAC may be left blank only when bilateral oedema already decides the
    // outcome; anything typed must be in range.
    final canNext = _muac.isValid || (_muac.isEmpty && _oedema);

    return _StepLayout(
      action: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _goTo(0),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.back),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: canNext
                  ? () {
                      controller
                        ..setMuac(_muac.isEmpty ? null : _muac.raw)
                        ..setOedema(_oedema)
                        ..computeResult();
                      _goTo(2);
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.seeResult),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
        ],
      ),
      children: [
        _ValueInput(
          field: _muac,
          label: l10n.muacLabel,
          unit: l10n.unitCm,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        Card.outlined(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            value: _oedema,
            onChanged: (v) => setState(() => _oedema = v),
            title: Text(l10n.oedemaLabel),
            subtitle: Text(l10n.oedemaHelp),
          ),
        ),
      ],
    );
  }
}

/// A number typed or filled from the scale, held in raw integer units
/// (grams or millimetres) with a plausibility range.
class _ValueField {
  _ValueField({
    required this.divisor,
    required this.digits,
    required this.min,
    required this.max,
  });

  final double divisor;
  final int digits;
  final int min;
  final int max;
  final TextEditingController controller = TextEditingController();

  /// True while the box holds a value the scale filled and nobody edited.
  bool fromDevice = false;

  bool get isEmpty => controller.text.trim().isEmpty;

  int? get raw {
    final v = double.tryParse(controller.text.trim());
    return v == null ? null : (v * divisor).round();
  }

  bool get isValid {
    final r = raw;
    return r != null && r >= min && r <= max;
  }

  bool get showsError => !isEmpty && !isValid;

  String format(int value) => (value / divisor).toStringAsFixed(digits);

  /// The range in the shortest readable form: 0.5–40, not 0.50–40.00.
  String compact(int value) {
    final s = format(value);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  void fillFromDevice(int value) {
    controller.text = format(value);
    fromDevice = true;
  }

  void dispose() => controller.dispose();
}

/// A scrolling body with the primary action pinned above the keyboard.
class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.children, required this.action});

  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: action,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget implements PreferredSizeWidget {
  const _StepProgress({
    required this.step,
    required this.count,
    required this.label,
    required this.motion,
  });

  final int step;
  final int count;
  final String label;
  final Duration motion;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.captureStepOf(step + 1, count)} · $label', // i18n-ignore: composed
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (step + 1) / count),
            duration: motion,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: value, minHeight: 4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the scale link stands, with a reconnect when it is down.
class _LinkBanner extends StatelessWidget {
  const _LinkBanner({
    required this.link,
    required this.onReconnect,
    required this.l10n,
  });

  final _Link link;
  final VoidCallback onReconnect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Widget lead, String text, Color tone) = switch (link) {
      _Link.connecting => (
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          l10n.captureConnecting,
          scheme.onSurfaceVariant,
        ),
      _Link.connected => (
          const Icon(Icons.bluetooth_connected, size: 20),
          l10n.deviceConnected,
          _lockedColour,
        ),
      _Link.failed => (
          const Icon(Icons.bluetooth_disabled, size: 20),
          l10n.deviceConnectFailed,
          scheme.error,
        ),
      _Link.lost => (
          const Icon(Icons.bluetooth_disabled, size: 20),
          l10n.deviceLinkLost,
          scheme.error,
        ),
    };
    final down = link == _Link.failed || link == _Link.lost;

    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: _motion,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            IconTheme.merge(data: IconThemeData(color: tone), child: lead),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            if (down)
              TextButton(
                  onPressed: onReconnect, child: Text(l10n.deviceReconnect)),
          ],
        ),
      ),
    );
  }
}

/// One scale channel: live value, stability, and the editable box it fills.
class _ReadingCard extends StatefulWidget {
  const _ReadingCard({
    required this.device,
    required this.channel,
    required this.field,
    required this.title,
    required this.unit,
    required this.icon,
    required this.live,
    required this.autoFill,
    required this.onChanged,
    this.header,
  });

  final DeviceClient device;
  final DeviceChannel channel;
  final _ValueField field;
  final String title;
  final String unit;
  final IconData icon;

  /// Whether the scale is connected; readings are only subscribed while it is.
  final bool live;
  final bool autoFill;
  final VoidCallback onChanged;
  final Widget? header;

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  StreamSubscription<DeviceReading>? _sub;
  DeviceReading? _reading;

  /// Last non-zero stable reading, protected from a zero-glitch frame.
  DeviceReading? _locked;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _listen();
  }

  @override
  void didUpdateWidget(_ReadingCard old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live || old.device != widget.device) _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = null;
    if (!widget.live) {
      _reading = null;
      _locked = null;
      return;
    }
    _sub = widget.device.readings(widget.channel).listen(
          _onReading,
          onError: (_) {}, // a dropped link is reported by the link banner
        );
  }

  void _onReading(DeviceReading r) {
    final wasLocked = _locked != null;
    setState(() {
      _reading = r;
      if (r.stable && r.valueRaw > 0) {
        _locked = r;
        // Fill the box — unless the worker is typing in it right now.
        if (widget.autoFill && !_focus.hasFocus) {
          widget.field.fillFromDevice(r.valueRaw);
        }
      } else if (!r.stable) {
        _locked = null; // a new measuring cycle started
      }
    });
    if (!wasLocked && _locked != null) {
      HapticFeedback.selectionClick();
      widget.onChanged();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shown = _locked ?? _reading;
    final stable = shown?.stable ?? false;
    final hasValue = (shown?.valueRaw ?? 0) > 0;
    final locked = stable && hasValue;
    final tone = locked
        ? _lockedColour
        : stable
            ? _emptyLockColour
            : theme.colorScheme.onSurfaceVariant;

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleMedium),
                ),
                if (widget.live && shown != null)
                  Semantics(
                    liveRegion: true,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        locked ? Icons.lock : Icons.sync,
                        size: 16,
                        color: tone,
                      ),
                      label: Text(
                        locked ? l10n.stabilityStable : l10n.stabilityHold,
                        style: TextStyle(color: tone),
                      ),
                      side: BorderSide(color: tone.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
            if (widget.header != null) ...[
              const SizedBox(height: 12),
              widget.header!,
            ],
            if (widget.live) ...[
              const SizedBox(height: 12),
              Center(
                child: AnimatedDefaultTextStyle(
                  duration: _motion,
                  style: theme.textTheme.displaySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: locked ? _lockedColour : theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  child: Text(
                    '${shown == null ? '—' : widget.field.format(shown.valueRaw)} ${widget.unit}', // i18n-ignore: value + unit
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ValueInput(
              field: widget.field,
              label: widget.title,
              unit: widget.unit,
              focusNode: _focus,
              hint: widget.live ? l10n.manualInputHint : null,
              onChanged: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// A numeric box with the unit and a plain-language range error.
class _ValueInput extends StatelessWidget {
  const _ValueInput({
    required this.field,
    required this.label,
    required this.unit,
    required this.onChanged,
    this.focusNode,
    this.hint,
  });

  final _ValueField field;
  final String label;
  final String unit;
  final VoidCallback onChanged;
  final FocusNode? focusNode;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: field.controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) {
        field.fromDevice = false; // the worker changed it by hand
        onChanged();
      },
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.edit_outlined),
        filled: true,
        errorText: field.showsError
            ? l10n.valueOutOfRange(
                field.compact(field.min),
                field.compact(field.max),
                unit,
              )
            : null,
        errorMaxLines: 2,
      ),
    );
  }
}

/// Zero and Take-measurement, shared by both channels: one cycle on the
/// scale reads weight and length together.
class _DeviceControls extends StatefulWidget {
  const _DeviceControls({
    required this.device,
    required this.enabled,
    required this.l10n,
  });

  final DeviceClient device;
  final bool enabled;
  final AppLocalizations l10n;

  @override
  State<_DeviceControls> createState() => _DeviceControlsState();
}

class _DeviceControlsState extends State<_DeviceControls> {
  bool _taring = false;
  bool _triggering = false;

  Future<void> _run(
    Future<void> Function() action,
    void Function(bool) busy,
  ) async {
    setState(() => busy(true));
    try {
      await action();
    } catch (_) {
      // A failed write surfaces through the link banner if the link is gone.
    } finally {
      if (mounted) setState(() => busy(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: !widget.enabled || _taring
                ? null
                : () => _run(widget.device.tare, (v) => _taring = v),
            icon: _taring
                ? const _ButtonSpinner()
                : const Icon(Icons.exposure_zero),
            label: Text(l10n.deviceZero),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.tonalIcon(
            onPressed: !widget.enabled || _triggering
                ? null
                : () => _run(
                      widget.device.triggerMeasurement,
                      (v) => _triggering = v,
                    ),
            icon: _triggering
                ? const _ButtonSpinner()
                : const Icon(Icons.play_arrow),
            label: Text(l10n.deviceTakeMeasurement),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
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
