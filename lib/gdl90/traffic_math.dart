library traffic_math;

import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:geolocator/geolocator.dart';


const double _kMetersPerNauticalMile = 1852.000;

double _relativeBearingFromHeadingAndLocations(final double lat1, final double long1,
                            final double lat2, final double long2,  final double myBearing)
{
  return (Geolocator.bearingBetween(lat1, long1, lat2, long2) - myBearing + 360) % 360;
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

Position locationAfterTime(final double lat, final double lon, final double heading, final double velocityInKt, 
  final double timeInHrs, final double altInFeet, final double vspeedInFpm) 
{
    final double newLat =  lat + cos(radians(heading)) * (velocityInKt/60.00000) * timeInHrs;
    return Position (
      latitude: newLat,
      longitude: lon + sin(radians(heading))
              // Again, use cos of average lat to give some weighting based on shorter intra-lon distance changes at higher latitudes
              * (velocityInKt / (60.00000*cos(radians((newLat+lat)/2.0000))))
              * timeInHrs,
      altitude: altInFeet + (vspeedInFpm * (60.0 * timeInHrs)),
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 0,
      speed: velocityInKt,
      speedAccuracy: 0,
      accuracy: 0,
      timestamp: DateTime.now()
    );
}