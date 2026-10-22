import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart';
import 'map_view.dart';
import 'routing.dart';
import 'store.dart';

class UserHome extends StatefulWidget {
  final Store store;
  final DbRow user;
  const UserHome({super.key, required this.store, required this.user});
  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final map = MapController();
  final router = Routing();
  List<DbRow> containers = [], history = [], ranking = [], ledger = [];
  LatLng? position;
  RouteResult? selected;
  StreamSubscription<Position>? gps;
  double liters = 1;
  bool walking = true,
      busy = false,
      started = false,
      demo = false,
      refreshing = false;
  int tab = 0;
  String? sessionId;
  DateTime lastRoute = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? lastRoutedPosition;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    gps?.cancel();
    map.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final c = await widget.store.containers();
      final h = await widget.store.deliveries(userId: widget.user['id'] as int);
      final r = await widget.store.ranking();
      final l = await widget.store.ledger(widget.user['id'] as int);
      if (mounted) {
        setState(() {
          containers = c;
          history = h;
          ranking = r;
          ledger = l;
        });
      }
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> locate() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Telefonun konum hizmetini açın.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Konum izni kapalı. Telefonun uygulama ayarlarından izin verin.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Rota için konum izni gerekli. Demo konumunu da kullanabilirsiniz.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      await gps?.cancel();
      setState(() {
        position = LatLng(p.latitude, p.longitude);
        demo = false;
        selected = null;
        started = false;
      });
      map.move(position!, 15);
      gps =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (p) {
              if (!mounted) return;
              final next = LatLng(p.latitude, p.longitude);
              setState(() => position = next);
              if (started) {
                map.move(next, map.camera.zoom);
                unawaited(updateRoute(next));
              }
            },
            onError: (Object e) {
              if (mounted) notify(context, 'Konum takibi durdu: ${message(e)}');
            },
          );
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updateRoute(LatLng next) async {
    if (refreshing ||
        selected == null ||
        DateTime.now().difference(lastRoute).inSeconds < 30) {
      return;
    }
    if (lastRoutedPosition != null &&
        const Distance().as(LengthUnit.Meter, lastRoutedPosition!, next) < 30) {
      return;
    }
    refreshing = true;
    lastRoute = DateTime.now();
    final old = selected;
    try {
      final r = await router.route(next, old!.container, walking);
      if (mounted && started && identical(selected, old)) {
        setState(() {
          selected = r;
          lastRoutedPosition = next;
        });
      }
    } catch (e) {
      if (mounted && started) {
        notify(context, 'Rota güncellenemedi. Son rota gösteriliyor.');
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> findRoute() async {
    if (position == null) {
      notify(context, 'Önce konumunuzu alın veya demo konumunu seçin.');
      return;
    }
    if (!inYozgat(position!)) {
      notify(
        context,
        'Bu prototip Yozgat merkez çalışma alanı için hazırlanmıştır. Demo konumuyla deneyebilirsiniz.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      final fresh = await widget.store.containers();
      final r = await router.best(position!, fresh, liters, walking);
      if (!mounted) return;
      setState(() {
        containers = fresh;
        selected = r;
        started = false;
        sessionId = newSession();
        lastRoutedPosition = position;
      });
      map.fitCamera(
        CameraFit.coordinates(
          coordinates: [position!, ...r.line],
          padding: const EdgeInsets.all(44),
        ),
      );
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> arrived() async {
    if (selected == null || sessionId == null || busy) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliveryPage(
          store: widget.store,
          user: widget.user,
          route: selected!,
          liters: liters,
          session: sessionId!,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {
        started = false;
        selected = null;
        sessionId = null;
        tab = 2;
      });
      await load();
    }
  }

  Future<void> demoPosition() async {
    await gps?.cancel();
    gps = null;
    if (!mounted) return;
    setState(() {
      position = yozgatCenter;
      demo = true;
      selected = null;
      started = false;
    });
    map.move(yozgatCenter, 15);
  }

  void invalidate() {
    selected = null;
    started = false;
    sessionId = null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('aytos'),
      actions: [
        IconButton(
          tooltip: 'Çıkış yap',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) {
        setState(() => tab = i);
        if (i != 0) unawaited(load());
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          label: 'Yağ teslim et',
        ),
        NavigationDestination(
          icon: Icon(Icons.leaderboard_outlined),
          label: 'Sıralama',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Geçmiş',
        ),
      ],
    ),
    body: IndexedStack(
      index: tab,
      children: [mapTab(), rankingTab(), historyTab()],
    ),
  );
  Widget mapTab() => Column(
    children: [
      Expanded(
        child: CollectionMap(
          containers: containers.where((c) => c['active'] == 1).toList(),
          controller: map,
          position: position,
          route: selected?.line ?? [],
          onContainer: (c) => showModalBottomSheet(
            context: context,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${c['neighborhood']} Mahallesi · ${c['street']}'),
                  Text(
                    'Simülasyon doluluğu: ${litersText(c['fill'] as num)} / ${litersText(c['capacity'] as num)} L',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (demo)
                const Text(
                  'Demo konumu · Canlı GPS takibi yapılmıyor',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              if (!started)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          position == null ? 'Konumumu al' : 'Konumu yenile',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: busy ? null : demoPosition,
                      child: const Text('Demo konum'),
                    ),
                  ],
                ),
              if (!started) ...[
                DropdownButtonFormField<double>(
                  initialValue: liters,
                  decoration: const InputDecoration(labelText: 'Yağ miktarı'),
                  items: [0.5, 1.0, 2.0, 3.0, 5.0]
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text('${litersText(l)} litre'),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (l) => setState(() {
                          liters = l!;
                          invalidate();
                        }),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.directions_walk),
                      label: Text('Yürüyerek'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.directions_car),
                      label: Text('Araçla'),
                    ),
                  ],
                  selected: {walking},
                  onSelectionChanged: busy
                      ? null
                      : (s) => setState(() {
                          walking = s.first;
                          invalidate();
                        }),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy ? null : findRoute,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route),
                  label: Text(
                    busy ? 'Lütfen bekleyin…' : 'Uygun konteynırı bul',
                  ),
                ),
              ],
              if (selected != null) ...[
                Text(
                  '${selected!.container['name']} · ${(selected!.meters / 1000).toStringAsFixed(2)} km · ${(selected!.seconds / 60).ceil()} dk',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${selected!.container['neighborhood']} Mahallesi · ${selected!.container['street']}',
                ),
                if (!started)
                  FilledButton(
                    onPressed: () => setState(() {
                      started = true;
                      lastRoute = DateTime.now();
                    }),
                    child: const Text('Başlat'),
                  ),
                if (started) ...[
                  Text(
                    walking
                        ? 'Yürüyüş rotası · Haritadaki yeşil hattı takip edin.'
                        : 'Araç rotası · Haritadaki yeşil hattı takip edin.',
                  ),
                  FilledButton(
                    onPressed: busy ? null : arrived,
                    child: const Text('Konuma geldim · QR okut'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => started = false),
                    child: const Text('Yönlendirmeyi durdur'),
                  ),
                ],
              ],
              if (selected == null)
                const Text(
                  'Yozgat · Demo konteynırlar ve simülasyon doluluğu',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget rankingTab() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Yozgat’a katkın',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Notice(
          '${widget.user['name']} · ${ledger.fold<int>(0, (a, l) => a + (l['points'] as int))} puan\nBeyan edilen toplam: ${litersText(history.fold<double>(0, (a, d) => a + (d['liters'] as num).toDouble()))} litre',
        ),
        const Text('Bu telefondaki kullanıcıların sıralaması'),
        const SizedBox(height: 12),
        if (ranking.isEmpty) const Text('Henüz kayıtlı kullanıcı yok.'),
        ...ranking.asMap().entries.map(
          (e) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${e.key + 1}')),
              title: Text(e.value['name'] as String),
              trailing: Text('${e.value['points']} puan'),
            ),
          ),
        ),
      ],
    ),
  );
  Widget historyTab() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Teslim geçmişi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Notice(
          'QR sonrası onayla litre başına 10 puan kazanırsınız. Admin yağ olarak onaylarsa bonus eklenir; reddederse teslim puanı geri alınır ve ceza uygulanır.',
        ),
        if (history.isEmpty) const Text('Henüz teslim yapmadınız.'),
        ...history.map(
          (d) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['container_name'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(d['address'] as String),
                  Text(dateText(d['created'])),
                  Text(
                    '${litersText(d['liters'] as num)} L · ${statusText(d['status'])}',
                  ),
                  ...ledger
                      .where((l) => l['delivery_id'] == d['id'])
                      .map(
                        (l) => Text(
                          '${switch (l['kind']) {
                            'base' => 'Teslim',
                            'bonus' => 'Onay bonusu',
                            'reversal' => 'Teslim puanı iadesi',
                            _ => 'Ceza',
                          }}: ${(l['points'] as int) > 0 ? '+' : ''}${l['points']} puan',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class DeliveryPage extends StatefulWidget {
  final Store store;
  final DbRow user;
  final RouteResult route;
  final double liters;
  final String session;
  const DeliveryPage({
    super.key,
    required this.store,
    required this.user,
    required this.route,
    required this.liters,
    required this.session,
  });
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool scanned = false, busy = false;
  @override
  void dispose() {
    unawaited(scanner.dispose());
    super.dispose();
  }

  void detected(BarcodeCapture capture) {
    if (scanned ||
        !capture.barcodes.any((b) => b.rawValue?.isNotEmpty == true)) {
      return;
    }
    setState(() => scanned = true);
    unawaited(scanner.stop());
  }

  Future<void> confirm() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.store.confirm(
        widget.session,
        widget.user['id'] as int,
        widget.route.container['id'] as int,
        widget.liters,
      );
      if (mounted) {
        notify(
          context,
          'Teslim kaydedildi. ${(widget.liters * 10).round()} puan eklendi.',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(scanned ? 'Teslimi onayla' : 'Konteynır QR kodu'),
    ),
    body: scanned
        ? ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Color(0xff16734c),
              ),
              const SizedBox(height: 16),
              Text(
                widget.route.container['name'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Yozgat · ${widget.route.container['neighborhood']} Mahallesi · ${widget.route.container['street']}',
              ),
              const SizedBox(height: 24),
              Text(
                '${litersText(widget.liters)} litre döktüğünüzü beyan ediyorsunuz.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${(widget.liters * 10).round()} puan kazanacaksınız.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Notice(
                'Puan, Onaylıyorum butonuna bastığınızda eklenir. Admin değerlendirmesinde yağ dışı sıvı tespit edilirse teslim puanı geri alınır ve ceza uygulanır. Bu prototipte her okunabilir QR kabul edilir.',
              ),
              FilledButton(
                onPressed: busy ? null : confirm,
                child: Text(busy ? 'Kaydediliyor…' : 'Onaylıyorum'),
              ),
            ],
          )
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Haznedeki QR kodunu kameraya gösterin. Puan için sonraki ekranda onay vermeniz gerekir.',
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: scanner,
                  onDetect: detected,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Kamera açılamadı. Kamera iznini uygulama ayarlarından kontrol edin.\n${error.errorCode.name}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}
