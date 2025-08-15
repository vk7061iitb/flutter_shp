import 'package:arcgis/utils/load.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import '../utils/data.dart';

class MapPage2 extends StatefulWidget {
  const MapPage2({super.key});

  @override
  State<MapPage2> createState() => _MapPage2State();
}

class _MapPage2State extends State<MapPage2> with TickerProviderStateMixin {
  int fileCode = 0;
  final MapController _mapController = MapController();
  List<Polygon> polygontoshow = [];
  List<Polyline> polylinetoshow = [];
  Logger logger = Logger();
  LatLngBounds bounds = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
  LatLngBounds b = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
  String selectedFile = 'india_ds.shp'; // Default file
  bool isLoading = false;
  bool isDropdownExpanded = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

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

  // Map of friendly names for shapefiles
  final Map<String, String> fileDisplayNames = {
    'cb_2018_us_aiannh_500k.shp': '🇺🇸 US American Indian Areas',
    'cb_2018_us_state_500k.shp': '🇺🇸 US States',
    'cb_2018_us_necta_500k.shp': '🇺🇸 US NECTA Areas',
    'ne_110m_admin_1_states_provinces.shp': '🌍 World States & Provinces',
    'india_ds.shp': '🇮🇳 India Districts',
    'tl_2024_04001_areawater.shp': '💧 Arizona Water Areas',
    'tl_2024_50_sdadm.shp': '🏛️ Vermont School Districts',
    'tl_2024_55_prisecroads.shp': '🛣️ Wisconsin Primary Roads',
    'tl_2019_12061_roads.shp': '🛤️ Florida Roads (2019)'
  };

  Future<void> readNplot(String filename) async {
    setState(() {
      isLoading = true;
    });

    String dbfFilePath = filename.replaceAll('.shp', '.dbf');
    try {
      // Add haptic feedback
      HapticFeedback.selectionClick();

      Map<String, dynamic> res = await loadData(
          'lib/assets/shapefiles/$filename',
          'lib/assets/shapefiles/$dbfFilePath');
      polygontoshow = res['polygons'];
      polylinetoshow = res['polylines'];
      bounds = res['bounds'];
      logger.i("polyLen : ${polygontoshow.length}");

      // Smooth camera transition
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
      );

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Loaded ${fileDisplayNames[filename] ?? filename}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e, s) {
      logger.e("Error : $e");
      logger.i("StackTrace: $s");

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to load $filename'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      readNplot(selectedFile);
      _fadeController?.forward();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Refresh button
          FloatingActionButton(
            heroTag: "refresh",
            mini: true,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.refresh_outlined, color: Colors.white),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await readNplot(selectedFile);
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          // Center on bounds button
          FloatingActionButton(
            heroTag: "center",
            mini: true,
            backgroundColor: Colors.green,
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              if (bounds.south != 0 ||
                  bounds.north != 0 ||
                  bounds.east != 0 ||
                  bounds.west != 0) {
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(20),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          // Toggle layers button
          FloatingActionButton(
            heroTag: "layers",
            backgroundColor: Colors.orange,
            child: const Icon(Icons.layers, color: Colors.white),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showLayerInfo(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Map
          Positioned.fill(
            child: _fadeAnimation != null
                ? FadeTransition(
                    opacity: _fadeAnimation!,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.arcgis',
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
                        // Polygon Layer with enhanced styling
                        MouseRegion(
                          hitTestBehavior: HitTestBehavior.deferToChild,
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (_hitNotifier.value != null) {
                                HapticFeedback.lightImpact();
                                logger.i(_hitNotifier.value!.coordinate);
                                _voidShowFeatures(
                                    _hitNotifier.value!.hitValues
                                        .cast<HitValue>(),
                                    _hitNotifier.value!.coordinate);
                              }
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
                        // Polyline Layer with enhanced styling
                        MouseRegion(
                          hitTestBehavior: HitTestBehavior.deferToChild,
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (_hitNotifier.value != null) {
                                HapticFeedback.lightImpact();
                                _voidShowFeatures(
                                  _hitNotifier.value!.hitValues
                                      .cast<HitValue>(),
                                  _hitNotifier.value!.coordinate,
                                );
                              }
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
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.arcgis',
                      ),
                    ],
                  ),
          ),

          // Enhanced Header with File Selection
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade800,
                    Colors.blue.shade600,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.map,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Shapefile Viewer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: DropdownButton<String>(
                            value: selectedFile,
                            isExpanded: true,
                            isDense: true,
                            borderRadius: BorderRadius.circular(12),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            onChanged: isLoading
                                ? null
                                : (String? newValue) async {
                                    if (newValue != null &&
                                        newValue != selectedFile) {
                                      selectedFile = newValue;
                                      await readNplot(selectedFile);
                                      setState(() {});
                                    }
                                  },
                            items: fileList
                                .map<DropdownMenuItem<String>>((String file) {
                              return DropdownMenuItem<String>(
                                value: file,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fileDisplayNames[file] ?? file,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading shapefile...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLayerInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Layer Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _buildInfoRow('Selected File:',
                  fileDisplayNames[selectedFile] ?? selectedFile),
              _buildInfoRow('Polygons:', '${polygontoshow.length}'),
              _buildInfoRow('Polylines:', '${polylinetoshow.length}'),
              _buildInfoRow('Total Features:',
                  '${polygontoshow.length + polylinetoshow.length}'),
              const SizedBox(height: 20),
              const Text(
                'Tip: Tap on any feature to view its attributes',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _voidShowFeatures(
    List<HitValue> features,
    LatLng coords,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Feature Attributes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Lat: ${coords.latitude.toStringAsFixed(4)}, '
                  'Lng: ${coords.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              const Divider(),
              // Content
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: features[0].entries.length,
                  itemBuilder: (context, index) {
                    final entry = features[0].entries.elementAt(index);
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value?.toString() ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
