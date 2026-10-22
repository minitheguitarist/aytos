# aytos

Yozgat için atık yağ toplama **Android prototipi**. Flutter + SQLite ile tek telefonda çalışır. Kullanıcı ve admin hesapları aynı yerel veriyi kullanır; sunucu veya cihaz bağlantısı yoktur.

## Android'e kurulum

İlk herkese açık test sürümü: [v0.1.0-beta.1](https://github.com/minitheguitarist/aytos/releases/tag/v0.1.0-beta.1).

1. Telefonunuzdan [AYTOS APK dosyasını indirin](https://github.com/minitheguitarist/aytos/releases/download/v0.1.0-beta.1/aytos-v0.1.0-beta.1.apk).
2. İndirilen dosyayı açın. Android isterse indirdiğiniz tarayıcı veya dosya yöneticisi için bu kaynaktan uygulama yükleme izni verin.
3. Uygulamayı kurup hesap oluşturun. Yozgat dışında test ederken **Demo konum** seçeneğini kullanın; teslim için [Demo QR](docs/demo-qr.png) kodunu başka bir ekrandan okutun.

Bu APK Android 7.0 ve üzeri için ARM, ARM64 ve x86_64 mimarilerini içerir.
Test sürümü mevcut demo anahtarıyla imzalanır. Önceki yerel kurulumla aynı
anahtar korunur; farklı imzayla kurulmuş bir APK üzerine güncelleme yapılamaz.
Veriler her telefonda ayrıdır; uygulamayı kaldırmak yerel kayıtları siler.

Sorun bildirirken telefon modeli, Android sürümü, uygulama sürümü ve hatayı
tekrarlama adımlarını [GitHub Issues](https://github.com/minitheguitarist/aytos/issues) üzerinden paylaşabilirsiniz.

## Çalıştırma

Flutter stable ve Android SDK kurulu bir bilgisayarda:

```sh
flutter pub get
flutter run
```

Paylaşılabilir test APK'sını üretmek için:

```sh
flutter build apk --release
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`. Bu, release modunda
derlenen bir demo APK'sıdır; mevcut yapılandırma demo imza anahtarını kullanır.
Google Play'de kalıcı dağıtım için ayrı bir yayın anahtarı yapılandırılmalıdır.
Test sürümlerinin aynı imzayla güncellenebilmesi için bu bilgisayardaki
`~/.android/debug.keystore` dosyasını özel olarak yedekleyin; repoya veya
release dosyalarına eklemeyin.

## Demo

1. Kullanıcı hesabı oluşturun (parola en az 8 karakter).
2. Konum izni verin veya **Demo konum** ile Yozgat merkezini seçin.
3. Litre ve yürüyüş/araç modunu seçin, **Uygun konteynırı bul** butonuna basın.
4. **Başlat** ile haritadaki rotayı takip edin. Gerçek GPS konumu değiştikçe işaretçi güncellenir; rota en sık 30 saniyede bir yeniden hesaplanır. Demo konumda GPS takibi yoktur.
5. **Konuma geldim** ile kamerayı açıp herhangi bir QR okutun. [Demo QR](docs/demo-qr.png) dosyasını bilgisayarda açarak veya yazdırarak deneyebilirsiniz.
6. Konteynır, mahalle, sokak ve litre bilgilerini kontrol edip **Onaylıyorum** butonuna basın. QR taraması tek başına puan vermez.
7. Çıkış yapıp **Demo admin girişi** ile son dökülenler listesini açın. Yağ / Yağ değil kararı verin.
8. Kullanıcı hesabıyla tekrar giriş yaparak puan ve teslim durumunu kontrol edin.

Demo admin: `admin@aytos.local` / `Aytos123!`. Kolay giriş butonu yalnızca bu prototip içindir. Kullanıcı parolaları rastgele salt ve PBKDF2-HMAC-SHA256 (120.000 tur) ile saklanır.

## İş kuralları

- 1 litre = 10 puan; 0,5 litre = 5 puan.
- Kullanıcı onayından sonra teslim ve puan, aynı SQLite transaction içinde kaydedilir.
- Aynı teslim oturumu birden fazla onayla ikinci kez puan üretemez.
- Admin yağ onayında varsayılan **+5 bonus** verir.
- Admin yağ değil kararında ilk teslim puanını geri alır ve ayrıca **−200 ceza** verir. Örneğin +20 alan kişi için −20 ve −200 kaydedilir.
- Puan negatif olabilir. Admin değerlendirmesi tek seferliktir; tekrar basmak veya sonradan karşı karara basmak puanı değiştirmez.
- Admin ayarlarından bonus ve ceza değiştirilir; geçmiş kararlar değişmez.
- Admin değerlendirmesi sırasında `ACCEPT` / `REJECT` cihaz kararı `simulated` durumuyla kaydedilir; gerçek donanıma gönderilmez.
- Konteynır doluluğu manuel simülasyondur. Onaylanan kullanıcı beyanı seçilen litre kadar simülasyon doluluğunu artırır; bütün sıvı hacimleri hesaba katılır. Admin reddi hacmi otomatik geri almaz. Boşaltma simülasyonu adminin doluluğu düzenlemesiyle yapılır.

## Harita ve rota

OpenStreetMap döşemeleri ve atıf bağlantısı, `flutter_map` ile gösterilir. Rota için FOSSGIS'in halka açık OSRM servisleri kullanılır:

- Yürüyüş: `routing.openstreetmap.de/routed-foot`
- Araç: `routing.openstreetmap.de/routed-car`

Aktif ve seçilen litreye yeterli boş kapasitesi olan tüm konteynırlar için yol mesafesi hesaplanır, en kısa mesafe seçilir. Kuş uçuşu mesafe kullanılmaz. Rota sorgularından biri başarısızsa eksik veriyle “en yakın” denmez; kullanıcıya hata gösterilir.

İnternet harita ve rota için gereklidir. Mevcut yönlendirme harita üzerinde rota çizgisi, tahmini süre/mesafe ve canlı konum sunar; sesli veya dönüş dönüş navigasyon içermez. Ekran kapalıyken arka plan navigasyonu hedeflenmez. Gerçek cihazda GPS/kamera izinleri ve servislerin erişilebilirliği kontrol edilmelidir.

Başlangıçtaki üç konteynır **demo noktalarıdır**, gerçek toplama noktaları değildir. Mahalle/adres bilgileri admin tarafından girilir; otomatik adres çözümleme yoktur. Prototip Yozgat çevresindeki dikdörtgen bir çalışma alanını kontrol eder; bu resmi il/idari sınır doğrulaması değildir. Gerçek kullanımda Yozgat sınır poligonu ve doğrulanmış adresler eklenmelidir.

## Yerel veriler ve sonraki aşama

SQLite tabloları: `users`, `containers`, `deliveries`, `ledger`, `decisions`, `settings`.

Veriler uygulama kapanınca korunur. Başka telefonlarla senkronize edilmez. Uygulama verilerini temizlemek veya uygulamayı kaldırmak kayıtları siler. Android yedekleme kapalıdır.

Sensör doluluğu, gerçek litre ölçümü, konteynıra özel QR, varış doğrulaması, donanımın komutu aldığını doğrulama ve merkezi veritabanı henüz uygulanmadı. QR içeriği doğrulanmaz veya saklanmaz; seçili konteynırın oturumu kullanılır. Litre ve varış kullanıcı beyanıdır.

Kod düzeni:

- `lib/store.dart`: kimlik doğrulama, SQLite, atomik teslim/puan ve cihaz kararı kayıtları.
- `lib/routing.dart`: yürüyüş/araç rotası ve kapasiteye göre konteynır seçimi.
- `lib/user_home.dart`: kullanıcı haritası, canlı konum, QR, teslim, sıralama ve geçmiş.
- `lib/admin_home.dart`: konteynırlar, sıvı değerlendirmesi ve puan ayarları.
- `lib/map_view.dart`: ortak OSM haritası ve atıf.

## Doğrulama

```sh
flutter analyze
flutter test
```

Dar ekran arayüz testleri giriş/kayıt ve yürüyüş/araç kontrollerini doğrular. Veritabanı testleri tekrarlanan onay/kararlarda çift puan oluşmamasını, ceza işlemini, kapasite hatasında transaction bütünlüğünü, admin yetkisini, yanlış parola/tekrarlanan e-postayı ve verilerin yeniden açılınca korunmasını kapsar.

GitHub Actions iş akışı analiz, test ve Android derlemesini çalıştırır; başarılı çalışmalarda APK `aytos-android-prototype` artifact adıyla 14 gün saklanır.
