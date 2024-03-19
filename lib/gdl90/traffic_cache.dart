import 'dart:core';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:avaremp/gdl90/traffic_report_message.dart';
import 'package:avaremp/geo_calculations.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:avaremp/gdl90/audible_traffic_alerts.dart';

import '../gps.dart';

/*
void main()  {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static List<CustomPaint> _buildTrafficPainters() {
    TrafficReportMessage m1 = TrafficReportMessage(20);
    m1.altitude = 2200;
    m1.coordinates = const LatLng(41.2565, 95.9345);
    m1.emitter = 7;
    m1.airborne = true;
    m1.velocity = 400;
    m1.verticalSpeed = -100;
    Traffic highDescendingRotor = Traffic(m1);
    TrafficReportMessage m2 = TrafficReportMessage(20);
    m2.altitude = 30;
    m2.coordinates = const LatLng(41.2565, 95.9345);
    m2.emitter = 3;
    m2.airborne = true;
    m2.velocity = 200;
    m2.verticalSpeed = -100;
    Traffic lowAscendingHeavy = Traffic(m2);   
    TrafficReportMessage m3 = TrafficReportMessage(20);
    m3.altitude = 300*3.2;
    m3.coordinates = const LatLng(41.2565, 95.9345);
    m3.emitter = 1;
    m3.airborne = true;
    m3.velocity = 200;
    m3.verticalSpeed = 0;
    Traffic sameAltLevelLight = Traffic(m3);       
    return [
      CustomPaint(painter: _TrafficPainter(highDescendingRotor)),
      CustomPaint(painter: _TrafficPainter(lowAscendingHeavy)),
      CustomPaint(painter: _TrafficPainter(sameAltLevelLight))
    ];
  }

  @override
  Widget build(BuildContext context) {
    // return MaterialApp(
    //   home: CustomPaint(painter: _MyPainter()), //Center(child: Text("hello there"))
    //   theme : ThemeData(
    //     brightness: Brightness.light,
    //   ),      
    // );
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/OmaSecClip.png"),
              fit: BoxFit.cover
            )
          ),
          constraints: const BoxConstraints.expand(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildTrafficPainters()
          )
        )
      )
    );
  }
}
*/

enum _TrafficAircraftType { regular, large, rotor }

class _TrafficPainter extends CustomPainter {

  static const double _kMetersToFeetCont = 3.28084;

  final _TrafficAircraftType _aircraftType;
  final bool _isAirborne;
  final int _flightLevelDiff;
  final int _vspeedDirection;
  final int _velocityLevel;

  static _TrafficAircraftType _getAircraftType(int adsbEmitterId) {
    switch(adsbEmitterId) {
      case 3:
      case 4:
      case 5:
        return _TrafficAircraftType.large;
      case 7:
        return _TrafficAircraftType.rotor;
      default:
        return _TrafficAircraftType.regular;
    }
  }

  static int _getFlightLevelDiff(double trafficAltitude) {
    return ((trafficAltitude - Storage().position.altitude.abs() * _kMetersToFeetCont) / 1000).round();
  }

  static int _getVerticalSpeedDirection(double verticalSpeed) {
    if (verticalSpeed*3.28 < -100) {
      return -1;
    } else if (verticalSpeed*3.28 > 100) {
      return 1;
    } else {
      return 0;
    }
  }

  _TrafficPainter(Traffic traffic) 
    : _aircraftType = _getAircraftType(traffic.message.emitter), 
    _isAirborne = traffic.message.airborne,
    _flightLevelDiff = _getFlightLevelDiff(traffic.message.altitude), 
    _vspeedDirection = _getVerticalSpeedDirection(traffic.message.verticalSpeed),
    _velocityLevel = (traffic.message.velocity*1.94384 / 60.0).round() {
      //print("Emitter is ${traffic.message.emitter} and type is $_aircraftType for callsign ${traffic.message.callSign}");
    }

  // Colors
  static const Color _levelColor = Color(0xFF000000);           // Level traffic = Black
  static const Color _highColor = Color(0xFF1919D0);            // High traffic = Mild dark blue
  static const Color _lowColor = Color(0xFF00D000);             // Low traffic = Limish green
  static const Color _groundColor = Color(0xFF836539);          // Ground traffic = Brown
  static const Color _lightForegroundColor = Color(0xFFFFFFFF); // Overlay for darker bg = White
  static const Color _darkForegroundColor = Color(0xFF000000);  // Overlay for light bg = Black

  // Aircraft outlines and vertical speed plus/minus overlays
  static final ui.Path _largeAircraft = ui.Path()
    ..addPolygon([ const Offset(0, 0), const Offset(15, 31), const Offset(16, 31), const Offset(31, 0), 
      const Offset(16, 4), const Offset(15, 4) ], true);  
  static final ui.Path _largeAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(10, 7), const Offset(21, 7), const Offset(21, 8), const Offset(10, 8) ], true);
  static final ui.Path _largeAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(15, 17), const Offset(15, 24), const Offset(16, 24), const Offset(16, 17) ], true)
    ..addPolygon([ const Offset(12, 20), const Offset(19, 20), const Offset(19, 21), const Offset(12, 21) ], true);    

  static final ui.Path _lightAircraft = ui.Path()
    ..addPolygon([ const Offset(4, 4), const Offset(15, 31), const Offset(16, 31), const Offset(27, 4),
      const Offset(16, 10), const Offset(15, 10) ], true);
  static final ui.Path _lightAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(15, 17), const Offset(15, 24), const Offset(16, 24), const Offset(16, 17) ], true)
    ..addPolygon([ const Offset(12, 20), const Offset(19, 20), const Offset(19, 21), const Offset(12, 21) ], true);
  static final ui.Path _lightAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(11, 17), const Offset(20, 17), const Offset(20, 18), const Offset(11, 18) ], true);

  static final ui.Path _rotorcraft = ui.Path()
    ..addOval(const Rect.fromLTRB(9, 11, 22, 31))
    ..addPolygon([const Offset(29, 11), const Offset(31, 13), const Offset(2, 31), const Offset(0, 29)], true)
    ..addPolygon([const Offset(9, 15), const Offset(2, 11), const Offset(0, 13), const Offset(10, 19) ], true)
    ..addPolygon([const Offset(21, 27), const Offset(29, 31), const Offset(31, 29), const Offset(21, 23) ], true)
    ..addRect(const Rect.fromLTRB(14, 0, 17, 12))
    ..addRect(const Rect.fromLTRB(10, 3, 21, 7));


  /// Paint arcraft, vpeed overlay, and (horizontal) speed barb
  @override paint(Canvas canvas, Size size) {
    // Decide opacity, based on dinstance from ownship and whether traffic is on the ground 
    // Traffic far above or below ownship will be quite transparent, to avoid clutter, and 
    // ground traffic has a 50% max opacity / min transparency to avoid taxiing or stationary (ADSB-initilized)
    // traffic from flooding the map
    final double opacity = min(max(.2, 1 - _flightLevelDiff.abs() * 0.1), _isAirborne ? 1.0 : 0.5);
    // Define colors using above opacity, with contrasting colors for above, level, below, and ground
    final Color acColor;
    if (!_isAirborne) {
      acColor = Color.fromRGBO(_groundColor.red, _groundColor.green, _groundColor.blue, opacity);
    } else if (_flightLevelDiff > 0) {
      acColor = Color.fromRGBO(_highColor.red, _highColor.green, _highColor.blue, opacity);
    } else if (_flightLevelDiff < 0) {
      acColor = Color.fromRGBO(_lowColor.red, _lowColor.green, _lowColor.blue, opacity);
    } else {
      acColor = Color.fromRGBO(_levelColor.red, _levelColor.green, _levelColor.blue, opacity);
    }
    final Color vspeedOverlayColor;
    if (_flightLevelDiff >= 0) {
      vspeedOverlayColor = Color.fromRGBO(_lightForegroundColor.red, _lightForegroundColor.green, _lightForegroundColor.blue, opacity);
    } else {
      vspeedOverlayColor = Color.fromRGBO(_darkForegroundColor.red, _darkForegroundColor.green, _darkForegroundColor.blue, opacity);
    }

    // draw aircraft
    final ui.Path aircraftShape;
    switch(_aircraftType) {
      case _TrafficAircraftType.large:
        aircraftShape = _largeAircraft;
        break;
      case _TrafficAircraftType.rotor:
        aircraftShape = _rotorcraft;
        break;
      default:
        aircraftShape = _lightAircraft;
    }
    canvas.drawPath(aircraftShape, Paint()..color = acColor);
    
    // draw vspeed overlay (if not level)
    if (_vspeedDirection != 0) {
      if (_aircraftType == _TrafficAircraftType.large) {
        canvas.drawPath(
          _vspeedDirection > 0 ? _largeAircraftPlusSign : _largeAircraftMinusSign,
          Paint()..color = vspeedOverlayColor
        );    
      } else {
        canvas.drawPath(
          _vspeedDirection > 0 ? _lightAircraftPlusSign : _lightAircraftMinusSign,
          Paint()..color = vspeedOverlayColor
        ); 
      }
    }
    
    // draw speed barb
    canvas.drawLine(const Offset(15, 31), Offset(15, 31+_velocityLevel*2.0), Paint()..color = acColor);
    canvas.drawLine(const Offset(16, 31), Offset(16, 31+_velocityLevel*2.0), Paint()..color = acColor);
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter  oldDelegate) {
    return _flightLevelDiff != oldDelegate._flightLevelDiff || _vspeedDirection != oldDelegate._vspeedDirection 
      || _isAirborne != oldDelegate._isAirborne || _velocityLevel != oldDelegate._velocityLevel;
  }
}

class Traffic {

  final TrafficReportMessage message;

  Traffic(this.message);

  bool isOld() {
    // old if more than 1 min
    return DateTime.now().difference(message.time).inMinutes > 0;
  }

  Widget getIcon() {
    // return Transform.rotate(angle: message.heading * pi / 180,
    //     child: Container(
    //       decoration: BoxDecoration(
    //           borderRadius: BorderRadius.circular(5),
    //           color: Colors.black),
    //       child:const Icon(Icons.arrow_upward_rounded, color: Colors.white,)));
    return Transform.rotate(angle: (message.heading+180 /* Images point down */) * pi / 180.0,
      child:  CustomPaint(painter: _TrafficPainter(this)));
  }

  LatLng getCoordinates() {
    return message.coordinates;
  }

  @override
  String toString() {
    return "${message.callSign}\n${message.altitude.toInt()} ft\n"
    "${(message.velocity * 1.94384).toInt()} knots\n"
    "${(message.verticalSpeed * 3.28).toInt()} fpm";
  }

}




class TrafficCache {
  static const int maxEntries = 20;
  final List<Traffic?> _traffic = List.filled(maxEntries + 1, null); // +1 is the empty slot where new traffic is added

  double findDistance(LatLng coordinate, double altitude) {
    // find 3d distance between current position and airplane
    // treat 1 mile of horizontal distance as 500 feet of vertical distance (C182 120kts, 1000 fpm)
    LatLng current = Gps.toLatLng(Storage().position);
    double horizontalDistance = GeoCalculations().calculateDistance(current, coordinate) * 500;
    double verticalDistance   = (Storage().position.altitude * 3.28084 - altitude).abs();
    double fac = horizontalDistance + verticalDistance;
    return fac;
  }

  void putTraffic(TrafficReportMessage message) {

    // filter own report
    if(message.icao == Storage().myIcao) {
      // do not add ourselves
      return;
    }

    for(Traffic? traffic in _traffic) {
      int index = _traffic.indexOf(traffic);
      if(traffic == null) {
        continue;
      }
      if(traffic.isOld()) {
        _traffic[index] = null;
        // purge old
        continue;
      }

      // update
      if(traffic.message.icao == message.icao) {
        // call sign not available. use last one
        if(message.callSign.isEmpty) {
          message.callSign = traffic.message.callSign;
        }
        final Traffic trafficNew = Traffic(message);
        _traffic[index] = trafficNew;

        // process any audible alerts from traffic (if enabled)
        handleAudibleAlerts();

        return;
      }
    }

    // put it in the end
    final Traffic trafficNew = Traffic(message);
    _traffic[maxEntries] = trafficNew;

    // sort
    _traffic.sort(_trafficSort);

    // process any audible alerts from traffic (if enabled)
    handleAudibleAlerts();

  }

  int _trafficSort(Traffic? left, Traffic? right) {
    if(null == left && null != right) {
      return 1;
    }
    if(null != left && null == right) {
      return -1;
    }
    if(null == left && null == right) {
      return 0;
    }
    if(null != left && null != right) {
      double l = findDistance(left.message.coordinates, left.message.altitude);
      double r = findDistance(right.message.coordinates, right.message.altitude);
      if(l > r) {
        return 1;
      }
      if(l < r) {
        return -1;
      }
    }
    return 0;
  }

  void handleAudibleAlerts() {
    if (Storage().settings.isAudibleAlertsEnabled()) {
      AudibleTrafficAlerts.getAndStartAudibleTrafficAlerts().then((value) {
        // TODO: Set all of the "pref" settings from new Storage params (which in turn have a config UI?)
        value?.processTrafficForAudibleAlerts(_traffic, Storage().position, Storage().lastMsGpsSignal, Storage().vspeed, Storage().airborne);
      });
    } else {
      AudibleTrafficAlerts.stopAudibleTrafficAlerts();
    }
  }

  List<Traffic> getTraffic() {
    List<Traffic> ret = [];

    for(Traffic? check in _traffic) {
      if(null != check) {
        ret.add(check);
      }
    }
    return ret;
  }
}
