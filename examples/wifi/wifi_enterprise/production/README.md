# Production Deployment Guide

## 🏭 ESP32-C3 Industrial Secure WiFi Enterprise - Production System

Bu klasör, ESP32-C3 cihazlarının endüstri standardında güvenli üretim sürecini otomatikleştiren dosyaları içerir.

---

## 📁 Dosyalar

### 1. `flash_secure_device.sh`
**Otomatik Production Flash Script**

#### Özellikler:
- ✅ Cihaz başına benzersiz şifreleme anahtarı üretimi
- ✅ NVS kimlik bilgilerinin otomatik şifrelenmesi
- ✅ Güvenli vault'a otomatik yedekleme
- ✅ Geçici dosyaların güvenli silinmesi (shred)
- ✅ Kapsamlı hata yönetimi ve loglama
- ✅ Production metadata takibi

#### Kullanım:
```bash
# ESP-IDF'yi aktive edin
source $IDF_PATH/export.sh

# Script'i çalıştırın
cd production
chmod +x flash_secure_device.sh
./flash_secure_device.sh

# WiFi şifresini girin (güvenli input)
# Script otomatik olarak:
# 1. Encryption key oluşturur
# 2. NVS credentials oluşturur
# 3. Şifreler
# 4. ESP32'ye yazar
# 5. Vault'a yedekler
# 6. Temp dosyaları siler
```

#### Ortam Değişkenleri:
```bash
export ESP_PORT=/dev/ttyUSB0          # ESP32 seri portu
export ESP_BAUD=921600                # Baud rate
export BACKUP_PATH=/secure/vault     # Backup lokasyonu
```

---

### 2. `nvs_credentials_template.csv`
**NVS Credentials Template**

Cihaz özel kimlik bilgileri için şablon dosyası.

#### İçerik:
- `wifi_creds` namespace
- `password` - WiFi şifresi (placeholder)
- `device_id` - Cihaz kimliği (placeholder)
- `firmware_version` - Firmware versiyonu

⚠️ **GÜVENLİK UYARISI:** Bu dosya sadece template'dir. Gerçek şifreler içermemelidir!

---

## 🔐 Güvenlik Özellikleri

### Flash Encryption
- Her cihaz için benzersiz encryption key
- eFuse'a yazılır (geri alınamaz)
- NVS partition şifrelenir

### NVS Encryption
- WiFi şifresi encrypted NVS'de saklanır
- Memory dump ile okunamaz
- Secure key management

### Backup System
- Tüm credentials güvenli vault'a yedeklenir
- Cihaz bazında klasörleme
- Metadata tracking (tarih, operator, etc.)

### Secure Deletion
- Geçici dosyalar `shred` ile silinir
- 3 geçişli random data override
- Memory'de kalıntı bırakmaz

---

## 📋 Production Workflow

### Adım 1: Hazırlık
```bash
# ESP-IDF kurulumu kontrol
echo $IDF_PATH

# Gerekli araçları kontrol
esptool.py version
python --version

# Backup dizini oluştur
mkdir -p /secure/vault/esp32_credentials
chmod 700 /secure/vault/esp32_credentials
```

### Adım 2: Production Flash
```bash
# Her cihaz için:
./flash_secure_device.sh

# WiFi şifresini girin
# Script otomatik işler
```

### Adım 3: Verification
```bash
# ESP32 seri monitor
idf.py monitor -p /dev/ttyUSB0

# WiFi bağlantısını kontrol edin
# Device ID'yi kaydedin
```

### Adım 4: Backup Kontrolü
```bash
# Backup'ı kontrol edin
ls -la /secure/vault/esp32_credentials/ESP32-FAB-*

# Metadata'yı görüntüleyin
cat /secure/vault/esp32_credentials/ESP32-FAB-*/metadata.txt
```

---

## 🛡️ Best Practices

### Production Ortamı
1. **Fiziksel Güvenlik**
   - Production bilgisayarını güvenli odada tutun
   - Erişimi sadece yetkili personele verin
   - Kamera ile izleyin

2. **Vault Güvenliği**
   - Backup path'i encrypted disk'te tutun
   - Düzenli off-site backup yapın
   - Access log tutun

3. **Operasyon Güvenliği**
   - Her cihazı kaydedin (seri numarası, device ID)
   - Production log tutun
   - Quality control yapın

### Recovery Stratejisi
1. **Backup Saklama**
   - 3-2-1 kuralı: 3 kopya, 2 ortam, 1 off-site
   - Cloud backup (encrypted)
   - HSM kullanın (büyük üretimler için)

2. **Kayıp Şifre Durumu**
   - Vault'tan credentials restore edin
   - Ya da factory reset yapın
   - NVS'yi yeniden yazın

---

## 🚨 Troubleshooting

### Hata: "ESP-IDF not found"
```bash
source $IDF_PATH/export.sh
```

### Hata: "esptool.py not found"
```bash
pip install esptool
```

### Hata: "Permission denied on /dev/ttyUSB0"
```bash
sudo usermod -a -G dialout $USER
# Logout/login gerekli
```

### Hata: "Flash encryption failed"
- ⚠️ eFuse zaten yazılmış olabilir (geri alınamaz!)
- Yeni bir ESP32 kullanın
- Test cihazlarında eFuse durumunu kontrol edin

---

## 📞 Destek ve İletişim

### Teknik Destek
- **Dokümantasyon:** ESP-IDF Security Guide
- **ESP32 Forum:** https://esp32.com
- **GitHub Issues:** Repository issue tracker

### Güvenlik Sorunları
Güvenlik açığı bulursanız:
1. Hemen production'ı durdurun
2. Sorunu isolated ortamda test edin
3. Security team'e rapor edin
4. Patch geliştirin
5. Etkilenen cihazları güncelleyin

---

## 📚 Referanslar

- [ESP-IDF Security Features](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/index.html)
- [Flash Encryption](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/flash-encryption.html)
- [NVS Encryption](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/storage/nvs_flash.html#nvs-encryption)
- [Secure Boot V2](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/secure-boot-v2.html)

---

**🔒 Güvenlik = Öncelik #1**

Bu production sistemi IEC 62443 ve ISO 27001 standartlarına uygun olarak tasarlanmıştır.
