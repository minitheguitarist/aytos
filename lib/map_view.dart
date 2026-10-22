import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';

const yozgatCenter = LatLng(39.8181, 34.8147);

class CollectionMap extends StatelessWidget {
  final List<DbRow> containers;
  final LatLng? position;
  final List<LatLng> route;
  final MapController? controller;
  final void Function(LatLng)? onTap;
  final void Function(DbRow)? onContainer;
  const CollectionMap({
    super.key,
    required this.containers,
    this.position,
    this.route = const [],
    this.controller,
    this.onTap,
    this.onContainer,
  });
  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: controller,
    options: MapOptions(
      initialCenter: yozgatCenter,
      initialZoom: 14,
      onTap: (_, p) => onTap?.call(p),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.aytos.aytos',
        maxZoom: 19,
      ),
      if (route.isNotEmpty)
        PolylineLayer(
          polylines: [
            Polyline(
              points: route,
              strokeWidth: 5,
              color: const Color(0xff16734c),
            ),
          ],
        ),
      MarkerLayer(
        markers: [
          ...containers.map(
            (c) => Marker(
              point: LatLng(
                (c['lat'] as num).toDouble(),
                (c['lon'] as num).toDouble(),
              ),
              width: 52,
              height: 54,
              child: GestureDetector(
                onTap: () => onContainer?.call(c),
                child: Tooltip(
                  message:
                      '${c['name']} · ${((c['fill'] as num) / (c['capacity'] as num) * 100).round()}%',
                  child: Icon(
                    Icons.location_on,
                    size: 44,
                    color: c['active'] == 1
                        ? const Color(0xff16734c)
                        : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          if (position != null)
            Marker(
              point: position!,
              width: 32,
              height: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      RichAttributionWidget(
        attributions: [
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          ),
        ],
      ),
    ],
  );
}
