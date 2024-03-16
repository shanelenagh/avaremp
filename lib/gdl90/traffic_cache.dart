import 'dart:core';
import 'dart:ui' as ui;
import 'package:avaremp/gdl90/traffic_report_message.dart';
import 'package:avaremp/geo_calculations.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:avaremp/gdl90/audible_traffic_alerts.dart';

import '../gps.dart';

void main()  {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
            children: [ 
              CustomPaint(painter: _TrafficPainter(true, .1, 1)),
              CustomPaint(painter: _TrafficPainter(false, .8, -1)),
              CustomPaint(painter: _TrafficPainter(false, 1.0, 1)),
              CustomPaint(painter: _TrafficPainter(false, 1, 0)),
              CustomPaint(painter: _TrafficPainter(true, .1, -1)) 
            ]
          )
        )
      )
    );
  }
}

class _TrafficPainter extends CustomPainter {

  final bool _isHeavy;
  final double _opacity;
  final int _highLowLevel;

  _TrafficPainter(bool isHeavy, double opacity, int highLowLevel) 
    : _isHeavy = isHeavy, _opacity = opacity, _highLowLevel = highLowLevel;

  static final Color _levelColor = const Color(0xFF000000);      // Black
  static final Color _highColor = const Color(0xFF1919D0);       // Mild dark blue
  static final Color _lowColor = const Color(0xFF00AD00);        // Limish green
  static final Color _foregroundColor = const Color(0xFFFFFFFF); // White

  static final ui.Path _lightAircraft = ui.Path()
    ..addPolygon([ const Offset(0, 0), const Offset(8, 20), const Offset(16, 0), const Offset(8, 8) ], true);
  static final ui.Path _heavyAircraft = ui.Path()
    ..addPolygon([ const Offset(0, 0), const Offset(12, 24), const Offset(24, 0), const Offset(12, 3) ], true);  
  static final ui.Path _lightAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(7, 9), const Offset(9, 9), const Offset(9, 14), const Offset(7, 14) ], true)
    ..addPolygon([ const Offset(5, 11), const Offset(11, 11), const Offset(11, 12), const Offset(5, 12) ], true);
  static final ui.Path _lightAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(5, 9), const Offset(11, 9), const Offset(11, 11), const Offset(5, 11) ], true);
  static final ui.Path _heavyAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(6, 6), const Offset(18, 6), const Offset(18, 8), const Offset(6, 8) ], true);
  static final ui.Path _heavyAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(11, 10), const Offset(13, 10), const Offset(13, 20), const Offset(11, 20) ], true)
    ..addPolygon([ const Offset(9, 14), const Offset(15, 14), const Offset(15, 16), const Offset(9, 16) ], true);    

  @override paint(Canvas canvas, Size size) {
    final Color acColor;
    if (_highLowLevel > 0) {
      acColor = Color.fromRGBO(_highColor.red, _highColor.green, _highColor.blue, _opacity);
    } else if (_highLowLevel < 0) {
      acColor = Color.fromRGBO(_lowColor.red, _lowColor.green, _lowColor.blue, _opacity);
    } else {
      acColor = Color.fromRGBO(_levelColor.red, _levelColor.green, _levelColor.blue, _opacity);
    }
    canvas.drawPath(
      _isHeavy ? _heavyAircraft : _lightAircraft,
      Paint()..color = acColor
    );
    if (_highLowLevel != 0) {
      if (_isHeavy) {
        canvas.drawPath(
          _highLowLevel > 0 ? _heavyAircraftPlusSign : _heavyAircraftMinusSign,
          Paint()..color = Color.fromRGBO(_foregroundColor.red, _foregroundColor.green, _foregroundColor.blue, _opacity)
        );    
      } else {
        canvas.drawPath(
          _highLowLevel > 0 ? _lightAircraftPlusSign : _lightAircraftMinusSign,
          Paint()..color = Color.fromRGBO(_foregroundColor.red, _foregroundColor.green, _foregroundColor.blue, _opacity)
        ); 
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
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
    return Transform.rotate(angle: message.heading * pi / 180,
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.black),
          child:const Icon(Icons.arrow_upward_rounded, color: Colors.white,)));
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
        final Storage storage = Storage();
        value?.processTrafficForAudibleAlerts(_traffic, storage.position, storage.lastMsGpsSignal, storage.vspeed, storage.airborne);
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