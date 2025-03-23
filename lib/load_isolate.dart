import 'dart:typed_data';
import 'package:arcgis/dbf_reader.dart';
import 'package:arcgis/models/shp_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';

Logger log = Logger();
Future<Map<String, dynamic>> loadNreadeData(
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
  log.i("s: $yMin, $xMin ||  n: $yMax, $xMax");
  LatLngBounds bounds = LatLngBounds(
    southwest: LatLng(yMin, xMin),
    northeast: LatLng(yMax, xMax),
  );
  Set<Polygon> tempPolygon = {};
  Set<Polyline> tempPolyline = {};
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
          polylineId: PolylineId("$offset"),
          points: points,
          width: 2,
          color: Colors.red,
          consumeTapEvents: true,
          onTap: () {
            Get.bottomSheet(
              PopScope(
                canPop: true,
                onPopInvokedWithResult: (didPop, result) {},
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            records[recordNumber - 1].entries.map((entry) {
                          return ListBody(
                            children: [
                              Text(
                                entry.key.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.value.toString(),
                                overflow: TextOverflow.fade,
                                softWrap: true,
                              ),
                              const Divider(
                                color: Colors.black26,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
            polygonId: PolygonId("$i$offset"),
            points: exterior[i],
            holes: holesData[i] ?? const <List<LatLng>>[],
            fillColor: Colors.red.shade200,
            strokeColor: Colors.red,
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () {
              Get.bottomSheet(
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            records[recordNumber - 1].entries.map((entry) {
                          return ListBody(
                            children: [
                              Text(
                                entry.key.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.value.toString(),
                                overflow: TextOverflow.fade,
                                softWrap: true,
                              ),
                              const Divider(
                                color: Colors.black26,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
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

/// [TO DO]
PolyLine getPolylineData({
  required int shpOffset,
  required ByteData shpData,
}) {
  double xMin = shpData.getFloat64(shpOffset + 12, Endian.little);
  double yMin = shpData.getFloat64(shpOffset + 20, Endian.little);
  double xMax = shpData.getFloat64(shpOffset + 28, Endian.little);
  double yMax = shpData.getFloat64(shpOffset + 36, Endian.little);
  LatLngBounds box = LatLngBounds(
    southwest: LatLng(yMin, xMin),
    northeast: LatLng(yMax, xMax),
  );
  int m = shpData.getInt32(shpOffset + 44, Endian.little); // no. of parts
  int n = shpData.getInt32(shpOffset + 48, Endian.little); // no. of points
  List<int> parts = List.filled(m, 0, growable: false);

  for (int i = 0; i < m; i++) {
    int byteOffset = shpOffset + 52 + i * 4;
    parts[i] = shpData.getInt32(byteOffset, Endian.little);
  }

  int pointsOffset = shpOffset + 52 + m * 4;
  List<LatLng> points = List.filled(n, const LatLng(0, 0));

  for (int i = 0; i < n; i++) {
    int lngOffset = pointsOffset + (i * 16); // x
    int latOffset = pointsOffset + (i * 16) + 8; // y
    points[i] = LatLng(
      shpData.getFloat64(latOffset, Endian.little), // latitude
      shpData.getFloat64(lngOffset, Endian.little), // longitude
    );
  }
  // calculate attributes

  return PolyLine(
    box: box,
    numParts: m,
    numPoints: n,
    parts: parts,
    points: points,
    attributes: {"name": "polyline"},
  );
}
