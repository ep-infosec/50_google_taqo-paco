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

package com.pacoapp.paco.shared.model2;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonProperty;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonView;
import org.joda.time.DateTime;

import java.io.Serializable;
import java.util.Arrays;
import java.util.List;


/**
 * Copied From Server code TODO unify code
 */
public class PacoEvent implements Serializable, EventInterface {

  public static final String REFERRED_EXPERIMENT_INPUT_ITEM_KEY = "referred_experiment";

  private Long id;
  private Long experimentId;
  private String who;
  private String lat;
  private String lon;
  private DateTime when;
  private String appId;
  private String pacoVersion;
  private boolean shared;
  private String experimentName;
  @JsonProperty("responses")
  private List<Output> what;

  @JsonSerialize(using=CustomDateTimeSerializer.class)
  private DateTime responseTime;
  @JsonSerialize(using=CustomDateTimeSerializer.class)
  private DateTime scheduledTime;
  private String[] blobs;
  private Integer experimentVersion;
  // timezone will be represented as part of the date time along with date fields
  @JsonView(Views.V4.class)
  private String timezone;

  private String experimentGroupName;
  private Long actionTriggerId;
  private Long actionTriggerSpecId;
  private Long actionId;
  @JsonIgnore
  private boolean joined;
  private DateTime sortDate;
  private boolean uploaded;

  @JsonProperty("responses")
  public List<Output> getWhat() {
    return what;
  }

  @JsonProperty("responses")
  public void setWhat(List<Output> what) {
    this.what = what;
  }

  public PacoEvent() {

  }

  public PacoEvent(String who, DateTime when, String experimentName, String lat, String lon,
                   String appId, String pacoVersion, List<Output> set, boolean shared, DateTime responseTime,
                   DateTime scheduledTime, String[] blobs, Long experimentId, Integer experimentVersion, String timezone,
                   String groupName, Long actionTriggerId, Long actionTriggerSpecId, Long actionId) {
    super();
    this.who = who;
    this.lat = lat;
    this.lon = lon;
    this.when = when;
    this.what = set;
    this.appId = appId;
    this.pacoVersion = pacoVersion;
    this.shared = shared;
    this.experimentId = experimentId;
    this.experimentName = experimentName;
    this.experimentVersion = experimentVersion;
    this.responseTime = responseTime;
    this.scheduledTime = scheduledTime;
    this.blobs = blobs;
    this.timezone = timezone;
    this.experimentGroupName = groupName;
    this.actionTriggerId = actionTriggerId;
    this.actionTriggerSpecId = actionTriggerSpecId;
    this.actionId = actionId;

  }

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getWho() {
    return who;
  }

  public void setWho(String who) {
    this.who = who;
  }

  @JsonIgnore
  public String getLat() {
    return lat;
  }

  @JsonIgnore
  public void setLat(String lat) {
    this.lat = lat;
  }

  @JsonIgnore
  public String getLon() {
    return lon;
  }

  @JsonIgnore
  public void setLon(String lon) {
    this.lon = lon;
  }

  public DateTime getWhen() {
    return when;
  }

  public void setWhen(DateTime when) {
    this.when = when;
  }

  @JsonIgnore
  public String getWhatByKey(String key) {
    for (Output currentWhat : what) {
      if (currentWhat.getName().equals(key)) {
        return currentWhat.getValue();
      }
    }
    return null;
  }

  public String getAppId() {
    return appId;
  }

  public void setAppId(String appId) {
    this.appId = appId;
  }

  public String getPacoVersion() {
    return pacoVersion;
  }

  public void setPaco_version(String pacoVersion) {
    this.pacoVersion = pacoVersion;
  }

  @JsonIgnore
  public boolean isShared() {
    return shared;
  }

  @JsonIgnore
  public void setShared(boolean shared) {
    this.shared = shared;
  }

  public String getExperimentName() {
    return experimentName;
  }

  public void setExperimentName(String experimentName) {
    this.experimentName = experimentName;
  }


  /**
   * @return
   */
  public DateTime getResponseTime() {
    return responseTime;
  }

  public void setResponseTime(DateTime responseTime) {
    this.responseTime = responseTime;
  }


  public DateTime getScheduledTime() {
    return scheduledTime;
  }

  public void setScheduledTime(DateTime scheduledTime) {
    this.scheduledTime = scheduledTime;
  }

  @JsonIgnore
  public boolean isMissedSignal() {
    return scheduledTime != null && responseTime == null;
  }

  /**
   * @return
   */
  @JsonIgnore
  public long responseTime() {
    if (responseTime == null || scheduledTime == null) {
      return 0;
    }
    return responseTime.getMillis() - scheduledTime.getMillis();
  }

  /**
   * @return
   */
  @JsonIgnore
  public boolean isJoinEvent() {
    return getWhatByKey("joined") != null;
  }

  public String[] getBlobs() {
    return blobs;
  }

  public void setBlobs(String[] blobs) {
    this.blobs = blobs;
  }

  @JsonIgnore
  public DateTime getIdFromTimes() {
    if (getScheduledTime() != null) {
      return getScheduledTime();
    } else/* if (getResponseTime() != null) */ {
      return getResponseTime();
    } // one of those two has to exist
  }

  public Long getExperimentId() {
    return experimentId;
  }

  public void setExperimentId(Long id) {
    this.experimentId = id;
  }

  public Integer getExperimentVersion() {
    return experimentVersion;
  }

  public void setExperimentVersion(Integer version) {
    this.experimentVersion = version;
  }

  public String getTimezone() {
    return timezone;
  }

  public void setTimezone(String timezone) {
    this.timezone = timezone;
  }

  @JsonIgnore
  public boolean isEmptyResponse() {
    for (Output currentWhat : what) {
      String key = currentWhat.getName();

      if (key.equals(REFERRED_EXPERIMENT_INPUT_ITEM_KEY)) {
        continue;
      }
      String value = currentWhat.getValue();
      if (value != null && value.length() > 0) {
        return false;
      }
    }
    return true;
  }

  public String getExperimentGroupName() {
    return experimentGroupName;
  }

  public void setExperimentGroupName(String experimentGroupName) {
    this.experimentGroupName = experimentGroupName;
  }

  public Long getActionTriggerId() {
    return actionTriggerId;
  }

  public void setActionTriggerId(Long actionTriggerId) {
    this.actionTriggerId = actionTriggerId;
  }

  public Long getActionTriggerSpecId() {
    return actionTriggerSpecId;
  }

  public void setActionTriggerSpecId(Long actionTriggerSpecId) {
    this.actionTriggerSpecId = actionTriggerSpecId;
  }

  public Long getActionId() {
    return actionId;
  }

  public void setActionId(Long actionId) {
    this.actionId = actionId;
  }

  public boolean isJoined() {
    return joined;
  }

  public void setJoined(boolean joined) {
    this.joined = joined;
  }

  public DateTime getSortDate() {
    return sortDate;
  }

  public void setSortDate(DateTime sortDate) {
    this.sortDate = sortDate;
  }

  @Override
  public String toString() {
    return "PacoEvent [id=" + id + ", experimentId=" + experimentId + ", who=" + who + ", lat=" + lat + ", lon=" + lon
            + ", when=" + when + ", appId=" + appId + ", pacoVersion=" + pacoVersion + ", shared=" + shared
            + ", experimentName=" + experimentName + ", what=" + what + ", responseTime=" + responseTime
            + ", scheduledTime=" + scheduledTime + ", blobs=" + Arrays.toString(blobs) + ", experimentVersion="
            + experimentVersion + ", timezone=" + timezone + ", experimentGroupName=" + experimentGroupName
            + ", actionTriggerId=" + actionTriggerId + ", actionTriggerSpecId=" + actionTriggerSpecId + ", actionId="
            + actionId + ", joined=" + joined + ", sortDate=" + sortDate + "]";
  }


  public void setUploaded(boolean uploaded) {
    this.uploaded = uploaded;
  }
}
