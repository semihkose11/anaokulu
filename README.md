# Anaokulu Kapı Sistemi

Veli, okul kapısındaki QR kodu okutarak veli kayıt formunu doldurur ve öğretmeni seçer. Öğretmen bildirimi kendi ekranında anında görür, "Geliyorum" ve "Tamamlandı" diyerek yanıt verir. Yönetici tüm gelişleri gün ve saatiyle kayıt defterinden izler, öğretmen hesaplarını açar ve yönetir.

Veriler ve girişler [Supabase](https://supabase.com) üzerinde tutulur.

## Sayfalar

| Adres | İçerik |
|---|---|
| `#form` | Veli kayıt formu (kapıdaki QR kodu bu sayfayı açar) |
| `#giris` | Öğretmen ve yönetici girişi (kullanıcı adı ve şifre) |
| `#ogretmen` | Öğretmen paneli: bekleyen veliler |
| `#yonetici` | Yönetim: kayıtlar, öğretmenler, QR kodu, kılavuz |
| `#kurulum` | Öğretmenler için iPhone kurulum rehberi |

## Klasör yapısı

- `index.html`: sitenin tamamı
- `supabase/01_kurulum.sql`: tablolar, güvenlik kuralları ve fonksiyonlar
- `supabase/02_ilk_yonetici.sql`: ilk yönetici hesabına yetki verme
- `supabase/functions/admin-users/index.ts`: öğretmen hesabı açma ve şifre sıfırlama (Edge Function)

## Güvenlik

- Sitede yalnızca Supabase'in herkese açık (publishable) anahtarı bulunur. Gizli (secret / service_role) anahtar hiçbir zaman bu depoya eklenmemelidir.
- Veliler giriş yapmadan yalnızca form gönderebilir ve kendi kayıtlarının durumunu görebilir. Öğretmen yalnızca kendi kayıtlarını, yönetici tüm kayıtları görür.
- Dışarıdan kayıt olma kapalıdır; hesapları yalnızca yönetici açar.

## Önemli not

Bu sürüm deneme aşamasındadır. Gerçek veli verisiyle kullanmadan önce KVKK aydınlatma metni, çerez politikası ve yurt dışına veri aktarımı konuları bir hukukçuyla netleştirilmelidir. Öğretmenin telefonuna uygulama kapalıyken gelen bildirim (web push) henüz eklenmemiştir; şu an bildirimler öğretmen paneli açıkken gelir.
