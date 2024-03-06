import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:avaremp/gdl90/traffic_cache.dart';
import 'package:geolocator/geolocator.dart';
import 'traffic_math.dart';
import 'dart:math';
import 'package:dart_numerics/dart_numerics.dart' as numerics;
import 'package:logging/logging.dart';

enum TrafficIdOption { PHONETIC_ALPHA_ID, FULL_CALLSIGN, NONE }
enum DistanceCalloutOption { NONE, ROUNDED, DECIMAL }
enum NumberFormatOption { COLLOQUIAL, INDIVIDUAL_DIGIT }


class AudibleTrafficAlerts {

  static const double _kMpsToKnotsConv = 1.0/0.514444;
  static const double _kMetersToFeetCont = 3.28084;
  static const int _kMaxIntValue = 9999999999;

  static AudibleTrafficAlerts? _instance;
  static final Logger _log = Logger('AudibleTrafficAlerts');

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

  bool prefIsAudibleGroundAlertsEnabled = true;
  bool prefVerticalAttitudeCallout = false;
  DistanceCalloutOption prefDistanceCalloutOption = DistanceCalloutOption.NONE;
  NumberFormatOption prefNumberFormatOption = NumberFormatOption.COLLOQUIAL;
  TrafficIdOption prefTrafficIdOption = TrafficIdOption.NONE;
  bool prefTopGunDorkMode = false;
  int prefAudibleTrafficAlertsMinSpeed = 0;
  int prefAudibleTrafficAlertsDistanceMinimum = 10;
  double prefTrafficAlertsHeight = 1000;
  int prefMaxAlertFrequencySeconds = 15;
  int prefTimeBetweenAnyAlertMs = 750;

  bool prefIsAudibleClosingInAlerts = true;
  double prefClosingAlertAltitude = 1000;
  double prefClosingTimeThresholdSeconds = 60;
  double prefClosestApproachThresholdNmi = 1;
  double prefCriticalClosingAlertRatio = 0.5;

  bool _isRunning = false;
  bool _isPlaying = false;


  static Future<AudibleTrafficAlerts?> getAndStartAudibleTrafficAlerts(double playRate) async {
    if (_instance == null) {
      final Completer<AudibleTrafficAlerts> completer = Completer();
      Logger.root.level = Level.INFO;
      Logger.root.onRecord.listen((record) {
        print('${record.time} ${record.level.name} [${record.loggerName}] - ${record.message}');
      });      
      _instance = AudibleTrafficAlerts._privateConstructor();
      _instance?._loadAudio(playRate).then((value) { 
        _log.info("Started audible traffic alerts. Settings: playRate=$playRate");
        _instance?._isRunning = true;
        completer.complete(_instance);
      });
      return completer.future;
    }
    return _instance;
  }

  static Future<void> stopAudibleTrafficAlerts() async {
    _instance?._isRunning = false;
    _log.info("Stopped audible traffic alerts");
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

  void processTrafficForAudibleAlerts(List<Traffic?> trafficList, Position? ownshipLocation, DateTime? ownshipUpdateTime, 
    double ownVspeed, int ownIcao, bool ownIsAirborne) 
  {
    if (!_isRunning || ownshipLocation == null || (ownshipLocation.speed*_kMpsToKnotsConv < prefAudibleTrafficAlertsMinSpeed) 
      || !(ownIsAirborne || prefIsAudibleGroundAlertsEnabled)) 
    {
      if (_log.level <= Level.FINER) { // Preventing unnecessary string interpolcation of log message, per log level
        _log.finer("Skipping alerts processing due to top-level precondition (e.g., ownship location [$ownshipLocation] or airborne [$ownIsAirborne] filter , ownship speed [${ownshipLocation?.speed??0*_kMpsToKnotsConv}] filter, etc.)");
      }
      return;
    }

    bool hasInserts = false;
    for (final traffic in trafficList) {
      if (traffic == null || traffic.message.icao == ownIcao || !(traffic.message.isAirborne || prefIsAudibleGroundAlertsEnabled)) {      
        if (_log.level <= Level.FINER) { // Preventing unnecessary string interpolcation of log message, per log level
          _log.finer("Skipping this traffic [${_getTrafficKey(traffic)}] processing due to precondition (e.g., ownship icao [$ownIcao], traffic airborne [${traffic?.message.isAirborne}] filter, etc.)");
        }        
        continue;
      }
      final double altDiff = _kMetersToFeetCont * ownshipLocation.altitude - traffic.message.altitude;
			final String trafficPositionTimeCalcUpdateValue = "${traffic.message.time.millisecondsSinceEpoch}_${ownshipUpdateTime?.millisecondsSinceEpoch}";
			final String trafficKey = _getTrafficKey(traffic);  
      final String? lastTrafficPositionUpdateValue = _lastTrafficPositionUpdateTimeMap[trafficKey];
      double curDistance = _kMaxIntValue*1.0;
      if (_log.level <= Level.FINER) { // Preventing unnecessary string interpolcation of log message, per log level
        _log.finer("Processing [$trafficKey], which has previous update times of $lastTrafficPositionUpdateValue");
      }       
      if ((lastTrafficPositionUpdateValue == null || lastTrafficPositionUpdateValue != trafficPositionTimeCalcUpdateValue)
        && altDiff.abs() < prefTrafficAlertsHeight
        && (curDistance = greatCircleDistanceNmi(ownshipLocation.latitude, ownshipLocation.longitude,
          traffic.message.coordinates.latitude, traffic.message.coordinates.longitude)) < prefAudibleTrafficAlertsDistanceMinimum
      ) {
        if (_log.level <= Level.FINE) { // Preventing unnecessary string interpolcation of log message, per log level
          _log.fine("Got alert hit for [$trafficKey], with alt diff=$altDiff and distance=$curDistance");
        }        
        hasInserts = hasInserts || _upsertTrafficAlertQueue(
          _AlertItem(traffic, ownshipLocation, 
            prefIsAudibleClosingInAlerts  
              ? _determineClosingEvent(ownshipLocation, traffic, curDistance, ownVspeed)
              : null
            , curDistance, altDiff)
        );
      } else if (_log.level <= Level.FINER) {
        _log.finer("Traffic [$trafficKey] didn't make the cut, with alt diff=$altDiff and distance=$curDistance");
      }
      _lastTrafficPositionUpdateTimeMap[trafficKey] = trafficPositionTimeCalcUpdateValue;
    }  

    if (hasInserts) {
      scheduleMicrotask(runAudibleAlertsQueueProcessing);
    }
  }

  bool _upsertTrafficAlertQueue(_AlertItem alert) {
    final int existingIndex = _alertQueue.indexOf(alert);
    if (existingIndex == -1) {
      // If this is a "critically close" alert, put it ahead of the first non-critically close alert
      final int alertQueueSize;
      if (alert._closingEvent != null && alert._closingEvent._isCriticallyClose && (alertQueueSize = _alertQueue.length) > 0) {
        for (int i = 0; i < alertQueueSize; i++) {
          final _AlertItem curAlert = _alertQueue[i];
          if (curAlert._closingEvent == null || !curAlert._closingEvent._isCriticallyClose) {
            _alertQueue.insert(i, alert);
            break;
          }
        }
      } else {
        _alertQueue.add(alert);
      }
      return true;
    } else {
      _alertQueue[existingIndex] = alert;
    }
    return false;
  }

  _ClosingEvent? _determineClosingEvent(Position ownshipLocation, Traffic traffic, double currentDistance, double ownVspeed)
  {
      final int ownSpeedInKts = (_kMpsToKnotsConv * ownshipLocation.speed).round();
      final double ownAltInFeet = _kMetersToFeetCont * ownshipLocation.altitude;
      final double closingEventTimeSec = (closestApproachTime(
              traffic.message.coordinates.latitude, traffic.message.coordinates.longitude, 
              ownshipLocation.latitude, ownshipLocation.longitude, traffic.message.heading, ownshipLocation.heading, 
              traffic.message.velocity.round(), ownSpeedInKts
      )).abs() * 60.00 * 60.00;
      if (closingEventTimeSec < prefClosingTimeThresholdSeconds) {    // Gate #1: Time threshold met
          final Position myCaLoc = locationAfterTime(ownshipLocation.latitude, ownshipLocation.longitude,
                  ownshipLocation.heading, ownSpeedInKts*1.0, closingEventTimeSec/3600.000, ownAltInFeet, ownVspeed);
          final Position theirCaLoc = locationAfterTime(traffic.message.coordinates.latitude, traffic.message.coordinates.longitude,
            traffic.message.heading, traffic.message.velocity, closingEventTimeSec/3600.000, traffic.message.altitude, 
            traffic.message.verticalSpeed);
          double? caDistance;
          final double altDiff = myCaLoc.altitude - theirCaLoc.altitude;
          // Gate #2: If traffic will be within configured "cylinder" of closing/TCPA alerts, create a closing event
          if (altDiff.abs() < prefClosingAlertAltitude
                  && (
                    caDistance = greatCircleDistanceNmi(myCaLoc.latitude, myCaLoc.longitude, theirCaLoc.latitude, theirCaLoc.longitude)
                  ) < prefClosestApproachThresholdNmi
                  && currentDistance > caDistance)    // catches cases when moving away
          {
              final bool criticallyClose = prefCriticalClosingAlertRatio > 0
                      && (closingEventTimeSec / prefClosingTimeThresholdSeconds) <= prefCriticalClosingAlertRatio
                      && (caDistance / prefClosestApproachThresholdNmi) <= prefCriticalClosingAlertRatio;
              return _ClosingEvent(closingEventTimeSec, caDistance, criticallyClose);
          } 
      }
      return null;
  }  

  void runAudibleAlertsQueueProcessing() {
    if (!_isRunning || _isPlaying || _alertQueue.isEmpty) {
      return;
    }
    
    int timeToWaitForTraffic = _kMaxIntValue;
    // Loop to allow a traffic item to cede place in line to next one if available if it can't go now
    for (int i = 0; i < _alertQueue.length; i++) {
      final _AlertItem nextAlert = _alertQueue[i];
      if (_log.level <= Level.FINER) { // Preventing unnecessary string interpolcation of log message, per log level
        _log.finer("Queue processing: looking at ${_getTrafficKey(nextAlert._traffic)} in iteration $i with queue size ${_alertQueue.length}");
      }
      final String trafficKey = _getTrafficKey(nextAlert._traffic);
      final int? lastTrafficAlertTimeValue = _lastTrafficAlertTimeMap[trafficKey];
      if (lastTrafficAlertTimeValue == null
        || (timeToWaitForTraffic = min(timeToWaitForTraffic, (prefMaxAlertFrequencySeconds * 1000) - (DateTime.now().millisecondsSinceEpoch - lastTrafficAlertTimeValue))) <= 0
      ) {
        if (_log.level <= Level.FINE) { // Preventing unnecessary string interpolcation of log message, per log level
          _log.fine("Queue processing: Saying alert for ${_getTrafficKey(nextAlert._traffic)} in iteration $i with queue size ${_alertQueue.length}");
        }
        _lastTrafficAlertTimeMap[trafficKey] = DateTime.now().millisecondsSinceEpoch;
        _isPlaying = true;
        _alertQueue.removeAt(i);
        _AudioSequencePlayer(_buildAlertSoundSequence(nextAlert)).playAudioSequence().then((value) { 
          _isPlaying = false;
          if (_alertQueue.isNotEmpty) {
            Future.delayed(Duration(milliseconds: (_alertQueue[0]._closingEvent?._isCriticallyClose ?? false) ? 0 
              : prefTimeBetweenAnyAlertMs), runAudibleAlertsQueueProcessing);        
          }
        });
        return;
      } 
    }
    if (timeToWaitForTraffic != _kMaxIntValue && timeToWaitForTraffic > 0) {
      if (_log.level <= Level.FINE) { // Preventing unnecessary string interpolcation of log message, per log level
        _log.fine("Queue processing: Waiting for traffic for ${timeToWaitForTraffic}ms with queue size ${_alertQueue.length}");
      }
      Future.delayed(Duration(milliseconds: timeToWaitForTraffic), runAudibleAlertsQueueProcessing);
    }
  }


  /**
   * Construct sound sequence based on alert properties and preference configuration
   * @param alert Alert item to build sound sequence for
   * @return Sequence of sounds that represents the assembled alert
   */
  List<AudioPlayer> _buildAlertSoundSequence(final _AlertItem alert) {
      final List<AudioPlayer> alertAudio = [];
      if (alert._closingEvent != null && alert._closingEvent._isCriticallyClose) {
          alertAudio.add(_criticallyCloseChirpAudio);
      }
      alertAudio.add(prefTopGunDorkMode ? _bogeyAudio : _trafficAudio);
      switch (prefTrafficIdOption) {
          case TrafficIdOption.PHONETIC_ALPHA_ID:
              _addPhoneticAlphaTrafficIdAudio(alertAudio, alert);
              break;
          case TrafficIdOption.FULL_CALLSIGN:
              _addFullCallsignTrafficIdAudio(alertAudio, alert._traffic?.message.callSign);
          default:
      }
      if (alert._closingEvent != null) {
          _addTimeToClosestPointOfApproachAudio(alertAudio, alert._closingEvent);
      }

      final int clockHour = nearestClockHourFromHeadingAndLocations(alert._ownLocation?.latitude??0,
										alert._ownLocation?.longitude??0, alert._traffic?.message.coordinates.latitude??0, 
                    alert._traffic?.message.coordinates.longitude??0, alert._ownLocation?.heading??0);
      _addPositionAudio(alertAudio, clockHour, alert._altDiff);
      
      
      if (prefDistanceCalloutOption != DistanceCalloutOption.NONE) {
          _addDistanceAudio(alertAudio, alert._distanceNmi);
      }
      
      if (prefVerticalAttitudeCallout /* && (alert._traffic?.message.verticalSpeed??0.0 != 0.0  Indeterminate value */) {
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
      if (vspeed.abs() < 100) {
          alertAudio.add(_levelAudio);
      } else if (vspeed >= 100) {
          alertAudio.add(_climbingAudio);
      } else if (vspeed <= -100) {
          alertAudio.add(_descendingAudio);
      }
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

  static final int _nineCodeUnit = "9".codeUnitAt(0), _zeroCodeUnit = "0".codeUnitAt(0), _aCodeUnit = "A".codeUnitAt(0), _zCodeUnit = "Z".codeUnitAt(0);
  void _addFullCallsignTrafficIdAudio(List<AudioPlayer> alertAudio, String? callsign) {
    if (callsign == null || callsign.trim().isEmpty) {
      return;
    }
    final String normalizedCallsign = callsign.toUpperCase().trim();
    for (int i = 0; i < normalizedCallsign.length; i++) {
        final int c = normalizedCallsign[i].codeUnitAt(0);
        if (c <= _nineCodeUnit && c >= _zeroCodeUnit) {
            alertAudio.add(_numberAudios[c - _zeroCodeUnit]);
        } else if (c >= _aCodeUnit && c <= _zCodeUnit) {
            alertAudio.add(_alphabetAudios[c - _aCodeUnit]);
        }
    }
  }  

  void _addDistanceAudio(List<AudioPlayer> alertAudio, double distance) {
      _addNumericalAlertAudio(alertAudio, distance, prefDistanceCalloutOption == DistanceCalloutOption.DECIMAL);
      alertAudio.add(_milesAudio);
  }  

  /**
   * Inject an individual digit audio alert sound sequence (1,032 ==> "one-zero-three-two")
   * @param alertAudio Existing audio list to add numeric value to
   * @param numeric Numeric value to speak into alert audio
   * @param doDecimal Whether to speak 1st decimal into alert (false ==> rounded to whole #)
   */
  void _addNumericalAlertAudio(List<AudioPlayer> alertAudio, double numeric, bool doDecimal) {
      if (prefNumberFormatOption == NumberFormatOption.COLLOQUIAL) {
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
   * @param alertAudio List of sounds to append to
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
   * @param alertAudio List of sounds to append to
   * @param numeric Numeric value to speak into alertAudio
   */
  void _addColloquialNumericBaseAlertAudio(List<AudioPlayer> alertAudio, double numeric) {
    final double log10Val = numerics.log10(numeric);
    for (int i = max(log10Val.isInfinite || log10Val.isNaN ? -1 : log10Val.round(), 0); i >= 0; i--) {
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
          if (prefDistanceCalloutOption != DistanceCalloutOption.NONE) {
              alertAudio.add(_withinAudio);
              _addDistanceAudio(alertAudio, closingEvent._closestApproachDistanceNmi);
          }
      }
  }  

  bool _addClosingSecondsAudio(List<AudioPlayer> alertAudio, double closingSeconds) {
      // Subtract speaking time of audio clips, and computation thereof, prior to # of seconds in this alert
      final double adjustedClosingSeconds = closingSeconds - (alertAudio.length*500.0/1000.0); // SWAG ==> TODO: Put in infra and code to compute duration of audio-to-date exactly?
      if (adjustedClosingSeconds > 0) {
          alertAudio.add(_closingInAudio);
          _addNumericalAlertAudio(alertAudio, adjustedClosingSeconds, false);
          alertAudio.add(_secondsAudio);
          return true;
      }
      return false;
  }  

  static String _getTrafficKey(Traffic? traffic) {
    return "${traffic?.message.callSign}:${traffic?.message.icao}";
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
  final double _altDiff;
  final _ClosingEvent? _closingEvent;

  _AlertItem(Traffic? traffic, Position? ownLocation, _ClosingEvent? closingEvent, double distnaceNmi, double altDiff) 
    : _traffic = traffic, _ownLocation = ownLocation, _closingEvent = closingEvent, _distanceNmi = distnaceNmi, _altDiff = altDiff;

  @override
  int get hashCode => _traffic?.message.icao.hashCode ?? 0;

  @override
  bool operator ==(Object other) {
    return other is _AlertItem
      && other.runtimeType == runtimeType
      && _traffic?.message.icao == other._traffic?.message.icao;
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