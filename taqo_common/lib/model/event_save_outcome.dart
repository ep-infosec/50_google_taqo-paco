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

import 'package:json_annotation/json_annotation.dart';

part 'event_save_outcome.g.dart';

@JsonSerializable()
class EventSaveOutcome {
  int eventId;
  bool status;
  String errorMessage;

  EventSaveOutcome();

  factory EventSaveOutcome.fromJson(Map<String, dynamic> json) =>
      _$EventSaveOutcomeFromJson(json);

  Map<String, dynamic> toJson() => _$EventSaveOutcomeToJson(this);
}
