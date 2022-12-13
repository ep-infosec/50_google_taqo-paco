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

import 'dart:convert';

import 'package:taqo_common/model/experiment_core.dart';
import 'package:taqo_common/model/experiment.dart';
import 'package:taqo_common/model/visualization.dart';
import "package:test/test.dart";

void main() {
  test("generate json for ExperimentCore", () {
    String jsonString = "{" +
        "\"title\": \"Everything Demo New\"," +
        " \"description\": \"\"," +
        "\"creator\": \"user1@example.com\"," +
        "  \"contactEmail\": \"user1@example.com\"," +
        "  \"id\": 1" +
        "}";

    Map experimentMap = jsonDecode(jsonString);
    var experiment = ExperimentCore.fromJson(experimentMap);
    expect(experiment.title, equals("Everything Demo New"));
  });

  test("generate json for Experiment (subclass of ExperimentCore", () {
    String jsonString = "{" +
        "\"title\": \"Everything Demo New\"," +
        " \"description\": \"\"," +
        "\"creator\": \"user1@example.com\"," +
        "  \"contactEmail\": \"user1@example.com\"," +
        "  \"id\": 1," +
        " \"published\":true " +
        "}";

    Map experimentMap = jsonDecode(jsonString);
    var experiment = Experiment.fromJson(experimentMap);
    expect(experiment.title, equals("Everything Demo New"));
    expect(experiment.published, equals(true));
  });

  test("generate json for List of Experiments", () {
    String jsonString = "[{" +
        "\"title\": \"Everything Demo New\"," +
        " \"description\": \"\"," +
        "\"creator\": \"user1@example.com\"," +
        "  \"contactEmail\": \"user1@example.com\"," +
        "  \"id\": 1," +
        " \"published\":true " +
        "}]";

    List experimentListMap = jsonDecode(jsonString);
    var experiment = Experiment.fromJson(experimentListMap.elementAt(0));
    expect(experiment.title, equals("Everything Demo New"));
    expect(experiment.published, equals(true));
  });

  test("parse json for visualization", () {
    String jsonString = '''
    [
    {
    "id": 897,
    "experimentId": 4608527852634112,
    "title": "Foods Eaten",
    "modifyDate": 1517875586000,
    "question": "Show the distribution of responses for the variable?",
    "yAxisVariables": [
    {
    "id": "New Group:food1",
    "group": "New Group",
    "name": "food1",
    "responseType": "open text"
    }
    ],
    "participants": [
    "rbe10001@gmail.com"
    ],
    "type": "Bubble Chart",
    "startDatetime": 1517788800000,
    "endDatetime": 1517875200000
    }
    ]
    ''';

    List visualizationList = jsonDecode(jsonString);
    var visualization = Visualization.fromJson(visualizationList.elementAt(0));
    expect(visualization.title, equals("Foods Eaten"));
    expect(visualization.modifyDate.dateTime,
        equals(DateTime.fromMillisecondsSinceEpoch(1517875586000)));
    expect(visualization.startDatetime.dateTime,
        equals(DateTime.fromMillisecondsSinceEpoch(1517788800000)));
    expect(visualization.endDatetime.dateTime,
        equals(DateTime.fromMillisecondsSinceEpoch(1517875200000)));
  });
}
