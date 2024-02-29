library traffic_math;

import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:geolocator/geolocator.dart';


const double _kMetersPerNauticalMile = 1852.000;

// double _angleFromCoordinate(final double lat1, final double long1, final double lat2, final double long2) 
// {
//   final double lat1Rad = radians(lat1);
//   final double long1Rad = radians(long1);
//   final double lat2Rad = radians(lat2);
//   final double long2Rad = radians(long2);

//   final double dLon = (long2Rad - long1Rad);

//   final double y = sin(dLon) * cos(lat2Rad);
//   final double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad)
//           * cos(lat2Rad) * cos(dLon);

//   final double bearingRad = atan2(y, x);

//   return  (degrees(bearingRad) + 360) % 360;
// }

double _relativeBearingFromHeadingAndLocations(final double lat1, final double long1,
                            final double lat2, final double long2,  final double myBearing)
{
  return (/*_angleFromCoordinate*/Geolocator.bearingBetween(lat1, long1, lat2, long2) - myBearing + 360) % 360;
}

int nearestClockHourFromHeadingAndLocations(
        final double lat1, final double long1, final double lat2, final double long2, final double myBearing)
{
  final int nearestClockHour = (_relativeBearingFromHeadingAndLocations(lat1, long1, lat2, long2, myBearing)/30.0).round();
  return nearestClockHour != 0 ? nearestClockHour : 12;
}

/**
 * Great circle distance between two lat/lon's via Haversine formula, Java impl courtesy of https://introcs.cs.princeton.edu/java/12types/GreatCircle.java.html
 * @param lat1 Latitude 1
 * @param lon1 Longitude 1
 * @param lat2 Latitude 2
 * @param lon2 Longitude 2
 * @return Great circle distance between two points in nautical miles
 */
double greatCircleDistanceNmi(final double lat1, final double lon1, final double lat2, final double lon2) 
{
  // final double x1 = radians(lat1);
  // final double y1 = radians(lon1);
  // final double x2 = radians(lat2);
  // final double y2 = radians(lon2);

  // /*
  //   * Compute using Haversine formula
  //   */
  // final double a = pow(sin((x2-x1)/2), 2)
  //         + cos(x1) * cos(x2) * pow(sin((y2-y1)/2), 2);

  // // great circle distance in radians
  // final double angle2 = 2.0 * asin(min(1, sqrt(a)));

  // // convert back to degrees, and each degree on a great circle of Earth is 60 nautical miles
  // return 60.0 * degrees(angle2);
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / _kMetersPerNauticalMile;
}

/**
 * Time to closest approach between two 2-d kinematic vectors; credit to: https://math.stackexchange.com/questions/1775476/shortest-distance-between-two-objects-moving-along-two-lines
 * @param lat1 Latitude 1
 * @param lon1 Longitude 2
 * @param lat2 Latitude 2
 * @param lon2 Longitude 2
 * @param heading1 Heading 1
 * @param heading2 Heading 2
 * @param velocity1 Velocity 1
 * @param velocity2 Velocity 2
 * @return Time (in units of velocity) of closest point of approach
 */
double closestApproachTime(final double lat1, final double lon1, final double lat2, final double lon2,
                                        final double heading1, final double heading2, final int velocity1, final int velocity2)
{
  // Use cosine of average of two latitudes, to give some weighting for lesser intra-lon distance at higher latitudes
  final double a = (lon2 - lon1) * (60.0000 * cos(radians((lat1+lat2)/2.0000)));
  final double b = velocity2*sin(radians(heading2)) - velocity1*sin(radians(heading1));
  final double c = (lat2 - lat1) * 60.0000;
  final double d = velocity2*cos(radians(heading2)) - velocity1*cos(radians(heading1));

  return - ((a*b + c*d) / (b*b + d*d));
}

List<double> locationAfterTime(final double lat, final double lon, final double heading, final double velocityInKt, 
  final double timeInHrs, final double altInFeet, final double vspeedInFpm) 
{
    final double newLat =  lat + cos(radians(heading)) * (velocityInKt/60.00000) * timeInHrs;
    return [
      newLat,
      lon + sin(radians(heading))
              // Again, use cos of average lat to give some weighting based on shorter intra-lon distance changes at higher latitudes
              * (velocityInKt / (60.00000*cos(radians((newLat+lat)/2.0000))))
              * timeInHrs,
      altInFeet + (vspeedInFpm * (60.0 * timeInHrs))
    ];
}