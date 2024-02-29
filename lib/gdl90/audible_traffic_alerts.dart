import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'traffic_report_message.dart';
import 'package:geolocator/geolocator.dart';


class AudibleTrafficAlerts implements PlayAudioSequenceCompletionListner {

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

  bool _isRunning = false;


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
    : _audioCache = AudioCache(prefix: "assets/audio/traffic_alerts/"), _trafficAudio = AudioPlayer(), _bogeyAudio = AudioPlayer(),
    _closingInAudio = AudioPlayer(), _overAudio = AudioPlayer(), _lowAudio = AudioPlayer(), _highAudio = AudioPlayer(), _sameAltitudeAudio = AudioPlayer(),
    _oClockAudio = AudioPlayer(), _twentiesToNinetiesAudios = [], _hundredAudio = AudioPlayer(), _thousandAudio = AudioPlayer(), _atAudio = AudioPlayer(), 
    _alphabetAudios = [], _numberAudios = [], _secondsAudio = AudioPlayer(), _milesAudio = AudioPlayer(), _climbingAudio = AudioPlayer(), _descendingAudio = AudioPlayer(), 
    _levelAudio = AudioPlayer(), _criticallyCloseChirpAudio = AudioPlayer(), _withinAudio = AudioPlayer(), _pointAudio = AudioPlayer();

  Future<void> _destroy() async {
    await _audioCache.clearAll();
  }

  Future<void> _loadAudio(double playRate) async {
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
        "tr_hotel.mp3", "tr_lima.mp3", "tr_mike.mp3", "tr_november.mp3", "tr_oscar.mp3", "tr_papa.mp3", "tr_quebec.mp3", "tr_romeo.mp3",
        "tr_sierra.mp3", "tr_tango.mp3", "tr_uniform.mp3", "tr_victor.mp3", "tr_whiskey.mp3", "tr_xray.mp3", "tr_yankee.mp3", "tr_zulu.mp3" ]
    };
    for (final singleEntry in singleAudioMap.entries) {
      await _populateAudio(singleEntry.key, singleEntry.value, playRate);
    }
    for (final listEntry in listAudioMap.entries) {
      for (final assetName in listEntry.value) {
        final ap = AudioPlayer();
        await _populateAudio(ap, assetName, playRate);
        listEntry.key.add(ap);
      }
    }
  }

  Future<void> _populateAudio(AudioPlayer player, String assetSourceName, double playRate) async {
      await _audioCache.load(assetSourceName);
      player.audioCache = _audioCache;
      await player.setSource(AssetSource(assetSourceName));
      await player.setPlaybackRate(playRate);
      await player.setPlayerMode(PlayerMode.lowLatency);     
  }

  Future<void> playSomeStuff() async {
    await AudioSequencePlayer([ _trafficAudio, _bogeyAudio ], this).playAudioSequence();
  }
  
  @override
  void sequencePlayCompletion() {
    // TODO: implement sequencePlayCompletion
    print("Finished playing sequence, per listener callback");
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
    final TrafficReportMessage _traffic;
    final Position _ownLocation;
    final double _distanceNmi;
    final int _ownAltitude;
    final _ClosingEvent _closingEvent;

    _AlertItem(TrafficReportMessage traffic, Position ownLocation, int ownAltitude, _ClosingEvent closingEvent, double distnaceNmi) 
      : _traffic = traffic, _ownLocation = ownLocation, _ownAltitude = ownAltitude, _closingEvent = closingEvent, _distanceNmi = distnaceNmi;

    @override
    int get hashCode => _traffic.callSign.hashCode;

    @override
    bool operator ==(Object other) {
        return other is _AlertItem
          && other.runtimeType == runtimeType
          && other._traffic.callSign == _traffic.callSign;
    }
}


abstract class PlayAudioSequenceCompletionListner {
  void sequencePlayCompletion();
}

class AudioSequencePlayer {
  final List<AudioPlayer?> _audioPlayers;
  final Completer _completer;

  AudioSequencePlayer(List<AudioPlayer?> audioPlayers, [PlayAudioSequenceCompletionListner? sequenceCompletionListener ]) 
    : _audioPlayers = audioPlayers, _completer = Completer(), assert(audioPlayers.isNotEmpty)
  {
    final List<StreamSubscription<void>?> audioPlayerSubscriptions = [];
    for (int i = 0; i < _audioPlayers.length; i++) {
      if (i < _audioPlayers.length-1) {
        audioPlayerSubscriptions.add(_audioPlayers[i]?.onPlayerComplete.listen((event) {
          _audioPlayers[i+1]?.resume();
        }));
      } else {
        audioPlayerSubscriptions.add(_audioPlayers[i]?.onPlayerComplete.listen((event) {
          for (final subscription in audioPlayerSubscriptions) {
            subscription?.cancel();
          }          
          _completer.complete();
          if (sequenceCompletionListener != null) {
            sequenceCompletionListener.sequencePlayCompletion();
          }
        }));
      }
    }
  }

  Future<void> playAudioSequence() {
    _audioPlayers[0]?.resume();
    return _completer.future;
  }
}