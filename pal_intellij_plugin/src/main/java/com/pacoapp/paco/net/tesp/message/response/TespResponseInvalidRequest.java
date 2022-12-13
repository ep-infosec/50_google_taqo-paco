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

package com.pacoapp.paco.net.tesp.message.response;

import com.pacoapp.paco.net.tesp.message.TespMessage;

public class TespResponseInvalidRequest extends TespResponseWithStringPayload {
    public static TespResponseInvalidRequest withPayload(String payload) {
        final TespResponseInvalidRequest response = new TespResponseInvalidRequest();
        response.setPayload(payload);
        return response;
    }

    public static TespResponseInvalidRequest withEncodedPayload(byte[] bytes) {
        final TespResponseInvalidRequest response = new TespResponseInvalidRequest();
        response.setPayloadWithEncoded(bytes);
        return response;
    }

    @Override
    public int getCode() {
        return TespMessage.tespCodeResponseInvalidRequest;
    }
}