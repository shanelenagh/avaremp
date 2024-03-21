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

const double _kDivBy180 = 1.0 / 180.0;


void main()  {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static List<Widget> _buildTrafficPainters() {
    TrafficReportMessage m1 = TrafficReportMessage(20);
    m1.altitude = 500;
    m1.coordinates = const LatLng(41.2565, 95.9345);
    m1.emitter = 7;
    m1.airborne = true;
    m1.velocity = 0;
    m1.verticalSpeed = 100;
    Traffic highDescendingRotor = Traffic(m1);

    TrafficReportMessage m2 = TrafficReportMessage(20);
    m2.altitude = -1000;
    m2.coordinates = const LatLng(41.2565, 95.9345);
    m2.emitter = 3;
    m2.airborne = true;
    m2.velocity = 0;
    m2.verticalSpeed = -200;
    Traffic lowAscendingHeavy = Traffic(m2);   

    TrafficReportMessage m3 = TrafficReportMessage(20);
    m3.altitude = 30;
    m3.coordinates = const LatLng(41.2565, 95.9345);
    m3.emitter = 2;
    m3.airborne = true;
    m3.velocity = 0;
    m3.verticalSpeed = 300;
    Traffic sameAltAscMedium = Traffic(m3);   

    TrafficReportMessage m4 = TrafficReportMessage(20);
    m4.altitude = 0;
    m4.coordinates = const LatLng(41.2565, 95.9345);
    m4.emitter = 1;
    m4.airborne = true;
    m4.velocity = 0;
    m4.verticalSpeed = 200;
    Traffic lowAscendingLight = Traffic(m4); 

    TrafficReportMessage m5 = TrafficReportMessage(20);
    m5.altitude = -500;
    m5.coordinates = const LatLng(41.2565, 95.9345);
    m5.emitter = 0;
    m5.airborne = true;
    m5.velocity = 0;
    m5.verticalSpeed = 200;
    Traffic lowAscendingUnknown = Traffic(m5);     
          
    return [
      Transform.scale(scale: 1, 
        child: CustomPaint(
          painter: _TrafficPainter(lowAscendingLight))),      
      // Transform.scale(scale: 3, 
      //   child: CustomPaint(          
      //     painter: _TrafficPainter(sameAltAscMedium))),
      Transform.scale(scale: 1, 
        child: CustomPaint(          
          painter: _TrafficPainter(lowAscendingHeavy))),
      Transform.scale(scale: 1, 
        child: CustomPaint(
          painter: _TrafficPainter(highDescendingRotor))),
      Transform.scale(scale: 1, 
        child: CustomPaint(
          painter: _TrafficPainter(lowAscendingUnknown))),                                
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
          /*
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/OmaSecClip.png"),
              fit: BoxFit.cover
            )
          ),
          */
          constraints: const BoxConstraints.expand(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildTrafficPainters()
          )
        )
      )
    );
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
    //      child: Container(
    //        decoration: BoxDecoration(
    //            borderRadius: BorderRadius.circular(5),
    //            color: Colors.black),
    //        child:const Icon(Icons.arrow_upward_rounded, color: Colors.white,)));
    return Transform.rotate(angle: (message.heading + 180.0 /* Image painted down on coordinate plane */) * pi  * _kDivBy180,
      child: CustomPaint(painter: _TrafficPainter(this)));
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

enum _TrafficAircraftType { regular, light, large, medium, rotorcraft }

/// Icon painter for different traffic aircraft (ADSB emitter) types, and graduated opacity for vertically distant traffic
class _TrafficPainter extends CustomPainter {

  // Const's for magic #'s and division speedup
  static const double _kMetersToFeetCont = 3.28084;
  static const double _kMetersPerSecondToKnots = 1.94384;
  static const double _kDivBy60Mult = 1.0 / 60.0;
  static const double _kDivBy1000Mult = 1.0 / 1000.0;
  // Colors for different aircraft heights, and contrasting overlays
  static const Color _levelColor = Color(0xFF505050);           // Level traffic = Dark grey
  static const Color _highColor = Color(0xFF2940FF);            // High traffic = Mild dark blue
  static const Color _lowColor = Color(0xFF50D050);             // Low traffic = Limish green
  static const Color _groundColor = Color(0xFF836539);          // Ground traffic = Brown
  static const Color _lightForegroundColor = Color(0xFFFFFFFF); // Overlay for darker backgrounds = White
  static const Color _darkForegroundColor = Color(0xFF000000);  // Overlay for light backgrounds = Black

  // Aircraft type outlines
  static final ui.Path _largeAircraft = ui.Path()
    // body
    ..addOval(const Rect.fromLTRB(12, 5, 19, 31))
    ..addRect(const Rect.fromLTRB(12, 9, 19, 20))..addRect(const Rect.fromLTRB(12, 9, 19, 20))
    ..addOval(const Rect.fromLTRB(12, 0, 19, 25))..addOval(const Rect.fromLTRB(12, 0, 19, 25)) 
    // left wing
    ..addPolygon([ const Offset(0, 13), const Offset(0, 16), const Offset(13, 22), const Offset(12, 14) ], true) 
    ..addPolygon([ const Offset(0, 13), const Offset(0, 16), const Offset(13, 22), const Offset(12, 14) ], true) 
    // left engine
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(6, 17, 10, 23), const Radius.circular(1)))  
    // left h-stabilizer
    ..addPolygon([ const Offset(9, 0), const Offset(9, 3), const Offset(15, 6), const Offset(15, 1) ], true) 
    // right wing
    ..addPolygon([ const Offset(31, 13), const Offset(31, 16), const Offset(19, 22), const Offset(19, 14) ], true) 
    ..addPolygon([ const Offset(31, 13), const Offset(31, 16), const Offset(19, 22), const Offset(19, 14) ], true) 
    // right engine
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(21, 17, 25, 23), const Radius.circular(1)))  
    // right h-stabilizer
    ..addPolygon([ const Offset(22, 0), const Offset(22, 3), const Offset(16, 6), const Offset(16, 1) ], true)     
  ;
  static final ui.Path _mediumAircraft = ui.Path()
    ..addPolygon([ const Offset(3, 3), const Offset(15, 31), const Offset(16, 31), const Offset(28, 3), 
      const Offset(16, 5), const Offset(15, 5) ], true);        
  static final ui.Path _regularSmallAircraft = ui.Path()
    ..addPolygon([ const Offset(4, 4), const Offset(15, 31), const Offset(16, 31), const Offset(27, 4),
      const Offset(16, 10), const Offset(15, 10) ], true);
  static final ui.Path _lightAircraft = ui.Path()
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(13, 13, 18, 30), const Radius.circular(2))) //(const Rect.fromLTRB(13, 13, 18, 30)) // body
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(4, 15, 27, 22), const Radius.circular(1))) // wings
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(11, 7, 20, 11), const Radius.circular(1)))  // h-stabilizer
    ..addPolygon([ const Offset(13, 16), const Offset(14, 7), const Offset(17, 7), const Offset(18, 16)], true); // rear body
  static final ui.Path _rotorcraft = ui.Path()
    ..addOval(const Rect.fromLTRB(9, 11, 22, 31))
    ..addPolygon([const Offset(29, 11), const Offset(31, 13), const Offset(2, 31), const Offset(0, 29)], true)
    ..addPolygon([const Offset(29, 11), const Offset(31, 13), const Offset(2, 31), const Offset(0, 29)], true)
    ..addPolygon([const Offset(2, 11), const Offset(0, 13), const Offset(29, 31), const Offset(31, 29) ], true)
    ..addPolygon([const Offset(2, 11), const Offset(0, 13), const Offset(29, 31), const Offset(31, 29) ], true) // and again, to force opaque at inersection
    ..addRect(const Rect.fromLTRB(15, 0, 16, 12))
    ..addRRect(RRect.fromLTRBR(10, 3, 21, 7, const Radius.circular(1))); //(const Rect.fromLTRB(10, 3, 21, 7));       
  // vertical speed plus/minus overlays
  static final ui.Path _plusSign = ui.Path()
    ..addPolygon([ const Offset(14, 14), const Offset(14, 23), const Offset(17, 23), const Offset(17, 14) ], true)
    ..addPolygon([ const Offset(11, 17), const Offset(20, 17), const Offset(20, 20), const Offset(11, 20) ], true)
    ..addPolygon([ const Offset(11, 17), const Offset(20, 17), const Offset(20, 20), const Offset(11, 20) ], true);  // and again, to force opaque at inersection
  static final ui.Path _minusSign = ui.Path()
    ..addPolygon([ const Offset(11, 16), const Offset(20, 16), const Offset(20, 19), const Offset(11, 19) ], true);
 

  final _TrafficAircraftType _aircraftType;
  final bool _isAirborne;
  final int _flightLevelDiff;
  final int _vspeedDirection;
  final int _velocityLevel;

  _TrafficPainter(Traffic traffic) 
    : _aircraftType = _getAircraftType(traffic.message.emitter), 
      _isAirborne = traffic.message.airborne,
      _flightLevelDiff = _getFlightLevelDiff(traffic.message.altitude), 
      _vspeedDirection = _getVerticalSpeedDirection(traffic.message.verticalSpeed),
      _velocityLevel = _getVelocityLevel(traffic.message.velocity*_kMetersPerSecondToKnots);

  /// Paint arcraft, vertical speed direction overlay, and (horizontal) speed barb
  @override paint(Canvas canvas, Size size) {
    // Decide opacity, based on vertical distance from ownship and whether traffic is on the ground. 
    // Traffic far above or below ownship will be quite transparent, to avoid clutter, and 
    // ground traffic has a 50% max opacity / min transparency to avoid taxiing or stationary (ADSB-initilized)
    // traffic from flooding the map. Opacity decrease is 20% for every 1000 foot diff above or below, with a 
    // floor of 20% total opacity (i.e., max 80% transparency)
    final double opacity = min(max(.2, (_isAirborne ? 1.0 : 0.5) - _flightLevelDiff.abs() * 0.2), (_isAirborne ? 1.0 : 0.5));
    // Define colors using above opacity, with contrasting colors for above, level, below, and ground
    final Color aircraftColor;
    if (!_isAirborne) {
      aircraftColor = Color.fromRGBO(_groundColor.red, _groundColor.green, _groundColor.blue, opacity);
    } else if (_flightLevelDiff > 0) {
      aircraftColor = Color.fromRGBO(_highColor.red, _highColor.green, _highColor.blue, opacity);
    } else if (_flightLevelDiff < 0) {
      aircraftColor = Color.fromRGBO(_lowColor.red, _lowColor.green, _lowColor.blue, opacity);
    } else {
      aircraftColor = Color.fromRGBO(_levelColor.red, _levelColor.green, _levelColor.blue, opacity);
    }
    final Color vspeedOverlayColor;
    if (_flightLevelDiff >= 0) {
      vspeedOverlayColor = Color.fromRGBO(_lightForegroundColor.red, _lightForegroundColor.green, _lightForegroundColor.blue, opacity);
    } else {
      vspeedOverlayColor = Color.fromRGBO(_darkForegroundColor.red, _darkForegroundColor.green, _darkForegroundColor.blue, opacity);
    }

    // Set aircraft shape
    final ui.Path aircraftShape;
    switch(_aircraftType) {
      case _TrafficAircraftType.light:
        aircraftShape = _lightAircraft;
        break;  
      case _TrafficAircraftType.medium:
        aircraftShape = _mediumAircraft;
        break;             
      case _TrafficAircraftType.large:
        aircraftShape = _largeAircraft;
        break;
      case _TrafficAircraftType.rotorcraft:
        aircraftShape = _rotorcraft;
        break;
      default:
        aircraftShape = _regularSmallAircraft;
    }
    
    // Set speed barb
    final ui.Path speedBarb = ui.Path()
      ..addRect(Rect.fromLTWH(14, 29, 3, _velocityLevel*2.0))
      ..addRect(Rect.fromLTWH(14, 29, 3, _velocityLevel*2.0)); // second time to prevent alias transparency interaction

    // Draw aircraft and speed barb in one shot (saves rendering time/resources)
    aircraftShape.addPath(speedBarb, const Offset(0,0));
    canvas.drawPath(aircraftShape, Paint()..color = aircraftColor);

    // draw vspeed overlay (if not level)
    if (_vspeedDirection != 0) {
      canvas.drawPath(
        _vspeedDirection > 0 ? _plusSign : _minusSign,
        Paint()..color = vspeedOverlayColor
      );    
    }      
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter oldDelegate) {
    return _flightLevelDiff != oldDelegate._flightLevelDiff || _velocityLevel != oldDelegate._velocityLevel 
      ||_vspeedDirection != oldDelegate._vspeedDirection || _isAirborne != oldDelegate._isAirborne;
  }

  @pragma("vm:prefer-inline")
  static _TrafficAircraftType _getAircraftType(int adsbEmitterCategoryId) {
    switch(adsbEmitterCategoryId) {
      case 1: // Light
      case 2: // Small
        return _TrafficAircraftType.light;
      case 3: // Large - 75,000 to 300,000 lbs
      case 4: // High Vortex Large (e.g., aircraft such as B757) 
      case 5: // Heavy (ICAO) - > 300,000 lbs
        return _TrafficAircraftType.large;
      case 7: // Rotorcraft 
        return _TrafficAircraftType.rotorcraft;
      default:
        return _TrafficAircraftType.regular;
    }
  }

  @pragma("vm:prefer-inline")
  static int _getFlightLevelDiff(double trafficAltitude) {
    return ((trafficAltitude - Storage().position.altitude.abs() * _kMetersToFeetCont) * _kDivBy1000Mult).round();
  }

  @pragma("vm:prefer-inline")
  static int _getVerticalSpeedDirection(double verticalSpeed) {
    if (verticalSpeed*_kMetersToFeetCont < -100) {
      return -1;
    } else if (verticalSpeed*_kMetersToFeetCont > 100) {
      return 1;
    } else {
      return 0;
    }
  }

  @pragma("vm:prefer-inline")
  static int _getVelocityLevel(double veloMps) {
    return (veloMps * _kMetersPerSecondToKnots * _kDivBy60Mult).round();
  }  
}