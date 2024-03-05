import 'dart:typed_data';
import 'package:avaremp/gdl90/ownship_message.dart';
import 'package:latlong2/latlong.dart';

import 'message.dart';

class TrafficReportMessage extends Message {
  double altitude = -305;
  LatLng coordinates = const LatLng(0, 0);
  int icao = 0;
  double velocity = 0;
  double verticalSpeed = 0;
  double heading = 0;
  String callSign = "";
  bool isAirborne = false;

  TrafficReportMessage(super.type);

  @override
  void parse(Uint8List message) {

    icao = (((message[1]).toInt() & 0xFF) << 16) + ((((message[2].toInt()) & 0xFF) << 8)) + (((message[3].toInt()) & 0xFF));
    double lat = OwnShipMessage.calculateDegrees((message[4].toInt() & 0xFF), (message[5].toInt() & 0xFF), (message[6].toInt() & 0xFF));
    double lon = OwnShipMessage.calculateDegrees((message[7].toInt() & 0xFF), (message[8].toInt() & 0xFF), (message[9].toInt() & 0xFF));
    coordinates = LatLng(lat, lon);

    int upper = ((message[10].toInt() & 0xFF)) << 4;
    int lower = ((message[11].toInt() & 0xF0)) >> 4;
    int alt = upper + lower;
    if (alt != 0xFFF) {
      alt *= 25;
      alt -= 1000;
      if (alt < -1000) {
        alt = -1000;
      }
    }
    altitude = alt.toDouble();

    isAirborne = (message[11] & 0x08) != 0;

    upper = ((message[13].toInt() & 0xFF)) << 4;
    lower = ((message[14].toInt() & 0xF0)) >> 4;

    if (upper == 0xFF0 && lower == 0xF) {
    }
    else {
      // knots
      velocity = ((upper.toDouble() + lower.toDouble()) * 0.514444);
    }

    // vs
    if ((message[14].toInt() & 0x08) == 0) {
      verticalSpeed = ((message[14].toInt() & 0x0F) << 14) + ((message[15].toInt() & 0xFF) << 6).toDouble();
    }
    else if (message[15].toInt() == 0) {
      verticalSpeed = 2000000000;
    }
    else {
      verticalSpeed = (((message[14].toInt() & 0x0F) << 14) + ((message[15].toInt() & 0xFF) << 6) - 0x40000).toDouble();
    }

    // heading / track
    heading = ((message[16].toInt() & 0xFF).toDouble() * 1.40625); // heading resolution 1.40625

    // call sign from 18 to 25
    Uint8List call = message.sublist(18, 26);
    callSign = String.fromCharCodes(call).replaceAll(' ', '');

  }

}
