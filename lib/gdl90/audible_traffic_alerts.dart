import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:avaremp/gdl90/traffic_cache.dart';
import 'package:geolocator/geolocator.dart';
import 'traffic_math.dart';

enum TrafficIdOption { PHONETIC_ALPHA_ID, FULL_CALLSIGN }

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
  bool _tempPrefTopGunDorkMode = false;
  int _tempPrefAudibleTrafficAlertsMinSpeed = 10;
  int _tempPrefAudibleTrafficAlertsDistanceMinimum = 5;
  bool _tempPrefIsAudibleClosingInAlerts = true;
  double _tempPrefTrafficAlertsHeight = 5000;
  int _tempPrefMaxAlertFrequencySeconds = 15;
  TrafficIdOption _tempTrafficIdOption = TrafficIdOption.PHONETIC_ALPHA_ID;
  

  bool _isRunning = false;
  bool _isPlaying = false;


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

  void processTrafficForAudibleAlerts(List<Traffic?> trafficList, Position? ownshipLocation, DateTime? ownshipUpdateTime) {
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
          _AlertItem(traffic, ownshipLocation, ownshipLocation.altitude/*TODO*/, null /*TODO*/, curDistance)
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
          scheduleMicrotask(runAudibleAlertsQueueProcessing);        
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
      // if (alert.closingEvent != null && alert.closingEvent.isCriticallyClose)
      //     alertAudio.add(criticallyCloseChirpSoundId);
      alertAudio.add(_tempPrefTopGunDorkMode ? _bogeyAudio : _trafficAudio);
      switch (_tempTrafficIdOption) {
          case TrafficIdOption.PHONETIC_ALPHA_ID:
              _addPhoneticAlphaTrafficIdAudio(alertAudio, alert);
              break;
          case TrafficIdOption.FULL_CALLSIGN:
          //     addFullCallsignTrafficIdAudio(alertAudio, alert.trafficCallsign);
      }
      // if (alert.closingEvent != null) {
      //     addTimeToClosestPointOfApproachAudio(alertAudio, alert.closingEvent, speakingRate);
      // }


      final int clockHour = nearestClockHourFromHeadingAndLocations(alert._ownLocation?.latitude??0,
										alert._ownLocation?.longitude??0, alert._traffic?.message.coordinates.latitude??0, 
                    alert._traffic?.message.coordinates.longitude??0, alert._ownLocation?.heading??0);
      _addPositionAudio(alertAudio, clockHour, alert._ownAltitude - (alert._traffic?.message.altitude??0));
      
      
      // if (this.distanceCalloutOption != DistanceCalloutOption.NONE) {
      //     addDistanceAudio(alertAudio, alert.distanceNmi);
      // }
      /*
      if (this.verticalAttitudeCallout && alert.vspeed != Integer.MAX_VALUE /* Indeterminate value */) {
          addVerticalAttitudeAudio(alertAudio, alert.vspeed);
      }
      return alertAudio;
      */
      return alertAudio;
  }

  void _addPositionAudio(final List<AudioPlayer> alertAudio, final int clockHour, final double altitudeDiff) {
      alertAudio.add(_atAudio);
      alertAudio.add(_numberAudios[clockHour]);
      alertAudio.add(_oClockAudio);
      alertAudio.add(altitudeDiff.abs() < 100 ? _sameAltitudeAudio
              : (altitudeDiff > 0 ? _lowAudio : _highAudio));
  }  

  void _addPhoneticAlphaTrafficIdAudio(final List<AudioPlayer> alertAudio, _AlertItem alert) {
    final String trafficKey = _getTrafficKey(alert._traffic);
    int icaoIndex = _phoneticAlphaIcaoSequenceQueue.indexOf(trafficKey);
    if (icaoIndex == -1) {
        _phoneticAlphaIcaoSequenceQueue.add(trafficKey);
        icaoIndex = _phoneticAlphaIcaoSequenceQueue.length-1;
    }
    alertAudio.add(_alphabetAudios[icaoIndex % _alphabetAudios.length]);
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