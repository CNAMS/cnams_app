// Capture session controller.
//
// Holds the values gathered during one measurement — weight, length (with the
// position it was taken in), MUAC, oedema — computes the z-score result through
// the engine, and persists it. The age used is derived once from the child's
// DOB at capture time and then held fixed, matching the stored-age_days rule.
//
// See docs/PRODUCTION_ROADMAP.md — Phase P2.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cgms_app/core/data/measurement_repository.dart';
import 'package:cgms_app/core/db/app_database.dart';
import 'package:cgms_app/core/zscore/anthropometry.dart';
import 'package:cgms_app/core/zscore/reference_tables.dart';
import 'package:cgms_app/core/zscore/zscore_engine.dart';

/// Immutable snapshot of a capture in progress.
class CaptureSession {
  const CaptureSession({
    required this.child,
    required this.ageDays,
    this.weightG,
    this.lengthMm,
    this.recumbent = true,
    this.muacMm,
    this.oedema = false,
    this.result,
  });

  final Child child;
  final int ageDays;
  final int? weightG;
  final int? lengthMm;
  final bool recumbent;
  final int? muacMm;
  final bool oedema;
  final ZScoreResult? result;

  bool get hasWeight => weightG != null;
  bool get hasLength => lengthMm != null;

  CaptureSession copyWith({
    int? weightG,
    int? lengthMm,
    bool? recumbent,
    int? muacMm,
    bool? oedema,
    ZScoreResult? result,
  }) {
    return CaptureSession(
      child: child,
      ageDays: ageDays,
      weightG: weightG ?? this.weightG,
      lengthMm: lengthMm ?? this.lengthMm,
      recumbent: recumbent ?? this.recumbent,
      muacMm: muacMm ?? this.muacMm,
      oedema: oedema ?? this.oedema,
      result: result ?? this.result,
    );
  }
}

class CaptureController extends StateNotifier<CaptureSession> {
  CaptureController({
    required Child child,
    required ZScoreEngine engine,
    required MeasurementRepository repository,
    required this.workerId,
    required this.appVersion,
    this.deviceSerial,
    DateTime Function() now = DateTime.now,
  })  : _engine = engine,
        _repository = repository,
        super(
          CaptureSession(
            child: child,
            ageDays: now().difference(child.dob).inDays,
          ),
        );

  final ZScoreEngine _engine;
  final MeasurementRepository _repository;
  final String workerId;
  final String appVersion;
  final String? deviceSerial;

  /// Whether the child's age calls for a recumbent (lying) length measurement.
  bool get recumbentExpected => isRecumbentExpected(state.ageDays);

  void setWeight(int grams) => state = state.copyWith(weightG: grams);

  void setLength(int mm, {required bool recumbent}) =>
      state = state.copyWith(lengthMm: mm, recumbent: recumbent);

  void setMuac(int mm) => state = state.copyWith(muacMm: mm);

  void setOedema(bool value) => state = state.copyWith(oedema: value);

  /// Run the engine over the gathered values and hold the result on the state.
  ZScoreResult computeResult() {
    final result = _engine.compute(
      ZScoreInput(
        sex: state.child.sex == 'M' ? Sex.male : Sex.female,
        ageDays: state.ageDays,
        weightG: state.weightG,
        lengthMm: state.lengthMm,
        muacMm: state.muacMm,
        recumbent: state.recumbent,
        oedema: state.oedema,
      ),
    );
    state = state.copyWith(result: result);
    return result;
  }

  /// Persist the measurement. Computes the result first if it hasn't been.
  Future<String> save() {
    final result = state.result ?? computeResult();
    return _repository.save(
      childId: state.child.id,
      ageDays: state.ageDays,
      result: result,
      workerId: workerId,
      appVersion: appVersion,
      weightG: state.weightG,
      lengthMm: state.lengthMm,
      muacMm: state.muacMm,
      recumbent: state.recumbent,
      oedema: state.oedema,
      source: deviceSerial != null ? 'device' : 'manual',
      deviceSerial: deviceSerial,
    );
  }
}
