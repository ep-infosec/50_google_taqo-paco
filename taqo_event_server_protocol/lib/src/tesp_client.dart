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
import 'dart:collection';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:taqo_common/model/action_specification.dart';
import 'package:taqo_common/model/event.dart';
import 'package:taqo_common/model/experiment.dart';
import 'package:taqo_common/model/notification_holder.dart';
import 'package:taqo_event_server_protocol/src/tesp_codec.dart';

import 'tesp_message.dart';
import 'tesp_message_socket.dart';

final _logger = Logger('TespClient');

class TespClient {
  final serverAddress;
  final int port;

  /// Maximum allowed time between two consecutive chunks belonging to the same response
  final Duration chunkTimeoutMillis;

  /// Timeout for connection to the server
  final Duration connectionTimeoutMillis;

  // Maximum allowed time between
  // (1) sending of one request is finished or previous request get responded, whichever happens later,
  // and
  // (2) a response is being received
  // is (time used for sending the message) * [_responseTimeoutFactor] + [_responseTimeoutLatency]
  // where the coefficients are estimated from some experiments and are enlarged
  // to make the timeout more permissive.
  // The reason for this linear relation is that we expect the time needed by the
  // server to process a request grows linearly with the size of the request.
  static const _responseTimeoutFactor = 20;
  static const _responseTimeoutLatency = Duration(seconds: 2);

  Socket _socket;
  TespMessageSocket<TespResponse, TespRequest> _tespSocket;
  // The response timeout is set based on the time needed for sending the request.
  // To measure the sending time, one need to buffer the requests so that the second request
  // is not added to the socket until sending the first request is finished.
  StreamController<TespRequestWrapper> _sendingBuffer;
  // The client can send the next request before the previous request get responded.
  // The following queue is to store the completers for un-responed requests.
  Queue<TimeoutCompleter<TespResponse>> _tespResponseCompleterQueue;
  final Completer _responseAllCompleter = Completer();
  Timer _responseTimeoutTimer;

  TespClient(this.serverAddress, this.port,
      {this.chunkTimeoutMillis = const Duration(milliseconds: 500),
      this.connectionTimeoutMillis = const Duration(milliseconds: 5000)});

  Future<void> connect() async {
    _socket = await Socket.connect(serverAddress, port,
        timeout: connectionTimeoutMillis);
    _logger.info('Connected to a TespServer at $serverAddress:$port.');
    _tespSocket = TespMessageSocket(_socket,
        timeoutMillis: chunkTimeoutMillis, isAsync: true);
    _sendingBuffer = StreamController();
    _tespResponseCompleterQueue = Queue();
    var stopwatch = Stopwatch();
    StreamSubscription sendingSubscription;
    StreamSubscription receivingSubscription;

    void closeWithError(TespResponseError error) {
      _logger.info('Closing with error: ${error.errorCode} ...');
      _responseTimeoutTimer?.cancel();
      _tespResponseCompleterQueue.forEach((e) => e.completer.complete(error));
      sendingSubscription?.cancel();
      receivingSubscription?.cancel();
      _responseAllCompleter.complete();
      close(force: true);
    }

    sendingSubscription = _sendingBuffer.stream.listen((tespRequestWrapper) {
      sendingSubscription.pause();
      stopwatch.start();
      _tespSocket.add(tespRequestWrapper.tespRequest);
      _socket.flush().then((_) {
        stopwatch.stop();
        tespRequestWrapper.timeoutCompleter.timeout =
            stopwatch.elapsed * _responseTimeoutFactor +
                _responseTimeoutLatency;

        // The timer is started when current sending is finished or previous
        // request get responded (including the case of being the first request),
        // whichever happens later.
        // Below is the case when finishing sending happens later.
        if (_tespResponseCompleterQueue.first ==
            tespRequestWrapper.timeoutCompleter) {
          _responseTimeoutTimer =
              Timer(tespRequestWrapper.timeoutCompleter.timeout, () {
            _logger.warning('Response timeout.');
            closeWithError(TespResponseError(
                TespResponseError.tespClientErrorResponseTimeout));
          });
        }
        sendingSubscription.resume();
      });
    });

    void handleResponse(TespResponse tespResponse) {
      // Unexpected response, i.e. a response without request.
      if (_tespResponseCompleterQueue.isEmpty) {
        _logger.warning(
            'Unexpected response: the client received a response before sending a request.');
        return;
      }

      var timeoutCompleter = _tespResponseCompleterQueue.removeFirst();
      timeoutCompleter.completer.complete(tespResponse);

      // The timer is started when current sending is finished or previous
      // request get responded (including the case of being the first request),
      // whichever happens later.
      // Below is the case when previous request getting responded happens later.
      if (_tespResponseCompleterQueue.isNotEmpty &&
          _tespResponseCompleterQueue.first.timeout != null) {
        _responseTimeoutTimer =
            Timer(_tespResponseCompleterQueue.first.timeout, () {
          _logger.warning('Response timeout.');
          closeWithError(TespResponseError(
              TespResponseError.tespClientErrorResponseTimeout));
        });
      }
    }

    void handleError(e) {
      if (e is TimeoutException) {
        _logger.warning('Timeout waiting for the next chunk of a response.');
        closeWithError(TespResponseError(
            TespResponseError.tespClientErrorChunkTimeout, '$e'));
      } else if (e is TespPayloadDecodingException) {
        _logger.warning('Response payload decoding error.');
        _responseTimeoutTimer?.cancel();
        handleResponse(TespResponseError(
            TespResponseError.tespClientErrorPayloadDecoding, '$e'));
      } else if (e is TespDecodingException || e is TypeError) {
        _logger.warning('Invalid response');
        closeWithError(
            TespResponseError(TespResponseError.tespClientErrorDecoding, '$e'));
      } else {
        _logger.warning('Unknown error');
        closeWithError(
            TespResponseError(TespResponseError.tespClientErrorUnknown, '$e'));
      }
    }

    receivingSubscription = _tespSocket.stream.listen(
        (FutureOr<TespResponse> event) {
          _responseTimeoutTimer?.cancel();
          if (event is Future<TespResponse>) {
            receivingSubscription.pause();
            event.then((tespResponse) {
              handleResponse(tespResponse);
              receivingSubscription.resume();
            }, onError: handleError);
          } else {
            handleResponse(event);
          }
        },
        onError: handleError,
        onDone: () {
          // The server closes early before sending out all the responses
          if (_tespResponseCompleterQueue.isNotEmpty) {
            _logger.warning(
                'The server closed early before sending out all the responses');
            closeWithError(TespResponseError(
                TespResponseError.tespClientErrorServerCloseEarly));
          } else {
            _logger.info('The server closed the connection.');
            _responseAllCompleter.complete();
            close();
          }
        });

    // Handle errors during sending
    unawaited(_tespSocket.done.catchError((e) {
      _logger.warning('Error while sending the requests.');
      closeWithError(
          TespResponseError(TespResponseError.tespClientErrorLostConnection));
    }, test: (e) => e is SocketException));
  }

  Future<TespResponse> send(TespRequest tespRequest) async {
    if (_tespSocket == null) {
      _logger.info(
          'Sending a TESP request while not connected to the event server. Trying to connect...');
      try {
        await connect();
      } catch (e) {
        _logger.warning(
            'Failed to connect to the PAL event server. Is it running?');
        rethrow;
      }
    }

    var completer = Completer<TespResponse>();
    var timeoutCompleter = TimeoutCompleter(completer);
    _tespResponseCompleterQueue.addLast(timeoutCompleter);
    _sendingBuffer.add(TespRequestWrapper(tespRequest, timeoutCompleter));
    return completer.future;
  }

  Future<void> close({bool force = false}) async {
    try {
      if (!force) {
        await _sendingBuffer?.close();
        await _tespSocket?.close();
        await _responseAllCompleter?.future;
      }
    } catch (e) {
      rethrow;
    } finally {
      _tespSocket?.cleanUp();
      _socket?.destroy();
      _tespResponseCompleterQueue?.clear();
      _socket = null;
      _tespSocket = null;
      _tespResponseCompleterQueue = null;
      _sendingBuffer = null;
    }
  }
}

class TimeoutCompleter<T> {
  final Completer<T> completer;
  Duration timeout;

  TimeoutCompleter(this.completer);
}

class TespRequestWrapper {
  final TespRequest tespRequest;
  final TimeoutCompleter<TespResponse> timeoutCompleter;

  TespRequestWrapper(this.tespRequest, this.timeoutCompleter);
}

class TespEventClient extends TespClient {
  TespEventClient(serverAddress, int port,
      {chunkTimeoutMillis = const Duration(milliseconds: 500),
      connectionTimeoutMillis = const Duration(milliseconds: 5000)})
      : super(serverAddress, port,
            chunkTimeoutMillis: chunkTimeoutMillis,
            connectionTimeoutMillis: connectionTimeoutMillis);

  Future<TespResponse> palAddEvents(List<Event> events) =>
      send(TespRequestPalAddEvents(events));

  Future<TespResponse> palAddEventsJson(List eventsJson) =>
      send(TespRequestPalAddEvents.withEventsJson(eventsJson));

  Future<TespResponse> palAddEventJson(eventJson) =>
      palAddEventsJson([eventJson]);

  Future<TespResponse> ping() => send(TespRequestPing());
}

class TespFullClient extends TespEventClient {
  TespFullClient(serverAddress, int port,
      {chunkTimeoutMillis = const Duration(milliseconds: 500),
      connectionTimeoutMillis = const Duration(milliseconds: 5000)})
      : super(serverAddress, port,
            chunkTimeoutMillis: chunkTimeoutMillis,
            connectionTimeoutMillis: connectionTimeoutMillis);

  Future<TespResponse> palPause() => send(TespRequestPalPause());

  Future<TespResponse> palResume() => send(TespRequestPalResume());

  Future<TespResponse> palAllowlistDataOnly() =>
      send(TespRequestPalAllowlistDataOnly());

  Future<TespResponse> palAllData() => send(TespRequestPalAllData());

  Future<TespResponse> alarmSchedule() => send(TespRequestAlarmSchedule());

  Future<TespResponse> alarmAdd(ActionSpecification alarm) =>
      send(TespRequestAlarmAdd(alarm));

  Future<TespResponse> alarmCancel(int alarmId) =>
      send(TespRequestAlarmCancel(alarmId));

  Future<TespResponse> alarmSelectAll() => send(TespRequestAlarmSelectAll());

  Future<TespResponse> alarmSelectById(int alarmId) =>
      send(TespRequestAlarmSelectById(alarmId));

  Future<TespResponse> alarmRemove(int alarmId) =>
      send(TespRequestAlarmRemove(alarmId));

  Future<TespResponse> notificationCheckActive() =>
      send(TespRequestNotificationCheckActive());

  Future<TespResponse> notificationAdd(NotificationHolder notification) =>
      send(TespRequestNotificationAdd(notification));

  Future<TespResponse> notificationCancel(int notificationId) =>
      send(TespRequestNotificationCancel(notificationId));

  Future<TespResponse> notificationCancelByExperiment(int experimentId) =>
      send(TespRequestNotificationCancelByExperiment(experimentId));

  Future<TespResponse> notificationSelectAll() =>
      send(TespRequestNotificationSelectAll());

  Future<TespResponse> notificationSelectById(int notificationId) =>
      send(TespRequestNotificationSelectById(notificationId));

  Future<TespResponse> notificationSelectByExperiment(int experimentId) =>
      send(TespRequestNotificationSelectByExperiment(experimentId));

  Future<TespResponse> notificationRemove(int notificationId) =>
      send(TespRequestNotificationRemove(notificationId));

  Future<TespResponse> notificationRemoveAll() =>
      send(TespRequestNotificationRemoveAll());

  Future<TespResponse> createMissedEvent(Event event) =>
      send(TespRequestCreateMissedEvent(event));

  Future<TespResponse> experimentSaveJoined(List<Experiment> experiments) =>
      send(TespRequestExperimentSaveJoined(experiments));

  Future<TespResponse> experimentSelectJoined() =>
      send(TespRequestExperimentSelectJoined());

  Future<TespResponse> experimentSelectById(int experimentId) =>
      send(TespRequestExperimentSelectById(experimentId));

  Future<TespResponse> experimentGetPausedStatuses(
          List<Experiment> experiments) =>
      send(TespRequestExperimentGetPausedStatuses(experiments));

  Future<TespResponse> experimentSetPausedStatus(
          Experiment experiment, bool paused) =>
      send(TespRequestExperimentSetPausedStatus(experiment, paused));
}
