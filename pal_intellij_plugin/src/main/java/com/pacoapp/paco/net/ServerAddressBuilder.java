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

package com.pacoapp.paco.net;

import javax.net.ssl.HttpsURLConnection;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;

public class ServerAddressBuilder {

  public static String createServerUrl(String serverAddress, String path) {
    if (isLocalDevelopmentServerAddress(serverAddress)) {
      return "http://" + serverAddress + path;
    } else {
      return "https://" + serverAddress + path;
    }
  }

  /**
   * Check whether Paco is connecting to a local development webserver.
   * We include localhost (127.0.0.1) here because a very easy way to get your phone to connect to a
   * testserver running on the machine it's connected to, is by just forwarding its local port to a
   * port on the machine, like this:
   * adb reverse tcp:8080 tcp:8080
   * Then the phone, whatever machine its connected to through adb, can just use 127.0.0.1:8080 as
   * the server address to connect to the host.
   *
   * @param serverAddress The server address as set in Paco's settings
   * @return whether this is a local development address
   */
  public static boolean isLocalDevelopmentServerAddress(String serverAddress) {
    return serverAddress.contains("10.0.2.2") || serverAddress.contains("127.0.0.1");
  }

  public static HttpURLConnection getConnection(URL u) throws IOException {
    if (isLocalDevelopmentServerAddress(u.getHost())) {
      return (HttpURLConnection) u.openConnection();
    }
    return (HttpsURLConnection) u.openConnection();
  }

}
