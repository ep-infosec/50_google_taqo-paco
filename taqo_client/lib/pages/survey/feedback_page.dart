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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:taqo_common/model/experiment.dart';
import 'package:taqo_common/model/experiment_group.dart';
import '../../service/alarm/flutter_local_notifications.dart'
    as flutter_local_notifications;
import '../running_experiments_page.dart';

class FeedbackPage extends StatefulWidget {
  static const routeName = 'feedback';

  FeedbackPage({Key key}) : super(key: key);

  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  Experiment _experiment;

  ExperimentGroup _experimentGroup;

  @override
  Widget build(BuildContext context) {
    var list = ModalRoute.of(context).settings.arguments as List;
    _experiment = list.elementAt(0) as Experiment;
    _experimentGroup = list.elementAt(1) as ExperimentGroup;

    return Scaffold(
        appBar: AppBar(
          title: Text(_experimentGroup.name),
          backgroundColor: Colors.indigo,
        ),
        body: Container(
          padding: EdgeInsets.all(8.0),
          //margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              buildFeedbackMessageRow(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.done),
            onPressed: () {
              flutter_local_notifications.launchDetails.then((launchDetails) {
                if (launchDetails.didNotificationLaunchApp) {
                  SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                } else {
                  Navigator.pushNamedAndRemoveUntil(context,
                      RunningExperimentsPage.routeName, (Route route) => false);
                }
              });
            }));
  }

  // TODO determine if it is html feedback and show in an html widget
  Widget buildFeedbackMessageRow() {
    return Row(children: <Widget>[
      Text(
        _experimentGroup.feedback.text,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
  }
}
