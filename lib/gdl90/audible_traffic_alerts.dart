import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:avaremp/gdl90/traffic_cache.dart';
import 'package:geolocator/geolocator.dart';
import 'traffic_math.dart';
import 'dart:math';
import 'package:dart_numerics/dart_numerics.dart' as numerics;

enum TrafficIdOption { PHONETIC_ALPHA_ID, FULL_CALLSIGN }
enum DistanceCalloutOption { NONE, ROUNDED, DECIMAL }
enum NumberFormatOption { COLLOQUIAL, INDIVIDUAL_DIGIT }

class AudibleTrafficAlerts {

  static AudibleTrafficAlerts? _instance;

  final AudioCache _audioCache;

  // Audio players for each sound used to compose an alert
  final AudioPlayer _trafficAudio;
  final AudioPlayer _bogeyAudio;
  final AudioPlayer _closingInAudio;
  final AudioPlayer _overAudio;
  final AudioPlayer _lowAudio, _highAudio, _sameAltitudeAudio;
  final AudioPlayer _oClockAudio;
  final List<AudioPlayer> _twentiesToNinetiesAudios;
  final AudioPlayer _hundredAudio, _thousandAudio;
  final AudioPlayer _atAudio;
  final List<AudioPlayer> _alphabetAudios;
  final List<AudioPlayer> _numberAudios;
  final AudioPlayer _secondsAudio;
  final AudioPlayer _milesAudio;
  final AudioPlayer _climbingAudio, _descendingAudio, _levelAudio;
  final AudioPlayer _criticallyCloseChirpAudio;
  final AudioPlayer _withinAudio;
  final AudioPlayer _pointAudio;

  final List<_AlertItem> _alertQueue;
  final Map<String,String> _lastTrafficPositionUpdateTimeMap;
  final Map<String,int> _lastTrafficAlertTimeMap;
  final List<String> _phoneticAlphaIcaoSequenceQueue;

  bool _tempPrefIsAudibleGroundAlertsEnabled = false;
  bool _tempVerticalAttitudeCallout = true;
  DistanceCalloutOption _tempDistanceCalloutOption = DistanceCalloutOption.DECIMAL;
  NumberFormatOption _tempNumberFormatOption = NumberFormatOption.COLLOQUIAL;
  bool _tempPrefTopGunDorkMode = false;
  int _tempPrefAudibleTrafficAlertsMinSpeed = 10;
  int _tempPrefAudibleTrafficAlertsDistanceMinimum = 5;
  double _tempPrefTrafficAlertsHeight = 5000;
  int _tempPrefMaxAlertFrequencySeconds = 15;
  int _tempTimeBetweenAnyAlertMs = 750;

  bool _tempPrefIsAudibleClosingInAlerts = true;
  double _tempClosingAlertAltitude = 1000;
  double _tempClosingTimeThresholdSeconds = 60;
  double _tempClosestApproachThresholdNmi = 1;
  double _tempCriticalClosingAlertRatio = 0.5;

  TrafficIdOption _tempTrafficIdOption = TrafficIdOption.PHONETIC_ALPHA_ID;
  

  bool _isRunning = false;
  bool _isPlaying = false;

  static final double kMpsToKnotsConv = 1.0/0.514444;
  static final double kMetersToFeetCont = 3.28084;


  static Future<AudibleTrafficAlerts?> getAndStartAudibleTrafficAlerts(double playRate) async {
    if (_instance == null) {
      _instance = AudibleTrafficAlerts._privateConstructor();
      await _instance?._loadAudio(playRate);
    }
    _instance?._isRunning = true;
    return _instance;
  }

  static Future<void> stopAudibleTrafficAlerts() async {
    _instance?._isRunning = false;
    await _instance?._destroy();
    _instance = null;
  }

  AudibleTrafficAlerts._privateConstructor()
    : _alertQueue = [], _lastTrafficPositionUpdateTimeMap = {}, _lastTrafficAlertTimeMap = {}, _phoneticAlphaIcaoSequenceQueue = [],
    _audioCache = AudioCache(prefix: "assets/audio/traffic_alerts/"), 
    _trafficAudio = AudioPlayer(), _bogeyAudio = AudioPlayer(), _closingInAudio = AudioPlayer(), _overAudio = AudioPlayer(), 
    _lowAudio = AudioPlayer(), _highAudio = AudioPlayer(), _sameAltitudeAudio = AudioPlayer(), _oClockAudio = AudioPlayer(), 
    _twentiesToNinetiesAudios = [], _hundredAudio = AudioPlayer(), _thousandAudio = AudioPlayer(), _atAudio = AudioPlayer(), 
    _alphabetAudios = [], _numberAudios = [], _secondsAudio = AudioPlayer(), _milesAudio = AudioPlayer(), _climbingAudio = AudioPlayer(), 
    _descendingAudio = AudioPlayer(), _levelAudio = AudioPlayer(), _criticallyCloseChirpAudio = AudioPlayer(), _withinAudio = AudioPlayer(), 
    _pointAudio = AudioPlayer();

  Future<void> _destroy() async {
    await _audioCache.clearAll();
  }

  Future<List<dynamic>> _loadAudio(double playRate) async {
    final singleAudioMap = { 
      _trafficAudio: "tr_traffic.mp3", _bogeyAudio: "tr_bogey.mp3", _closingInAudio: "tr_cl_closingin.mp3", _overAudio: "tr_cl_over.mp3",
      _lowAudio: "tr_low.mp3", _highAudio: "tr_high.mp3", _sameAltitudeAudio: "tr_same_altitude.mp3", _oClockAudio: "tr_oclock.mp3",
      _hundredAudio: "tr_100.mp3", _thousandAudio: "tr_1000.mp3", _atAudio: "tr_at.mp3", _secondsAudio: "tr_seconds.mp3",
      _milesAudio: "tr_miles.mp3", _climbingAudio: "tr_climbing.mp3", _descendingAudio: "tr_descending.mp3", _levelAudio: "tr_level.mp3",
      _criticallyCloseChirpAudio: "tr_cl_chirp.mp3", _withinAudio: "tr_within.mp3", _pointAudio: "tr_point.mp3"
    };
    final listAudioMap = { 
      _twentiesToNinetiesAudios: [ "tr_20.mp3", "tr_30.mp3", "tr_40.mp3", "tr_50.mp3", "tr_60.mp3", "tr_70.mp3", "tr_80.mp3", "tr_90.mp3" ], 
      _alphabetAudios: [ "tr_alpha.mp3", "tr_bravo.mp3", "tr_charlie.mp3", "tr_delta.mp3", "tr_echo.mp3", "tr_foxtrot.mp3", "tr_golf.mp3",
        "tr_hotel.mp3", "tr_india.mp3", "tr_juliet.mp3", "tr_kilo.mp3", "tr_lima.mp3", "tr_mike.mp3", "tr_november.mp3", "tr_oscar.mp3", 
        "tr_papa.mp3", "tr_quebec.mp3", "tr_romeo.mp3", "tr_sierra.mp3", "tr_tango.mp3", "tr_uniform.mp3", "tr_victor.mp3", "tr_whiskey.mp3", 
        "tr_xray.mp3", "tr_yankee.mp3", "tr_zulu.mp3" ],
      _numberAudios: [ "tr_00.mp3", "tr_01.mp3", "tr_02.mp3", "tr_03.mp3", "tr_04.mp3", "tr_05.mp3", "tr_06.mp3", "tr_07.mp3", "tr_08.mp3",
        "tr_09.mp3", "tr_10.mp3", "tr_11.mp3", "tr_12.mp3", "tr_13.mp3", "tr_14.mp3", "tr_15.mp3", "tr_16.mp3", "tr_17.mp3", "tr_18.mp3",
        "tr_19.mp3" ]
    };
    final List<Future> futures = [];
    for (final singleEntry in singleAudioMap.entries) {
      futures.add(_populateAudio(singleEntry.key, singleEntry.value, playRate));
    }
    for (final listEntry in listAudioMap.entries) {
      for (final assetName in listEntry.value) {
        final player = AudioPlayer();
        futures.add(_populateAudio(player, assetName, playRate));
        listEntry.key.add(player);
      }
    }
    return Future.wait(futures);
  }

  Future<List<dynamic>> _populateAudio(AudioPlayer player, String assetSourceName, double playRate) async {
    final List<Future> futures = [];
    futures.add(_audioCache.load(assetSourceName));
    player.audioCache = _audioCache;
    futures.add(player.setSource(AssetSource(assetSourceName)));
    futures.add(player.setPlayerMode(PlayerMode.lowLatency));   
    futures.add(player.setPlaybackRate(playRate));
    return Future.wait(futures); 
  }

  void processTrafficForAudibleAlerts(List<Traffic?> trafficList, Position? ownshipLocation, DateTime? ownshipUpdateTime, double ownVspeed) {
    if (!_isRunning || ownshipLocation == null) {
      return;
    }

    bool hasInserts = false;
    for (final traffic in trafficList) {
      if (traffic == null) {
        continue;
      }
      //TODO: Add ICAO/code setting and check to ensure traffic doesn't match it (e.g., Susan C's ghost ownship alerts: final String ownTailNumber = 
      //TODO: Add airborne flag for traffic message and check this: if (!(traffic.message.isAirborne || _tempPrefIsAudibleGroundAlertsEnabled)) { continue; }
      //TODO: Add low speed filter (for takeoff/landing)
      final double altDiff = ownshipLocation.altitude - traffic.message.altitude;
			final String trafficPositionTimeCalcUpdateValue = "${traffic.message.time.millisecondsSinceEpoch}_${ownshipUpdateTime?.millisecondsSinceEpoch}";
			final String trafficKey = _getTrafficKey(traffic);  
      final String? lastTrafficPositionUpdateValue = _lastTrafficPositionUpdateTimeMap[trafficKey];
      final double curDistance;
      if ((lastTrafficPositionUpdateValue == null || lastTrafficPositionUpdateValue != trafficPositionTimeCalcUpdateValue)
        && altDiff.abs() < _tempPrefTrafficAlertsHeight
        && (curDistance = greatCircleDistanceNmi(ownshipLocation.latitude, ownshipLocation.longitude,
          traffic.message.coordinates.latitude, traffic.message.coordinates.longitude)) < _tempPrefAudibleTrafficAlertsDistanceMinimum
      ) {
        _log("!!!!!!!!!!!!!!!!!!!!!!!!!! putting one in, woot: ${trafficKey} having value ${lastTrafficPositionUpdateValue} vs. calced ${trafficPositionTimeCalcUpdateValue} altdiff=${altDiff} and dist=${curDistance} of time ${traffic.message.time}");
        hasInserts = hasInserts || _upsertTrafficAlertQueue(
          _AlertItem(traffic, ownshipLocation, ownshipLocation.altitude, 
            _tempPrefIsAudibleClosingInAlerts  
              ? _determineClosingEvent(ownshipLocation, traffic, curDistance, ownVspeed)
              : null
            , curDistance)
        );
        _lastTrafficPositionUpdateTimeMap[trafficKey] = trafficPositionTimeCalcUpdateValue;
      } //TODO: ELSE --> REMOVE stuff from queue that is no longer eligible on this iteration
    }  

    if (hasInserts)
      scheduleMicrotask(runAudibleAlertsQueueProcessing);
  }

  bool _upsertTrafficAlertQueue(_AlertItem alert) {
    final int existingIndex = _alertQueue.indexOf(alert);
    if (existingIndex == -1) {
      _log("inserting list: ${alert._traffic?.message.icao} and list currently size: ${_alertQueue.length}");
      _alertQueue.add(alert);
      return true;
    } else {
      _log("UPDATING LIST: ${alert._traffic?.message.icao} and list currently size: ${_alertQueue.length}");
      _alertQueue[existingIndex] = alert;
    }
    return false;
  }

  _ClosingEvent? _determineClosingEvent(Position ownLocation, Traffic traffic, double currentDistance, double ownVspeed)
  {
      final int ownSpeedInKts = (kMpsToKnotsConv * ownLocation.speed).round();
      final double ownAltInFeet = kMetersToFeetCont * ownLocation.altitude;
      final double closingEventTimeSec = (closestApproachTime(
              traffic.message.coordinates.latitude, traffic.message.coordinates.longitude, 
              ownLocation.latitude, ownLocation.longitude, traffic.message.heading, ownLocation.heading, 
              traffic.message.velocity.round(), ownSpeedInKts
      )).abs() * 60.00 * 60.00;
      _log("Closintg seconds is ${closingEventTimeSec}");
      if (closingEventTimeSec < _tempClosingTimeThresholdSeconds) {    // Gate #1: Time threshold met
          final Position myCaLoc = locationAfterTime(ownLocation.latitude, ownLocation.longitude,
                  ownLocation.heading, ownSpeedInKts*1.0, closingEventTimeSec/3600.000, ownAltInFeet, ownVspeed);
          final Position theirCaLoc = locationAfterTime(traffic.message.coordinates.latitude, traffic.message.coordinates.longitude,
            traffic.message.heading, traffic.message.velocity, closingEventTimeSec/3600.000, traffic.message.altitude, 
            traffic.message.verticalSpeed);
          double? caDistance;
          final double altDiff = myCaLoc.altitude - theirCaLoc.altitude;
          _log("Closing altdiff=${altDiff} for ownVspeed=${ownVspeed} and their vspeed=${traffic.message.verticalSpeed}");
          _log("Closing myalt=${ownLocation.altitude}, theiralt=${traffic.message.altitude} and time in hours later is ${closingEventTimeSec/3600.000}");
          // Gate #2: If traffic will be within configured "cylinder" of closing/TCPA alerts, create a closing event
          if (altDiff.abs() < _tempClosingAlertAltitude
                  && (
                    caDistance = greatCircleDistanceNmi(myCaLoc.latitude, myCaLoc.longitude, theirCaLoc.latitude, theirCaLoc.longitude)
                  ) < _tempClosestApproachThresholdNmi
                  && currentDistance > caDistance)    // catches cases when moving away
          {
              final bool criticallyClose = _tempCriticalClosingAlertRatio > 0
                      && (closingEventTimeSec / _tempClosingTimeThresholdSeconds) <= _tempCriticalClosingAlertRatio
                      && (caDistance / _tempClosestApproachThresholdNmi) <= _tempCriticalClosingAlertRatio;
              return _ClosingEvent(closingEventTimeSec, caDistance, criticallyClose);
          } 
          _log("Closing caDistance=${caDistance??-1} and curDistance=$currentDistance");
      }
      return null;
  }  

  void runAudibleAlertsQueueProcessing() {
    if (!_isRunning || _isPlaying || _alertQueue.isEmpty) {
      return;
    }
    final _AlertItem nextAlert = _alertQueue[0];
    int timeToWaitForThisTraffic = 0;
    final String trafficKey = _getTrafficKey(nextAlert._traffic);
    final int? lastTrafficAlertTimeValue = _lastTrafficAlertTimeMap[trafficKey];
    //TODO: Also put minimum separate (timeToWaitForAny) for all alerts
    //TODO: Cede place in line to "next one" if available (e.g., move this one to back and call this again)
    if (lastTrafficAlertTimeValue == null
      || (timeToWaitForThisTraffic = (_tempPrefMaxAlertFrequencySeconds * 1000) - (DateTime.now().millisecondsSinceEpoch - lastTrafficAlertTimeValue)) <= 0
    ) {
      _lastTrafficAlertTimeMap[trafficKey] = DateTime.now().millisecondsSinceEpoch;
      _log("====================================== processing alerts ${trafficKey} of list size (now) ${_alertQueue.length} as time to wait is ${timeToWaitForThisTraffic} and last val was ${lastTrafficAlertTimeValue}");
      _isPlaying = true;
      _alertQueue.removeAt(0);
      _AudioSequencePlayer(_buildAlertSoundIdSequence(nextAlert)).playAudioSequence().then((value) { 
        _log("Finished playing sequence, per listener callback");
        _isPlaying = false;
        if (_alertQueue.isNotEmpty) {
          Future.delayed(Duration(milliseconds: _tempTimeBetweenAnyAlertMs), runAudibleAlertsQueueProcessing);        
        }
      });
    } else if (timeToWaitForThisTraffic > 0) {
      _log("waiting to alert for ${trafficKey} for ${timeToWaitForThisTraffic}ms");
      Future.delayed(Duration(milliseconds: timeToWaitForThisTraffic), runAudibleAlertsQueueProcessing);
    }
  }


  /**
   * Construct soundId sequence based on alert properties and preference configuration
   * @param alert Alert item to build soundId sequence for
   * @return Sequence of soundId's for the soundplayer that represents the assembled alert
   */
  List<AudioPlayer> _buildAlertSoundIdSequence(final _AlertItem alert) {
      final List<AudioPlayer> alertAudio = [];
      if (alert._closingEvent != null && alert._closingEvent._isCriticallyClose)
          alertAudio.add(_criticallyCloseChirpAudio);
      alertAudio.add(_tempPrefTopGunDorkMode ? _bogeyAudio : _trafficAudio);
      switch (_tempTrafficIdOption) {
          case TrafficIdOption.PHONETIC_ALPHA_ID:
              _addPhoneticAlphaTrafficIdAudio(alertAudio, alert);
              break;
          case TrafficIdOption.FULL_CALLSIGN:
              _addFullCallsignTrafficIdAudio(alertAudio, alert._traffic?.message.callSign);
      }
      if (alert._closingEvent != null) {
          _addTimeToClosestPointOfApproachAudio(alertAudio, alert._closingEvent);
      }

      final int clockHour = nearestClockHourFromHeadingAndLocations(alert._ownLocation?.latitude??0,
										alert._ownLocation?.longitude??0, alert._traffic?.message.coordinates.latitude??0, 
                    alert._traffic?.message.coordinates.longitude??0, alert._ownLocation?.heading??0);
      _addPositionAudio(alertAudio, clockHour, alert._ownAltitude - (alert._traffic?.message.altitude??0));
      
      
      if (_tempDistanceCalloutOption != DistanceCalloutOption.NONE) {
          _addDistanceAudio(alertAudio, alert._distanceNmi);
      }
      
      if (_tempVerticalAttitudeCallout /* && (alert._traffic?.message.verticalSpeed??0.0 != 0.0  Indeterminate value */) {
          _addVerticalAttitudeAudio(alertAudio, alert._traffic?.message.verticalSpeed??0.0);
      }
      return alertAudio;
  }

  void _addPositionAudio(List<AudioPlayer> alertAudio, int clockHour, double altitudeDiff) {
      alertAudio.add(_atAudio);
      alertAudio.add(_numberAudios[clockHour]);
      alertAudio.add(_oClockAudio);
      alertAudio.add(altitudeDiff.abs() < 100 ? _sameAltitudeAudio
              : (altitudeDiff > 0 ? _lowAudio : _highAudio));
  }  

  void _addVerticalAttitudeAudio(List<AudioPlayer> alertAudio, double vspeed) {
      if (vspeed.abs() < 100)
          alertAudio.add(_levelAudio);
      else if (vspeed >= 100)
          alertAudio.add(_climbingAudio);
      else if (vspeed <= -100)
          alertAudio.add(_descendingAudio);
  }  

  void _addPhoneticAlphaTrafficIdAudio(List<AudioPlayer> alertAudio, _AlertItem alert) {
    final String trafficKey = _getTrafficKey(alert._traffic);
    int icaoIndex = _phoneticAlphaIcaoSequenceQueue.indexOf(trafficKey);
    if (icaoIndex == -1) {
        _phoneticAlphaIcaoSequenceQueue.add(trafficKey);
        icaoIndex = _phoneticAlphaIcaoSequenceQueue.length-1;
    }
    alertAudio.add(_alphabetAudios[icaoIndex % _alphabetAudios.length]);
  } 

  void _addFullCallsignTrafficIdAudio(List<AudioPlayer> alertAudio, String? callsign) {
    if (callsign == null || callsign.trim().isEmpty) {
      return;
    }
    final String normalizedCallsign = callsign.toUpperCase().trim();
    for (int i = 0; i < normalizedCallsign.length; i++) {
        int c = normalizedCallsign[i].codeUnitAt(0);
        if (c <= "9".codeUnitAt(0) && c >= "0".codeUnitAt(0))
            alertAudio.add(_numberAudios[c-"0".codeUnitAt(0)]);
        else if (c >= "A".codeUnitAt(0) && c <= "Z".codeUnitAt(0))
            alertAudio.add(_alphabetAudios[c-"A".codeUnitAt(0)]);
    }
  }  

  void _addDistanceAudio(List<AudioPlayer> alertAudio, double distance) {
      _addNumericalAlertAudio(alertAudio, distance, _tempDistanceCalloutOption == DistanceCalloutOption.DECIMAL);
      alertAudio.add(_milesAudio);
  }  

  /**
   * Inject an individual digit audio alert sound sequence (1,032 ==> "one-zero-three-two")
   * @param alertAudio Existing audio list to add numeric value to
   * @param numeric Numeric value to speak into alert audio
   * @param doDecimal Whether to speak 1st decimal into alert (false ==> rounded to whole #)
   */
  void _addNumericalAlertAudio(List<AudioPlayer> alertAudio, double numeric, bool doDecimal) {
      if (_tempNumberFormatOption == NumberFormatOption.COLLOQUIAL) {
          _addColloquialNumericBaseAlertAudio(alertAudio, doDecimal ? numeric : numeric.round() * 1.0);
      } else {
          _addNumberSequenceNumericBaseAlertAudio(alertAudio, doDecimal ? numeric : numeric.round() * 1.0);
      }

      if (doDecimal) {
          _addFirstDecimalAlertAudioSequence(alertAudio, numeric);
      }
  }

  /**
   * Speak a number in digit-by-digit format (1962 ==> "one nine six two")
   * @param alertAudio List of soundId to append to
   * @param numeric Numeric value to speak into alertAudio
   */
  void _addNumberSequenceNumericBaseAlertAudio(List<AudioPlayer> alertAudio, double numeric) {
      double curNumeric = numeric;    // iteration variable for digit processing
      for (int i = max(numerics.log10(numeric).floor(), 0); i >= 0; i--) {
          if (i == 0) {
              alertAudio.add(_numberAudios[min((curNumeric % 10).floor(), 9)]);
          } else {
              final double pow10 = pow(10, i) as double;
              alertAudio.add(_numberAudios[min(curNumeric / pow10, 9).floor()]);
              curNumeric = curNumeric % pow10;
          }
      }
  }

  /**
   * Speak a number in colloquial format (1962 ==> "one thousand nine hundred sixty-two")
   * @param alertAudio List of soundId to append to
   * @param numeric Numeric value to speak into alertAudio
   */
  void _addColloquialNumericBaseAlertAudio(List<AudioPlayer> alertAudio, double numeric) {
      for (int i = max(numerics.log10(numeric).round(), 0); i >= 0; i--) {
          if (i == 0
              // Only speak "zero" if it is only zero (not part of tens/hundreds/thousands)
              && ((numeric % 10) != 0 || (max(numerics.log10(numeric), 0)) == 0))
          {
              alertAudio.add(_numberAudios[min(numeric % 10, 9).floor()]);
          } else {
              if (i > 3) {
                  alertAudio.add(_overAudio);
                  alertAudio.addAll([ _numberAudios[9], _thousandAudio, _numberAudios[9], _hundredAudio, 
                    _twentiesToNinetiesAudios[9 - 2], _numberAudios[9] ]);
                  return;
              } else {
                  final double pow10 = pow(10, i) * 1.0;
                  final int digit = min(numeric / pow10, 9).floor();
                  if (i == 1 && digit == 1) {             // tens/teens
                      alertAudio.add(_numberAudios[10 + (numeric.floor()) % 10]);
                      return;
                  } else {
                      if (i == 1 && digit != 0) {         // twenties/thirties/etc.
                          alertAudio.add(_twentiesToNinetiesAudios[digit-2]);
                      } else if (i == 2 && digit != 0) {  // hundreds
                          alertAudio.add(_numberAudios[digit]);
                          alertAudio.add(_hundredAudio);
                      } else if (i == 3 && digit != 0) {  // thousands
                          alertAudio.add(_numberAudios[digit]);
                          alertAudio.add(_thousandAudio);
                      }
                      numeric = numeric % pow10;
                  }
              }
          }
      }
  }

  void _addFirstDecimalAlertAudioSequence(List<AudioPlayer> alertAudio, double numeric) {
      final int firstDecimal = min(((numeric - numeric.floor()) * 10).round(), 9);
      if (firstDecimal != 0) {
          alertAudio.add(_pointAudio);
          alertAudio.add(_numberAudios[firstDecimal]);
      }
  }

  void _addTimeToClosestPointOfApproachAudio(List<AudioPlayer> alertAudio, _ClosingEvent closingEvent) {
      if (_addClosingSecondsAudio(alertAudio, closingEvent.closingSeconds())) {
          if (_tempDistanceCalloutOption != DistanceCalloutOption.NONE) {
              alertAudio.add(_withinAudio);
              _addDistanceAudio(alertAudio, closingEvent._closestApproachDistanceNmi);
          }
      }
  }  

  bool _addClosingSecondsAudio(List<AudioPlayer> alertAudio, double closingSeconds) {
      // Subtract speaking time of audio clips, and computation thereof, prior to # of seconds in this alert
      final double adjustedClosingSeconds = closingSeconds - 1; // SWAG TODO: /*(soundPlayer.getPartialSoundSequenceDuration(alertAudio, speakingRate)+100)/1000.00;
      if (adjustedClosingSeconds > 0) {
          alertAudio.add(_closingInAudio);
          _addNumericalAlertAudio(alertAudio, adjustedClosingSeconds, false);
          alertAudio.add(_secondsAudio);
          return true;
      }
      return false;
  }  

  String _getTrafficKey(Traffic? traffic) {
    return "${traffic?.message.callSign}:${traffic?.message.icao}";
  }


  static void _log(String msg) {
    print("${DateTime.now()}: ${msg}");
  }
}


class _ClosingEvent {
  final double _closingTimeSec;
  final double _closestApproachDistanceNmi;
  final int _eventTimeMillis;
  final bool _isCriticallyClose;

  _ClosingEvent(double closingTimeSec, double closestApproachDistanceNmi, bool isCriticallyClose) 
    : _closingTimeSec = closingTimeSec, _closestApproachDistanceNmi = closestApproachDistanceNmi, 
    _isCriticallyClose = isCriticallyClose, _eventTimeMillis = DateTime.now().millisecondsSinceEpoch;

  double closingSeconds() {
    return _closingTimeSec-(DateTime.now().millisecondsSinceEpoch - _eventTimeMillis)/1000.0000;
  }
}


class _AlertItem {
  final Traffic? _traffic;
  final Position? _ownLocation;
  final double _distanceNmi;
  final double _ownAltitude;
  final _ClosingEvent? _closingEvent;

  _AlertItem(Traffic? traffic, Position? ownLocation, double ownAltitude, _ClosingEvent? closingEvent, double distnaceNmi) 
    : _traffic = traffic, _ownLocation = ownLocation, _ownAltitude = ownAltitude, _closingEvent = closingEvent, _distanceNmi = distnaceNmi;

  @override
  int get hashCode => _traffic?.message.icao.hashCode ?? 0;

  @override
  bool operator ==(Object other) {
    return other is _AlertItem
      && other.runtimeType == runtimeType
      && (
        other._traffic?.message.icao == _traffic?.message.icao
        // NOT RELIABLE, AS IS OFTEN NULL OR EASILY HACKED || other._traffic?.message.callSign == _traffic?.message.callSign
      );
  }
}


class _AudioSequencePlayer {
  final List<AudioPlayer?> _audioPlayers;
  final Completer _completer;
  StreamSubscription<void>? _lastAudioPlayerSubscription;
  int _seqIndex = 0;

  _AudioSequencePlayer(List<AudioPlayer?> audioPlayers) 
    : _audioPlayers = audioPlayers, _completer = Completer(), assert(audioPlayers.isNotEmpty)
  {
    _lastAudioPlayerSubscription = _audioPlayers[0]?.onPlayerComplete.listen(_handleNextSeqAudio);      
  }

  void _handleNextSeqAudio(event) {
    _lastAudioPlayerSubscription?.cancel();
    if (_seqIndex < _audioPlayers.length) {
      _lastAudioPlayerSubscription = _audioPlayers[_seqIndex]?.onPlayerComplete.listen(_handleNextSeqAudio);
      _audioPlayers[_seqIndex++]?.resume();
    } else {        
      _completer.complete();
    }
  }

  Future<void> playAudioSequence() {
    _audioPlayers[_seqIndex++]?.resume();
    return _completer.future;
  }
}