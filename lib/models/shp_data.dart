import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolyLine {
  LatLngBounds box;
  int numParts;
  int numPoints;
  List<int> parts;
  List<LatLng> points;
  Map<String, dynamic> attributes;

  PolyLine({
    required this.box,
    required this.numParts,
    required this.numPoints,
    required this.parts,
    required this.points,
    required this.attributes,
  });
}

class PolyGon {
  LatLngBounds box;
  int numParts;
  int numPoints;
  List<int> parts;
  Ring ring;
  Map<String, dynamic> attributes;

  PolyGon({
    required this.box,
    required this.numParts,
    required this.numPoints,
    required this.parts,
    required this.ring,
    required this.attributes,
  });
}

class Ring {
  List<LatLng> exterior;
  List<List<LatLng>> interior;

  Ring({
    required this.exterior,
    required this.interior,
  });
}

enum ShapeType {
  nullShape,
  point,
  polyLine,
  polygon,
  multiPoint,
  pointZ,
  polyLineZ,
  polygonZ,
  multiPointZ,
  pointM,
  polyLineM,
  polygonM,
  multiPointM,
  multiPatch,
}

Map<int, ShapeType> shapeTypeMap = {
  0: ShapeType.nullShape,
  1: ShapeType.point,
  3: ShapeType.polyLine,
  5: ShapeType.polygon,
  8: ShapeType.multiPoint,
  11: ShapeType.pointZ,
  13: ShapeType.polyLineZ,
  15: ShapeType.polygonZ,
  18: ShapeType.multiPointZ,
  21: ShapeType.pointM,
  23: ShapeType.polyLineM,
  25: ShapeType.polygonM,
  28: ShapeType.multiPointM,
  31: ShapeType.multiPatch,
};
