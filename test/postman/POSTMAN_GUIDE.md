# Firebase API Testing with Postman

Bu rehber, Digital Diary uygulamasının Firebase API'lerini Postman ile nasıl test edeceğinizi açıklar.

---

## 📥 1. Postman Collection'ı Import Etme

1. **Postman'i açın** (yoksa https://www.postman.com/downloads/ adresinden indirin)
2. Sol üstteki **Import** butonuna tıklayın
3. `postman/Firebase_API_Collection.postman_collection.json` dosyasını sürükleyin
4. **Import** butonuna tıklayın

---

## 🔧 2. Collection Yapısı

```
Digital Diary - Firebase API Tests
├── 1. Authentication
│   ├── 1.1 Sign Up (Create User)
│   ├── 1.2 Sign In (Login)
│   ├── 1.3 Get User Data
│   ├── 1.4 Refresh Token
│   └── 1.5 Password Reset Email
├── 2. Firestore Database
│   ├── 2.1 Create User Profile
│   ├── 2.2 Get User Profile
│   ├── 2.3 Create Video Document
│   ├── 2.4 Query Public Videos
│   ├── 2.5 Update Video (Like)
│   └── 2.6 Delete Video
├── 3. Error Cases
│   ├── 3.1 Login - Invalid Password
│   ├── 3.2 Login - User Not Found
│   └── 3.3 Firestore - Unauthorized
└── 4. Cleanup
    ├── 4.1 Delete Test User Profile
    └── 4.2 Delete Test User Account
```

---

## 🚀 3. Testleri Çalıştırma

### Adım 1: İlk Kullanıcı Oluşturma
1. `1. Authentication` → `1.1 Sign Up` isteğini açın
2. **Send** butonuna tıklayın
3. Başarılı olursa `ID_TOKEN` ve `USER_ID` otomatik kaydedilir

### Adım 2: Giriş Yapma
1. `1.2 Sign In` isteğini çalıştırın
2. Token'lar güncellenir

### Adım 3: Firestore İşlemleri
1. `2.1 Create User Profile` → Kullanıcı profili oluşturur
2. `2.2 Get User Profile` → Profili okur
3. `2.3 Create Video` → Video dökümanı oluşturur
4. `2.4 Query Videos` → Public videoları sorgular
5. `2.5 Update Video` → Like sayısını günceller

### Adım 4: Temizlik
1. `4.1 Delete User Profile` → Firestore verisini siler
2. `4.2 Delete User Account` → Firebase Auth hesabını siler

---

## 🏃 4. Collection Runner ile Otomatik Test

1. Collection'a sağ tıklayın → **Run collection**
2. Çalıştırmak istediğiniz request'leri seçin
3. **Run** butonuna tıklayın
4. Sonuçları inceleyin ve **screenshot** alın

### Runner Sırası (Önerilen):
```
1. 1.1 Sign Up
2. 1.2 Sign In
3. 2.1 Create User Profile
4. 2.2 Get User Profile
5. 2.3 Create Video Document
6. 2.4 Query Public Videos
7. 2.5 Update Video (Like)
8. 2.6 Delete Video
9. 3.1 Login - Invalid Password
10. 3.2 Login - User Not Found
11. 4.1 Delete Test User Profile
12. 4.2 Delete Test User Account
```

---

## 📊 5. Test Sonuçlarını Görüntüleme

Her request'in **Tests** sekmesinde otomatik testler var:

```javascript
// Örnek test
pm.test('Status code is 200', function () {
    pm.response.to.have.status(200);
});

pm.test('Response has idToken', function () {
    pm.expect(pm.response.json()).to.have.property('idToken');
});
```

### Screenshot Alma:
1. Runner çalıştırdıktan sonra sonuç ekranını görün
2. **Win + Shift + S** ile screenshot alın
3. `screenshots/postman_results.png` olarak kaydedin

---

## 🔑 6. Collection Variables

| Variable | Açıklama | Değer |
|----------|----------|-------|
| `API_KEY` | Firebase Web API Key | `YOUR_API_KEY` |
| `PROJECT_ID` | Firebase Project ID | `digitaldiaryapp-591c2` |
| `ID_TOKEN` | Oturum token'ı | *(Otomatik set edilir)* |
| `USER_ID` | Kullanıcı ID | *(Otomatik set edilir)* |
| `REFRESH_TOKEN` | Yenileme token'ı | *(Otomatik set edilir)* |
| `VIDEO_ID` | Video döküman ID | *(Otomatik set edilir)* |

---

## 🌐 7. Firebase REST API Endpoints

### Authentication API
```
Base URL: https://identitytoolkit.googleapis.com/v1

POST /accounts:signUp?key={API_KEY}        - Yeni kullanıcı
POST /accounts:signInWithPassword?key=...  - Giriş
POST /accounts:lookup?key=...              - Kullanıcı bilgisi
POST /accounts:sendOobCode?key=...         - Şifre sıfırlama
POST /accounts:delete?key=...              - Hesap silme
```

### Firestore REST API
```
Base URL: https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents

GET    /{collection}/{docId}     - Döküman oku
POST   /{collection}             - Yeni döküman
PATCH  /{collection}/{docId}     - Döküman güncelle
DELETE /{collection}/{docId}     - Döküman sil
POST   :runQuery                 - Sorgu çalıştır
```

---

## ⚠️ 8. Önemli Notlar

1. **Test Ortamı Kullanın:** Mümkünse production Firebase yerine test projesi kullanın
2. **Token Süresi:** ID Token'lar 1 saat geçerli, `Refresh Token` ile yenileyebilirsiniz
3. **Firestore Rules:** Test için rules'ları geçici olarak açmanız gerekebilir:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
4. **Cleanup:** Test sonrası `4. Cleanup` klasöründeki istekleri çalıştırın

---

## 📸 9. Rapor için Screenshot Alma

### Collection Runner Sonuçları:
1. Collection'a sağ tık → Run collection
2. Tüm testleri çalıştır
3. Yeşil (✓) ve kırmızı (✗) sonuçları gösteren ekranın screenshot'ını al

### Tek Request Test Sonucu:
1. Request'i çalıştır
2. Alt kısımdaki **Test Results** sekmesine tık
3. PASS/FAIL durumunu gösteren screenshot al

### Export Seçenekleri:
- **Run Summary:** Runner'da "Export Results" butonu
- **JSON Export:** Sonuçları JSON olarak kaydet
- **HTML Report:** Newman CLI ile HTML rapor oluştur

---

## 🔧 10. Newman ile CLI Testing (Opsiyonel)

```bash
# Newman kurulumu
npm install -g newman
npm install -g newman-reporter-htmlextra

# Collection'ı çalıştır
newman run postman/Firebase_API_Collection.postman_collection.json

# HTML rapor ile çalıştır
newman run postman/Firebase_API_Collection.postman_collection.json -r htmlextra --reporter-htmlextra-export postman/test_report.html
```

---

**Hazırlayan:** GitHub Copilot  
**Tarih:** December 15, 2025
