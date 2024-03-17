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
              CustomPaint(painter: TrafficPainter(true, .3, -1)),
              CustomPaint(painter: TrafficPainter(false, .8, -1)),
              CustomPaint(painter: TrafficPainter(false, 1.0, 1)),
              CustomPaint(painter: TrafficPainter(false, 1, 0)),
              CustomPaint(painter: TrafficPainter(true, .1, -1)) 
            ]
          )
        )
      )
    );
  }
}
*/

class TrafficPainter extends CustomPainter {

  final bool _isHeavy;
  final double _opacity;
  final double _highLowLevel;

  static double _computeFlightLevelOpacity(double trafficAltitude) {
    return min(.1, 

    );
  }

  TrafficPainter(Traffic traffic) 
    : _isHeavy = false /* TODO: get this from GDL90 message */, _opacity = _computeFlightLevelOpacity(traffic.message.altitude), _highLowLevel = traffic.message.verticalSpeed;

  // TODO: Do list for "colors" (alpha blend) of each of the flight levels
  static final Color _levelColor = const Color(0xFF000000);      // Black
  static final Color _highColor = const Color(0xFF1919D0);       // Mild dark blue
  static final Color _lowColor = const Color(0xFF00D000);        // Limish green
  static final Color _groundColor = const Color(0xFF836539);        // Brown
  static final Color _lightForegroundColor = const Color(0xFFFFFFFF); // White
  static final Color _darkForegroundColor = const Color(0xFF000000); // black




  static final ui.Path _heavyAircraft = ui.Path()
    ..addPolygon([ const Offset(0, 0), const Offset(15, 31), const Offset(16, 31), const Offset(31, 0), 
      const Offset(16, 4), const Offset(15, 4) ], true);  
  static final ui.Path _heavyAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(9, 6), const Offset(22, 6), const Offset(22, 7), const Offset(9, 7) ], true);
  static final ui.Path _heavyAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(15, 17), const Offset(15, 24), const Offset(16, 24), const Offset(16, 17) ], true)
    ..addPolygon([ const Offset(12, 20), const Offset(19, 20), const Offset(19, 21), const Offset(12, 21) ], true);    

  static final ui.Path _lightAircraft = ui.Path()
    ..addPolygon([ const Offset(4, 4), const Offset(15, 31), const Offset(16, 31), const Offset(27, 4),
      const Offset(16, 10), const Offset(15, 10) ], true);
  static final ui.Path _lightAircraftPlusSign = ui.Path()
    ..addPolygon([ const Offset(15, 17), const Offset(15, 24), const Offset(16, 24), const Offset(16, 17) ], true)
    ..addPolygon([ const Offset(12, 20), const Offset(19, 20), const Offset(19, 21), const Offset(12, 21) ], true);
  static final ui.Path _lightAircraftMinusSign = ui.Path()
    ..addPolygon([ const Offset(9, 11), const Offset(22, 11), const Offset(22, 12), const Offset(9, 12) ], true);


  /// TODO: Use an image cache to speed painting (premature opt?)
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
          Paint()..color = _highLowLevel >= 0 ? Color.fromRGBO(_lightForegroundColor.red, _lightForegroundColor.green, _lightForegroundColor.blue, _opacity)
            : Color.fromRGBO(_darkForegroundColor.red, _darkForegroundColor.green, _darkForegroundColor.blue, _opacity)
        );    
      } else {
        canvas.drawPath(
          _highLowLevel > 0 ? _lightAircraftPlusSign : _lightAircraftMinusSign,
          Paint()..color = _highLowLevel >= 0 ? Color.fromRGBO(_lightForegroundColor.red, _lightForegroundColor.green, _lightForegroundColor.blue, _opacity)
            : Color.fromRGBO(_darkForegroundColor.red, _darkForegroundColor.green, _darkForegroundColor.blue, _opacity)
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
    // return Transform.rotate(angle: message.heading * pi / 180,
    //     child: Container(
    //       decoration: BoxDecoration(
    //           borderRadius: BorderRadius.circular(5),
    //           color: Colors.black),
    //       child:const Icon(Icons.arrow_upward_rounded, color: Colors.white,)));
    return Transform.rotate(angle: (message.heading+180 /* Images point down */) * pi / 180.0,
      child:  CustomPaint(painter: TrafficPainter(false, .7, 1)));
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