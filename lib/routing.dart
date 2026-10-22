import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'store.dart';

class RouteResult {
  final DbRow container;
  final List<LatLng> line;
  final double meters, seconds;
  RouteResult(this.container, this.line, this.meters, this.seconds);
}

class Routing {
  Future<RouteResult> route(LatLng start, DbRow container, bool walking) async {
    final service = walking ? 'routed-foot' : 'routed-car';
    final url = Uri.parse(
      'https://routing.openstreetmap.de/$service/route/v1/driving/${start.longitude},${start.latitude};${container['lon']},${container['lat']}?overview=full&geometries=geojson',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Rota servisine ulaşılamadı. İnternet bağlantısını kontrol edin.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('Bu konteynıra uygun bir yol bulunamadı.');
    }
    final r = data['routes'][0];
    return RouteResult(
      container,
      (r['geometry']['coordinates'] as List)
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList(),
      (r['distance'] as num).toDouble(),
      (r['duration'] as num).toDouble(),
    );
  }

  Future<RouteResult> best(
    LatLng start,
    List<DbRow> containers,
    double liters,
    bool walking,
  ) async {
    final candidates = containers
        .where(
          (c) =>
              c['active'] == 1 &&
              (c['capacity'] as num) - (c['fill'] as num) >= liters,
        )
        .toList();
    if (candidates.isEmpty) {
      throw Exception(
        'Bu miktar için yeterli kapasitesi olan aktif konteynır bulunamadı.',
      );
    }
    // Compare actual road distances for every eligible container. Partial failure
    // is reported rather than claiming an unverified nearest result.
    final results = <RouteResult>[];
    for (final c in candidates) {
      results.add(await route(start, c, walking));
    }
    results.sort((a, b) => a.meters.compareTo(b.meters));
    return results.first;
  }
}

bool inYozgat(LatLng p) =>
    p.latitude >= 39.55 &&
    p.latitude <= 40.05 &&
    p.longitude >= 34.4 &&
    p.longitude <= 35.2;
String litersText(num n) =>
    n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1).replaceAll('.', ',');
