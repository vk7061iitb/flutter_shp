import 'dart:typed_data';
import 'package:arcgis/data.dart';
import 'package:arcgis/dbf_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

Logger log = Logger();
Future<Map<String, dynamic>> loadData(
    String filepath, String dbfFilePath) async {
  ByteData data = await rootBundle.load(filepath);
  Uint8List shpByteData = data.buffer.asUint8List();
  int n = shpByteData.length;

  shpByteData = Uint8List(0);
  int fileCode = data.getInt32(0, Endian.big);
  log.i(fileCode);
  if (fileCode != 9994) {
    throw 'Invalid Shape file!';
  }
  int offset = 100;
  double xMin = data.getFloat64(36, Endian.little);
  double yMin = data.getFloat64(44, Endian.little);
  double xMax = data.getFloat64(52, Endian.little);
  double yMax = data.getFloat64(60, Endian.little);
  if (xMin >= xMax || yMin >= yMax) {
    throw 'Invalid bounds values!';
  }

  LatLngBounds bounds = LatLngBounds(
    LatLng(yMin, xMin),
    LatLng(yMax, xMax),
  );
  List<Polygon> tempPolygon = [];
  List<Polyline> tempPolyline = [];
  final DBFParser dbfParser = DBFParser();
  final header = await dbfParser.parseHeader(dbfFilePath);
  final records = await dbfParser.parseRecords(dbfFilePath, header);

  while (offset < n) {
    int recordNumber = data.getInt32(offset, Endian.big);
    int contentLength = data.getInt32(offset + 4, Endian.big);
    int shapeType = data.getInt32(offset + 8, Endian.little);
    int recordSizeInBytes = contentLength * 2;

    /// If polyline
    if (shapeType == 3) {
      int numParts = data.getInt32(offset + 44, Endian.little);
      int numPoints = data.getInt32(offset + 48, Endian.little);

      List<int> parts = [];
      for (int i = 0; i < numParts; i++) {
        int partIndex = data.getInt32(offset + 52 + (i * 4), Endian.little);
        parts.add(partIndex);
      }

      int pointsOffset = offset + 52 + (numParts * 4);
      List<LatLng> points = [];

      for (int i = 0; i < numPoints; i++) {
        double x = data.getFloat64(pointsOffset + (i * 16), Endian.little);
        double y = data.getFloat64(pointsOffset + (i * 16) + 8, Endian.little);
        points.add(LatLng(y, x));
      }
      tempPolyline.add(
        Polyline(
          points: points,
          strokeWidth: 3,
          color: Colors.red,
          hitValue: HitValue.from(records[recordNumber - 1]),
        ),
      );
    }

    /// If polygon
    if (shapeType == 5) {
      int numParts = data.getInt32(offset + 44, Endian.little);
      int numPoints = data.getInt32(offset + 48, Endian.little);

      List<int> parts = [];
      for (int i = 0; i < numParts; i++) {
        int partIndex = data.getInt32(offset + 52 + (i * 4), Endian.little);
        parts.add(partIndex);
      }

      int pointsOffset = offset + 52 + (numParts * 4);
      List<LatLng> allPoints = [];
      List<List<LatLng>> exterior = [];
      Map<int, List<List<LatLng>>> holesData = {};
      for (int i = 0; i < numPoints; i++) {
        double x = data.getFloat64(pointsOffset + (i * 16), Endian.little);
        double y = data.getFloat64(pointsOffset + (i * 16) + 8, Endian.little);
        allPoints.add(LatLng(y, x));
      }
      if (numParts == 1) {
        // Only one ring in the record noOfRecords = 0; need to check the direction
        exterior.add(allPoints);
      } else {
        // check the rotation of first part
        int rotation =
            findPolygonOrientation(allPoints.sublist(parts[0], parts[1]));
        int sign = 1;
        if (rotation == 1) {
          // anticlockwise
          sign = -1; // outer ring should be in clock-wise direction
        }
        for (int i = 0; i < numParts; i++) {
          int s = parts[i];
          int e = (i + 1 < parts.length) ? parts[i + 1] : allPoints.length;
          List<LatLng> ring = allPoints.sublist(s, e);
          int rot = sign * findPolygonOrientation(ring);
          if (rot == -1) {
            // CW -> exterior loop
            exterior.add(ring);
          } else {
            // ACW -> holes
            // this hole belong to the the most recent exterior ring

            for (int i = exterior.length - 1; i >= 0; i--) {
              if (ring
                  .any((point) => isPointInsidePolygon(point, exterior[i]))) {
                if (holesData.containsKey(i)) {
                  holesData[i]?.add(ring);
                } else {
                  holesData[i] = [ring];
                }
              }
            }
          }
        }
      }
      // add the polgons
      for (int i = 0; i < exterior.length; i++) {
        tempPolygon.add(
          Polygon(
            points: exterior[i],
            holePointsList: holesData[i] ?? const <List<LatLng>>[],
            borderColor: Colors.red,
            // ignore: deprecated_member_use
            color: Colors.red.withOpacity(0.25),
            borderStrokeWidth: 3,
            disableHolesBorder: false,
            hitValue: HitValue.from(records[recordNumber - 1]),
          ),
        );
      }
    }
    offset += 8 + recordSizeInBytes;
  }

  return {
    'polygons': tempPolygon,
    'polylines': tempPolyline,
    'bounds': bounds,
  };
}

class ShpData {
  List<OuterRing> polygons;
  List<ShpPolyline> polylines;
  LatLngBounds bounds;

  ShpData({
    required this.polygons,
    required this.polylines,
    required this.bounds,
  });
}

class ShpPolyline {
  List<LatLng> points;
  LatLngBounds bound;
  Map<String, dynamic> attributes;

  ShpPolyline({
    required this.points,
    required this.attributes,
    required this.bound,
  });
}

class OuterRing {
  List<LatLng> outerRingPoints;
  List<List<LatLng>> holes;
  LatLngBounds bound;
  Map<String, dynamic> attributes;
  OuterRing({
    required this.outerRingPoints,
    required this.holes,
    required this.bound,
    required this.attributes,
  });
}

/// Utility functions
bool isPointOnSegment(LatLng p, LatLng a, LatLng b) {
  // Check if the point is collinear with the segment (cross product should be 0)
  double crossProduct =
      (p.latitude - a.latitude) * (b.longitude - a.longitude) -
          (p.longitude - a.longitude) * (b.latitude - a.latitude);
  if (crossProduct != 0) return false;

  // Check if the point lies within the bounds of the segment
  return (p.longitude >= a.longitude && p.longitude <= b.longitude ||
          p.longitude >= b.longitude && p.longitude <= a.longitude) &&
      (p.latitude >= a.latitude && p.latitude <= b.latitude ||
          p.latitude >= b.latitude && p.latitude <= a.latitude);
}

bool isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
  int n = polygon.length;

  // If polygon has less than 3 vertices, it's not a valid polygon
  if (n < 3) return false;

  bool inside = false;
  double px = point.longitude;
  double py = point.latitude;

  // Iterate over each edge of the polygon
  for (int i = 0, j = n - 1; i < n; j = i++) {
    double xi = polygon[i].longitude, yi = polygon[i].latitude;
    double xj = polygon[j].longitude, yj = polygon[j].latitude;

    // Check if the point is on the edge (on the line segment)
    if (isPointOnSegment(point, polygon[i], polygon[j])) {
      return false; // Exclude points on the edge
    }

    // Check if the point is on the same level as the edge
    bool intersect = ((yi > py) != (yj > py)) &&
        (px < (xj - xi) * (py - yi) / (yj - yi) + xi);

    if (intersect) inside = !inside;
  }

  return inside;
}

int findPolygonOrientation(List<LatLng> points) {
  int n = points.length;
  if (n < 3) return -2;
  double sum = 0.0;
  for (int i = 0; i < n; i++) {
    LatLng current = points[i];
    LatLng next = points[(i + 1) % n]; // Wrap around to the first vertex
    sum += (next.longitude - current.longitude) *
        (next.latitude + current.latitude);
  }

  if (sum > 0) {
    return 1; // counter-clockwise
  } else if (sum < 0) {
    return -1; // clockwise
  } else {
    return 0; // degenerate
  }
}
