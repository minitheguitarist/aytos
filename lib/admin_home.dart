import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'main.dart';
import 'map_view.dart';
import 'routing.dart';
import 'store.dart';

class AdminHome extends StatefulWidget {
  final Store store;
  final DbRow user;
  const AdminHome({super.key, required this.store, required this.user});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  List<DbRow> containers = [], deliveries = [];
  int tab = 0;
  bool busy = false;
  DbRow settings = {'bonus': 5, 'penalty': 200};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final c = await widget.store.containers(),
          d = await widget.store.deliveries(),
          s = await widget.store.settings();
      if (mounted) {
        setState(() {
          containers = c;
          deliveries = d;
          settings = s;
        });
      }
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> edit({DbRow? container, LatLng? point}) async {
    if (point != null && !inYozgat(point)) {
      notify(context, 'Konteynır Yozgat merkez çalışma alanında olmalı.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContainerEditor(
          store: widget.store,
          container: container,
          point: point,
        ),
      ),
    );
    await load();
  }

  Future<void> review(DbRow d, bool oil) async {
    if (busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(oil ? 'Yağ olarak onayla' : 'Yağ dışı sıvı olarak reddet'),
        content: Text(
          oil
              ? '${d['user_name']} için +${settings['bonus']} bonus eklenecek. Konteynır kabul kararı simüle edilecek.'
              : '${d['user_name']} için ${d['base_points']} teslim puanı geri alınacak ve −${settings['penalty']} ceza uygulanacak. Konteynır ret kararı simüle edilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.review(
        widget.user['id'] as int,
        d['id'] as String,
        oil,
      );
      await load();
      if (mounted) {
        notify(
          context,
          'Karar ve puan işlemi kaydedildi. Cihaz komutu yalnızca simüle edildi.',
        );
      }
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editPoints() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsEditor(store: widget.store, settings: settings),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('aytos · Admin'),
      actions: [
        IconButton(
          tooltip: 'Puan ayarları',
          onPressed: busy ? null : editPoints,
          icon: const Icon(Icons.settings_outlined),
        ),
        IconButton(
          tooltip: 'Çıkış yap',
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          label: 'Konteynırlar',
        ),
        NavigationDestination(
          icon: Icon(Icons.water_drop_outlined),
          label: 'Son dökülenler',
        ),
      ],
    ),
    body: IndexedStack(
      index: tab,
      children: [
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Notice(
                'Haritada bir noktaya dokunarak konteynır ekleyin. İşaretçiye dokunarak düzenleyin. Doluluk ve cihaz komutları simülasyondur.',
              ),
            ),
            Expanded(
              child: CollectionMap(
                containers: containers,
                onTap: (p) => edit(point: p),
                onContainer: (c) => edit(container: c),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView(
                children: containers
                    .map(
                      (c) => ListTile(
                        leading: Icon(
                          Icons.recycling,
                          color: c['active'] == 1 ? Colors.green : Colors.grey,
                        ),
                        title: Text(c['name'] as String),
                        subtitle: Text(
                          '${litersText(c['fill'] as num)} / ${litersText(c['capacity'] as num)} L · ${c['active'] == 1 ? 'Aktif' : 'Pasif'}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => edit(container: c),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Son dökülenler',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Notice(
                'Yağ: +${settings['bonus']} bonus\nYağ değil: teslim puanını geri al ve −${settings['penalty']} ceza uygula.',
              ),
              if (deliveries.isEmpty)
                const Text(
                  'Henüz teslim kaydı yok. Kullanıcı hesabıyla bir teslim oluşturun.',
                ),
              ...deliveries.map(
                (d) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${d['user_name']} · ${litersText(d['liters'] as num)} L',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('${d['container_name']} · ${d['address']}'),
                        Text(dateText(d['created'])),
                        Text('Teslim puanı: +${d['base_points']}'),
                        const SizedBox(height: 8),
                        Text(statusText(d['status'])),
                        if (d['status'] == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => review(d, true),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Yağ'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => review(d, false),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Yağ değil'),
                                ),
                              ),
                            ],
                          ),
                        if (d['status'] != 'pending')
                          Text(
                            'Cihaz kararı: ${d['status'] == 'accepted' ? 'ACCEPT' : 'REJECT'} · Simüle edildi\n${dateText(d['reviewed'])}',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ContainerEditor extends StatefulWidget {
  final Store store;
  final DbRow? container;
  final LatLng? point;
  const ContainerEditor({
    super.key,
    required this.store,
    this.container,
    this.point,
  });
  @override
  State<ContainerEditor> createState() => _ContainerEditorState();
}

class _ContainerEditorState extends State<ContainerEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, neighborhood, street, capacity, fill;
  bool active = true, busy = false;
  late LatLng selectedPoint;
  @override
  void initState() {
    super.initState();
    final c = widget.container;
    selectedPoint =
        widget.point ??
        LatLng((c!['lat'] as num).toDouble(), (c['lon'] as num).toDouble());
    name = TextEditingController(text: c?['name'] as String?);
    neighborhood = TextEditingController(text: c?['neighborhood'] as String?);
    street = TextEditingController(text: c?['street'] as String?);
    capacity = TextEditingController(text: '${c?['capacity'] ?? 100}');
    fill = TextEditingController(text: '${c?['fill'] ?? 0}');
    active = c?['active'] != 0;
  }

  @override
  void dispose() {
    for (final c in [name, neighborhood, street, capacity, fill]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final c = widget.container;
      final row = <String, Object?>{
        'name': name.text.trim(),
        'neighborhood': neighborhood.text.trim(),
        'street': street.text.trim(),
        'capacity': double.parse(capacity.text.replaceAll(',', '.')),
        'fill': double.parse(fill.text.replaceAll(',', '.')),
        'active': active ? 1 : 0,
        'lat': selectedPoint.latitude,
        'lon': selectedPoint.longitude,
      };
      if (c != null) row['id'] = c['id'];
      await widget.store.saveContainer(row);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label, {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Bu alan gerekli';
            if (numeric) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              if (n == null || !n.isFinite) return 'Geçerli bir sayı girin';
            }
            return null;
          },
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.container == null ? 'Konteynır ekle' : 'Konteynırı düzenle',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Notice(
            'Yozgat · Konumu haritadan seçilir. Mahalle ve sokak adını manuel girin. Doluluk gerçek sensör verisi değildir.',
          ),
          SizedBox(
            height: 210,
            child: CollectionMap(
              containers: [
                {
                  'name': name.text.isEmpty ? 'Seçilen nokta' : name.text,
                  'lat': selectedPoint.latitude,
                  'lon': selectedPoint.longitude,
                  'capacity': 100,
                  'fill': 0,
                  'active': 1,
                },
              ],
              onTap: busy
                  ? null
                  : (p) {
                      if (!inYozgat(p)) {
                        notify(
                          context,
                          'Yozgat çalışma alanından bir nokta seçin.',
                        );
                        return;
                      }
                      setState(() => selectedPoint = p);
                    },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Konumu değiştirmek için haritaya dokunun.'),
          ),
          field(name, 'Konteynır adı'),
          field(neighborhood, 'Mahalle'),
          field(street, 'Sokak / adres'),
          field(capacity, 'Kapasite (litre)', numeric: true),
          field(fill, 'Simülasyon doluluğu (litre)', numeric: true),
          SwitchListTile(
            title: const Text('Aktif konteynır'),
            value: active,
            onChanged: busy ? null : (v) => setState(() => active = v),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Kaydediliyor…' : 'Kaydet'),
          ),
        ],
      ),
    ),
  );
}

class PointsEditor extends StatefulWidget {
  final Store store;
  final DbRow settings;
  const PointsEditor({super.key, required this.store, required this.settings});
  @override
  State<PointsEditor> createState() => _PointsEditorState();
}

class _PointsEditorState extends State<PointsEditor> {
  late final bonus = TextEditingController(text: '${widget.settings['bonus']}'),
      penalty = TextEditingController(text: '${widget.settings['penalty']}');
  bool busy = false;
  @override
  void dispose() {
    bonus.dispose();
    penalty.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final b = int.tryParse(bonus.text), p = int.tryParse(penalty.text);
      if (b == null || p == null) throw Exception('Tam sayı girin.');
      await widget.store.saveSettings(b, p);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Puan ayarları')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Notice(
          'Teslim: litre başına 10 puan. Bu ayarlar sonraki admin kararlarına uygulanır; geçmişte verilen puanlar korunur.',
        ),
        TextField(
          controller: bonus,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Yağ onayı bonusu'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: penalty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Yağ değil cezası (pozitif sayı)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}
