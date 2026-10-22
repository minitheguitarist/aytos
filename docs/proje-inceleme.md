# Proje incelemesi — 13 Ekim 2026

## Genel yapı

AYTOS, Yozgat için Flutter ve SQLite kullanan bir Android prototipi.
Kullanıcı ve admin aynı telefondaki veritabanını kullanır. Sunucu, telefonlar
arası senkronizasyon ve gerçek konteynır donanımı bağlantısı bulunmuyor.

| Dosya | Sorumluluk |
| --- | --- |
| `lib/main.dart` | Başlangıç, Türkçe tema, kayıt ve giriş |
| `lib/store.dart` | SQLite tabloları, parola doğrulama, teslim ve puan işlemleri |
| `lib/user_home.dart` | Konum, rota, QR tarama, teslim, sıralama ve geçmiş |
| `lib/admin_home.dart` | Konteynır düzenleme, teslim değerlendirmesi, puan ayarları |
| `lib/map_view.dart` | OpenStreetMap haritası, konumlar ve rota çizgisi |
| `lib/routing.dart` | Kapasiteye uygun konteynırlar arasında yol mesafesi karşılaştırması |

## Çalışan testler

`flutter test`: 7 test geçti.

- Tekrarlanan ve eşzamanlı teslim onaylarında tek puan kaydı.
- Tekrarlanan admin kararlarında tek bonus veya ceza.
- Yağ dışı sıvıda teslim puanının geri alınması ve −200 ceza.
- Yetersiz kapasitede teslim/puan kaydının oluşmaması.
- Kullanıcının admin değerlendirmesi yapamaması.
- Veritabanı yeniden açıldığında hesap, puan ve kararların korunması.
- Yanlış parola ve aynı normalize edilmiş e-postanın reddedilmesi.
- 320 × 640 ekranda giriş/kayıt ve miktar/ulaşım kontrollerinin yerleşimi.

`dart analyze`: hata bulunmadı.
`flutter analyze --no-pub /tmp/aytos-project`: hata bulunmadı.

Bilgisayardan demo merkez → Konteynır B sorgusunda yürüyüş ve araç
servislerinin ikisi de `code: Ok` döndürdü (yaklaşık 1,06 km).
Bu kontrol, telefonun internet ve harita erişimini ayrıca doğrulamaz.

Bu bilgisayardaki Flutter 3.44.0 analiz istemcisi, çalışma yolundaki Türkçe
karakterlerde LSP mesaj uzunluğunu hatalı hesaplıyor. `/tmp/aytos-project`
sembolik bağlantısı ile aynı kaynaklar ASCII yol üzerinden analiz edildi.
Bu geçici bağlantı bilgisayar yeniden başlatıldığında kaybolabilir.

## Taşıma sırasında eksilen dosyalar

Eski proje: `/home/smurat/Belgeler/Kişisel Projeler/p/aytos`.
Yeni proje: `/home/smurat/Belgeler/Kişisel Projeler/aytos`.

Kaynak kodu ve test dosyaları eski klasörle aynıydı. Yeni klasöre gelmeyen
`.gitignore`, `.metadata` ve ayrıntılı README geri getirildi. Android Gradle
çalıştırıcı dosyaları kurulu Flutter SDK'dan üretildi. `pubspec.lock`, kurulu
Flutter sürümünün sabitlediği bağımlılıklara uyarlandı.

Eski klasördeki `.github/workflows/android.yml` yeni klasörde eksikti.
GitHub aşamasında iş akışı kullanılan Flutter sürümüyle birlikte ele alınmalı.

## Cihazda doğrulanacak akış

1. Yeni kullanıcı kaydı; uygulama kapatılıp açıldıktan sonra aynı hesapla giriş.
2. Konum izni verme/reddetme; Yozgat dışında “Demo konum” kullanımı.
3. 2 litre için yürüyüş ve araç rotası; harita ve rota servislerine erişim.
4. “Başlat” → “Konuma geldim · QR okut”; kamera izni ve `docs/demo-qr.png` taraması.
5. “Onaylıyorum” sonrası +20 puan, geçmiş kaydı ve konteynır doluluğunda +2 litre.
6. Çıkış → “Demo admin girişi” → “Son dökülenler” → “Yağ”: toplam 25 puan.
7. Ayrı teslimde “Yağ değil”: teslim puanı geri alınır, −200 ceza uygulanır.
8. Admin konteynır düzenleme, aktif/pasif durumu, kapasite ve puan ayarları.

## Prototip sınırları ve sonraki işler

- Her okunabilir QR kabul ediliyor; QR içeriği konteynıra bağlanmıyor.
- Varış ve litre miktarı kullanıcı beyanı; GPS varış doğrulaması ve sensör ölçümü yok.
- Demo admin hesabına tek düğmeyle giriliyor; yayımlanmadan önce gerçek yetkilendirme gerekir.
- Konteynır doluluğu ve `ACCEPT`/`REJECT` cihaz kararları simülasyon.
- Rota sorguları sırayla yapılıyor; üç adayın zaman aşımı toplamda 45 saniyeye çıkabilir.
- SQLite kayıtları telefonlar arasında paylaşılmıyor; kaldırma veya veri temizleme kayıtları siler.
- Mevcut Android release derlemesi debug anahtarıyla imzalanıyor.
- Mevcut testler kamera/GPS donanımını ve gerçek ağ servislerini doğrulamıyor.

## Git durumu

İlk incelemede `main` dalı `origin/main` dalını takip ediyordu ve uzak depo
`https://github.com/minitheguitarist/aytos` olarak ayarlıydı. Tek commit,
README ve lisansı içeren başlangıç commitiydi; uygulama dosyaları hazırlama
alanına eklenmişti ve henüz commit edilmemişti. GitHub'a yükleme hatasının
tam nedeni, kimlik doğrulama ve uzak depo kontrolü yapılmadan belirlenemez.
