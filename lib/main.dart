import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'store.dart';
import 'user_home.dart';
import 'admin_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    runApp(AytosApp(store: await Store.open()));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Yerel veritabanı açılamadı. Uygulamayı yeniden başlatın.',
            ),
          ),
        ),
      ),
    );
  }
}

class AytosApp extends StatelessWidget {
  final Store store;
  const AytosApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'aytos',
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff16734c)),
      scaffoldBackgroundColor: const Color(0xfff5f7f2),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: AuthPage(store: store),
  );
}

String message(Object e) => e.toString().replaceFirst('Exception: ', '');
void notify(BuildContext context, Object e) {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message(e))));
  }
}

String newSession() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
String dateText(Object? value) {
  final d = DateTime.parse(value as String).toLocal();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String statusText(Object? s) => switch (s) {
  'accepted' => 'Yağ · onaylandı',
  'rejected' => 'Yağ değil · reddedildi',
  _ => 'Admin değerlendirmesi bekliyor',
};

class Notice extends StatelessWidget {
  final String text;
  const Notice(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}

class AuthPage extends StatefulWidget {
  final Store store;
  const AuthPage({super.key, required this.store});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool registration = false, busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit({bool admin = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final user = admin
          ? await widget.store.login('admin@aytos.local', 'Aytos123!')
          : registration
          ? await widget.store.register(name.text, email.text, password.text)
          : await widget.store.login(email.text, password.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => user['role'] == 'admin'
              ? AdminHome(store: widget.store, user: user)
              : UserHome(store: widget.store, user: user),
        ),
      );
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.eco_rounded,
                  size: 72,
                  color: Color(0xff16734c),
                ),
                const SizedBox(height: 12),
                Text(
                  'aytos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Atık yağını dönüştür, Yozgat’a katkı sağla.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Text(
                  registration ? 'Hesap oluştur' : 'Hoş geldiniz',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (registration) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Ad soyad'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parola',
                    helperText: 'En az 8 karakter',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Lütfen bekleyin…'
                        : registration
                        ? 'Kayıt ol'
                        : 'Giriş yap',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => registration = !registration),
                  child: Text(
                    registration ? 'Zaten hesabım var' : 'Hesap oluştur',
                  ),
                ),
                const Divider(),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => submit(admin: true),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Demo admin girişi'),
                ),
                const Notice(
                  'Prototip · Veriler yalnızca bu telefonda saklanır. Harita ve rota için internet gerekir. Konteynır noktaları demo amaçlıdır.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
