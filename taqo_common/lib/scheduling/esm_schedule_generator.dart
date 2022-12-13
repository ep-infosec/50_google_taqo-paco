// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// @dart=2.9

import 'dart:async';
import 'dart:math';

import 'package:taqo_common/model/experiment.dart';
import 'package:taqo_common/model/schedule.dart';
import 'package:taqo_common/storage/local_file_storage.dart';
import 'package:taqo_common/storage/esm_signal_storage.dart';
import 'package:taqo_common/util/date_time_util.dart';

class ESMScheduleGenerator {
  static const int _maxRandomAttempts = 1000;

  final DateTime startTime;
  final Experiment experiment;
  final String groupName;
  final int triggerId;
  final Schedule schedule;

  final ILocalFileStorage _storageImpl;
  final Completer _lock;

  ESMScheduleGenerator(this._storageImpl, this.startTime, this.experiment,
      this.groupName, this.triggerId, this.schedule)
      : _lock = Completer() {
    _generate();
  }

  /// Get the next scheduled alarm time
  Future<DateTime> nextScheduleTime() async {
    await _lock.future;
    final periodStart = _getPeriodStart();
    return await _lookupNextESMScheduleTime(periodStart) ??
        _lookupNextESMScheduleTime(_getNextPeriodStart(periodStart));
  }

  /// Get the all scheduled alarm times
  Future<List<DateTime>> allScheduleTimes() async {
    await _lock.future;
    final periodStart = _getPeriodStart();
    final storage = await ESMSignalStorage.get(_storageImpl);
    final signals = await storage.getSignals(
        periodStart, experiment.id, groupName, triggerId, schedule.id);
    if (signals != null) {
      return signals;
    }
    return storage.getSignals(_getNextPeriodStart(periodStart), experiment.id,
        groupName, triggerId, schedule.id);
  }

  /// Generate ESM Schedules for the next two periods
  Future<void> _generate() async {
    final periodStart = _getPeriodStart();
    await _ensureESMScheduleGeneratedForPeriod(periodStart);

    final nextPeriodStart = _getNextPeriodStart(periodStart);
    await _ensureESMScheduleGeneratedForPeriod(nextPeriodStart);

    _lock.complete();
  }

  DateTime _getNextPeriodStart(DateTime prev) {
    if (schedule.esmPeriodInDays == Schedule.ESM_PERIOD_DAY) {
      return _getPeriodStart(prev.add(Duration(days: 1)));
    } else if (schedule.esmPeriodInDays == Schedule.ESM_PERIOD_WEEK) {
      final offset = prev.weekday == DateTime.sunday ? 7 : 7 - prev.weekday;
      return _getPeriodStart(prev.add(Duration(days: offset)));
    } else if (schedule.esmPeriodInDays == Schedule.ESM_PERIOD_MONTH) {
      final offset = getLastDayOfMonth(prev) - prev.day + 1;
      return _getPeriodStart(prev.add(Duration(days: offset)));
    }
    return null;
  }

  /// Gets the first day of the period
  /// If [forDate] is null, returns the period start day for [startTime]
  /// Else returns the period start day for the period containing [forDate]
  DateTime _getPeriodStart([DateTime forDate]) {
    var base = forDate ?? startTime;

    // Find first day of ESM period
    var periodStart = getDateWithoutTime(base);
    if (schedule.esmPeriodInDays == Schedule.ESM_PERIOD_WEEK) {
      // We use Sunday for the first day of the week
      periodStart =
          periodStart.subtract(Duration(days: periodStart.weekday % 7));
    } else if (schedule.esmPeriodInDays == Schedule.ESM_PERIOD_MONTH) {
      periodStart = periodStart.subtract(Duration(days: periodStart.day - 1));
    }

    if (!schedule.esmWeekends) {
      periodStart = skipOverWeekend(periodStart);
    }

    return periodStart;
  }

  /// Retrieve the next scheduled alarm time for [periodStart] from storage
  Future<DateTime> _lookupNextESMScheduleTime(DateTime periodStart) async {
    final storage = await ESMSignalStorage.get(_storageImpl);
    final signals = await storage.getSignals(
        periodStart, experiment.id, groupName, triggerId, schedule.id);

    if (signals.isEmpty) {
      return null;
    }

    signals.sort();
    for (var s in signals) {
      if (s.isAtSameMomentAs(startTime) || s.isAfter(startTime)) {
        return s;
      }
    }

    return null;
  }

  /// Checks if ESM schedule for [periodStart] exists in storage and generates/stores it, if
  /// necessary
  Future<void> _ensureESMScheduleGeneratedForPeriod(
      DateTime periodStart) async {
    if (experiment.isOver(periodStart)) {
      return;
    }

    final storage = await ESMSignalStorage.get(_storageImpl);
    final signals = await storage.getSignals(
        periodStart, experiment.id, groupName, triggerId, schedule.id);

    if (signals.isNotEmpty) {
      // Signals are already generated -> done
      //print('ESM signals already generated for period periodStart');
      return;
    }

    final signalTimes = _generateESMTimesForSchedule(periodStart);
    for (var signal in signalTimes) {
      await storage.storeSignal(periodStart, experiment.id, signal, groupName,
          triggerId, schedule.id);
    }
  }

  List<DateTime> _generateESMTimesForSchedule(DateTime periodStart) {
    final signalTimes = <DateTime>[];
    if (schedule.esmFrequency == null || schedule.esmFrequency == 0) {
      return signalTimes;
    }

    var schedulableDays = 0;
    switch (schedule.esmPeriodInDays) {
      case Schedule.ESM_PERIOD_DAY:
        schedulableDays = 1;
        break;
      case Schedule.ESM_PERIOD_WEEK:
        schedulableDays = 5;
        if (schedule.esmWeekends) {
          schedulableDays += 2;
        }
        break;
      case Schedule.ESM_PERIOD_MONTH:
        var dt = cloneDateTime(periodStart);
        while (dt.month == periodStart.month) {
          if (dt.weekday < DateTime.saturday || schedule.esmWeekends) {
            schedulableDays += 1;
          }
          dt = dt.add(Duration(days: 1));
        }
        break;
    }

    final candidateBaseDt = getDateWithoutTime(periodStart)
        .add(Duration(hours: schedule.esmStartHour ~/ 3600000));

    final minutesPerDay =
        ((schedule.esmEndHour - schedule.esmStartHour) ~/ 1000) ~/ 60;
    final minutesPerPeriod = schedulableDays * minutesPerDay;
    final minutesPerBlock = max(minutesPerPeriod ~/ schedule.esmFrequency, 1);
    final minBuffer = schedule.minimumBuffer;
    final rand = Random();

    for (var signal = 0; signal < schedule.esmFrequency; signal++) {
      var candidateDt;
      bool okToAdd = false;

      for (var i = 0; i < _maxRandomAttempts; i++) {
        candidateDt = cloneDateTime(candidateBaseDt);
        var candidate =
            (signal * minutesPerBlock) + rand.nextInt(minutesPerBlock);
        while (candidate > minutesPerDay) {
          candidateDt = candidateDt.add(Duration(days: 1));
          if (!schedule.esmWeekends) {
            candidateDt = skipOverWeekend(candidateDt);
          }
          candidate -= minutesPerDay;
        }

        candidateDt = candidateDt.add(Duration(minutes: candidate));

        // signalTimes is guaranteed to be sorted ascending
        okToAdd = signalTimes.isEmpty ||
            candidateDt.difference(signalTimes.last).inMinutes > minBuffer;
        if (okToAdd) {
          break;
        }
      }

      if (okToAdd) {
        signalTimes.add(candidateDt);
      }
    }

    return signalTimes;
  }
}
