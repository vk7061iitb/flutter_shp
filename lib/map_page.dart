import 'package:arcgis/load.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import 'data.dart';

class MapPage2 extends StatefulWidget {
  const MapPage2({super.key});

  @override
  State<MapPage2> createState() => _MapPage2State();
}

class _MapPage2State extends State<MapPage2> {
  int fileCode = 0;
  final MapController _mapController = MapController();
  List<Polygon> polygontoshow = [];
  List<Polyline> polylinetoshow = [];
  Logger logger = Logger();
  LatLngBounds bounds = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
  LatLngBounds b = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
  String selectedFile = 'india_ds.shp'; // Default file
  List<String> fileList = [
    'cb_2018_us_aiannh_500k.shp',
    'cb_2018_us_state_500k.shp',
    'cb_2018_us_necta_500k.shp',
    'ne_110m_admin_1_states_provinces.shp',
    'india_ds.shp',
    'tl_2024_04001_areawater.shp',
    'tl_2024_50_sdadm.shp',
    'tl_2024_55_prisecroads.shp',
    'tl_2019_12061_roads.shp'
  ];
  final LayerHitNotifier _hitNotifier = ValueNotifier(null);

  Future<void> readNplot(String filename) async {
    String dbfFilePath = filename.replaceAll('.shp', '.dbf');
    try {
      Map<String, dynamic> res =
          await loadData('lib/$filename', 'lib/$dbfFilePath');
      polygontoshow = res['polygons'];
      polylinetoshow = res['polylines'];
      bounds = res['bounds'];
      logger.i("polyLen : ${polygontoshow.length}");
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
      );
    } catch (e, s) {
      logger.e("Error : $e");
      logger.i("StackTrace: $s");
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readNplot(selectedFile);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh_outlined),
        onPressed: () async {
          setState(() {});
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  animationConfig: const ScaleRAWA(),
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => {},
                    ),
                  ],
                ),
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      logger.i(_hitNotifier.value!.coordinate);
                      _voidShowFeatures(
                          _hitNotifier.value!.hitValues.cast<HitValue>(),
                          _hitNotifier.value!.coordinate);
                    },
                    child: PolygonLayer(
                      hitNotifier: _hitNotifier,
                      simplificationTolerance: 0,
                      polygons: polygontoshow,
                      polygonCulling: true,
                      polygonLabels: true,
                      useAltRendering: false,
                    ),
                  ),
                ),
                // polyline layer
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _voidShowFeatures(
                        _hitNotifier.value!.hitValues.cast<HitValue>(),
                        _hitNotifier.value!.coordinate,
                      );
                    },
                    child: PolylineLayer(
                      hitNotifier: _hitNotifier,
                      simplificationTolerance: 0,
                      polylines: polylinetoshow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              color: Colors.white,
              width: MediaQuery.sizeOf(context).width,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  value: selectedFile,
                  isExpanded: true,
                  isDense: true,
                  autofocus: true,
                  borderRadius: BorderRadius.circular(15),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      selectedFile = newValue;
                      await readNplot(selectedFile); // Load new data on change
                      setState(() {});
                    }
                  },
                  items: fileList.map<DropdownMenuItem<String>>((String file) {
                    return DropdownMenuItem<String>(
                      value: file,
                      child: Text(file),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _voidShowFeatures(
    List<HitValue> features,
    LatLng coords,
  ) {
    showModalBottomSheet(
        enableDrag: true,
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: (features[0]).entries.map<Widget>((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
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
          );
        });
  }
}
