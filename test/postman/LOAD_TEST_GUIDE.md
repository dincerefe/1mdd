# 1000 Kullanıcı Load Test Rehberi

## 📁 Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `load_test_users.csv` | 1000 kullanıcı verisi |
| `Load_Test_Collection.postman_collection.json` | Load test collection |

---

## 🚀 Postman'de Load Test Çalıştırma

### Adım 1: Collection'ı Import Et
1. Postman'i aç
2. **Import** → `Load_Test_Collection.postman_collection.json`

### Adım 2: Collection Runner'ı Aç
1. Collection'a sağ tıkla → **Run collection**
2. Veya üstteki **Runner** butonuna tıkla

### Adım 3: CSV Dosyasını Yükle
1. Runner penceresinde **Data** bölümünü bul
2. **Select File** → `load_test_users.csv` seç
3. **Preview** ile verinin doğru yüklendiğini kontrol et

### Adım 4: Ayarları Yapılandır
```
Iterations: 1000 (otomatik CSV'den alınır)
Delay: 100ms (requests arası bekleme)
```

### Adım 5: Testleri Çalıştır
1. Çalıştırmak istediğin request'leri seç:
   - ✅ 1. Create User (Sign Up)
   - ✅ 2. Sign In (Login)
   - ✅ 3. Create User Profile
   - ✅ 4. Read Public Videos

2. **Run** butonuna tıkla

---

## 📊 Test Senaryoları

### Senaryo 1: Sadece Kullanıcı Oluşturma
- Request: `1. Create User (Sign Up)`
- Iterations: 1000
- Beklenen: 1000 yeni kullanıcı Firebase Auth'da

### Senaryo 2: Login Yük Testi
- Request: `2. Sign In (Login)`
- Iterations: 1000
- Beklenen: Tüm kullanıcılar başarıyla giriş yapar

### Senaryo 3: Tam Akış Testi
- Tüm 4 request seçili
- Iterations: 1000
- Her iterasyonda: SignUp → Login → Profile → Videos

---

## ⚠️ Önemli Uyarılar

### Firebase Limitleri
| Limit | Değer |
|-------|-------|
| Auth requests/saniye | ~100 |
| Firestore writes/saniye | ~500 |
| Firestore reads/saniye | ~50,000 |

### Önerilen Delay Ayarları
- **100 kullanıcı:** 0ms delay
- **500 kullanıcı:** 50ms delay
- **1000 kullanıcı:** 100ms delay

### Test Sonrası Temizlik
1000 test kullanıcısını silmek için Firebase Console'dan:
1. Authentication → Users → Bulk delete
2. Firestore → users collection → Delete

---

## 📈 Sonuçları Analiz Etme

### Runner Sonuç Ekranı
- **Total Requests:** Toplam istek sayısı
- **Passed:** Başarılı testler
- **Failed:** Başarısız testler
- **Average Response Time:** Ortalama yanıt süresi

### Export Seçenekleri
1. **Run Summary:** JSON formatında export
2. **Export Results:** Detaylı sonuçlar

### Performance Metrikleri
```
- Avg Response Time: < 500ms ✅
- 95th Percentile: < 1000ms ✅
- Error Rate: < 1% ✅
```

---

## 🖼️ Screenshot Alma

### Runner Başlamadan Önce
1. CSV yüklü ekranın screenshot'ı

### Test Sırasında
1. Progress bar'ın screenshot'ı

### Test Sonrası
1. Summary ekranının screenshot'ı
2. Graphs sekmesinin screenshot'ı (varsa)

---

## 🔧 Newman ile CLI Load Test (Opsiyonel)

```bash
# Newman kurulumu
npm install -g newman

# Load test çalıştır
newman run postman/Load_Test_Collection.postman_collection.json \
  -d postman/load_test_users.csv \
  -n 1000 \
  --delay-request 100 \
  --reporters cli,json \
  --reporter-json-export postman/load_test_results.json
```

---

## 📋 CSV Formatı

```csv
email,password,username,displayName
testuser1@loadtest.com,TestPass1!,loadtest_user_1,Load Test User 1
testuser2@loadtest.com,TestPass2!,loadtest_user_2,Load Test User 2
...
testuser1000@loadtest.com,TestPass1000!,loadtest_user_1000,Load Test User 1000
```

**Toplam:** 1000 satır (+ 1 header)
