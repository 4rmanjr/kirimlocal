# KirimLocal CLI - Refaktor Nama dari LocalSend ke KirimLocal

## Ringkasan

Nama proyek telah berhasil direfaktor dari "LocalSend" ke "KirimLocal" untuk sesuai dengan nama repositori GitHub. Ini mencakup perubahan pada semua aspek dari aplikasi, termasuk:

## Perubahan yang Telah Dilakukan

### 1. Nama File Utama
- File `localsend.sh` telah diubah menjadi `kirimlocal.sh`

### 2. Nama Internal Aplikasi
- Semua referensi ke "LocalSend" diubah menjadi "KirimLocal"
- Versi aplikasi sekarang menampilkan "KirimLocal CLI v2.5"
- Nama aplikasi dalam antarmuka pengguna telah diperbarui

### 3. Konfigurasi dan Direktori
- Direktori konfigurasi berubah dari `~/.localsend_certs` ke `~/.kirimlocal_certs`
- File histori berubah dari `~/.localsend_history` ke `~/.kirimlocal_history`
- Direktori unduhan default berubah dari `~/Downloads/LocalSend` ke `~/Downloads/KirimLocal`

### 4. Protokol Discovery
- Protokol discovery berubah dari `LOCALSEND_SCAN`/`LOCALSEND_PEER` ke `KIRIMLOCAL_SCAN`/`KIRIMLOCAL_PEER`

### 5. Fungsi dan Variabel Internal
- Sertifikat SSL berubah dari `localsend.pem` ke `kirimlocal.pem`
- File temporary berubah dari `localsend_$$` ke `kirimlocal_$$`

### 6. Fungsi Instalasi
- Fungsi `install_global` sekarang menginstal ke `kirimlocal` daripada `localsend`
- Pesan-pesan instalasi telah diperbarui

### 7. Desktop Entry
- File desktop entry berubah dari `LocalSend.desktop` ke `KirimLocal.desktop`
- Nama aplikasi di desktop entry telah diperbarui
- Deskripsi dan perintah dalam desktop entry telah diperbarui

### 8. Sistem Test
- Semua file test telah diperbarui untuk merujuk ke `kirimlocal.sh`
- File temporary dalam test berubah dari `localsend_functions.sh` ke `kirimlocal_functions.sh`
- Referensi histori dalam test telah diperbarui

### 9. Dokumentasi
- File dokumentasi telah diperbarui untuk mencerminkan nama baru
- File `DESKTOP_SHORTCUT_FEATURE.md` telah diperbarui
- File `TESTING_SYSTEM_SUMMARY.md` telah diperbarui
- File `upcoming.md` telah diperbarui
- File `Makefile` telah diperbarui

## Kompatibilitas
- Semua fungsionalitas utama tetap berjaga
- Fitur-fitur tambahan seperti clipboard sharing dan desktop shortcut tetap berfungsi
- Sistem test tetap berjalan dengan sempurna
- Instalasi global dan lokal tetap berfungsi di berbagai distribusi Linux

## Penggunaan
- Perintah sebelumnya: `bash localsend.sh` sekarang menjadi `bash kirimlocal.sh`
- Perintah setelah instalasi: `localsend` sekarang menjadi `kirimlocal`
- Semua opsi dan fungsionalitas tetap sama

## Status
- Semua test melewati (7/7)
- Tidak ada kerusakan fungsionalitas
- Nama sekarang konsisten dengan repositori GitHub
- Siap untuk digunakan produksi