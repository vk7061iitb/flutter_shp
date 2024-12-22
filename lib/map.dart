import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'load_isolate.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

int fileCode = 0;
late GoogleMapController _mapController;
Set<Polygon> polygon = {};
Set<Polyline> polyline = {};
Set<ClusterManager> clusterManager = {};
Logger logger = Logger();
LatLngBounds bounds =
    LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));

String selectedFile = 'india_ds.shp'; // Default file
List<String> fileList = [
  'cb_2018_us_aiannh_500k.shp',
  'tl_2024_us_aiannh.shp',
  'cb_2018_us_state_500k.shp',
  'cb_2018_us_necta_500k.shp',
  'ne_110m_admin_1_states_provinces.shp',
  'india_ds.shp',
  'tl_2024_04001_areawater.shp',
  'tl_2024_50_sdadm.shp'
];

Future<void> readNplot(String filename) async {
  String dbfFilePath = filename.replaceAll('.shp', '.dbf');
  try {
    Map<String, dynamic> res =
        await loadNreadeData('lib/$filename', 'lib/$dbfFilePath');
    polygon = res['polygons'];
    polyline = res['polylines'];
    bounds = res['bounds'];

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  } catch (e, s) {
    logger.e("Error : $e");
    logger.i("StackTrace: $s");
  }
}

class _MapPageState extends State<MapPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readNplot(selectedFile);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            child: const Text("Refresh"),
            onPressed: () async {
              setState(() {});
            },
          ),
          FloatingActionButton(
            child: const Text("Plot"),
            onPressed: () async {
              readNplot(selectedFile);
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<String>(
                    value: selectedFile,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedFile = newValue;
                          readNplot(selectedFile); // Load new data on change
                        });
                      }
                    },
                    items:
                        fileList.map<DropdownMenuItem<String>>((String file) {
                      return DropdownMenuItem<String>(
                        value: file,
                        child: Text(file),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(0, 0),
                    ),
                    polygons: polygon,
                    polylines: polyline,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _mapController.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 10),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
