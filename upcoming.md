# Upcoming Improvements

Daftar peningkatan yang belum diimplementasikan untuk LocalSend CLI.

## 🔧 Code Quality

- [ ] **ShellCheck Validation** - Jalankan ShellCheck dan perbaiki semua warning untuk memastikan kode mengikuti standar industri bash scripting.
- [ ] **Strict Mode** - Tambahkan `set -euo pipefail` di awal script dengan pengecualian yang aman untuk error handling lebih ketat.

## 📝 Documentation

- [ ] **README.md** - Buat dokumentasi lengkap dengan contoh penggunaan, screenshot, dan panduan instalasi yang lebih detail.
- [ ] **Man Page** - Buat manual page untuk integrasi dengan sistem `man`.

## 🧪 Testing & Debugging

- [ ] **Unit Tests** - Implementasi unit test menggunakan [bats-core](https://github.com/bats-core/bats-core).
- [ ] **File Logging** - Tambahkan opsi logging ke file (`~/.localsend.log`) untuk debugging.

## 🚀 Features (dari saran sebelumnya)

- [x] **Clipboard Sharing** - ✅ Implemented in v2.5
- [x] **Desktop Shortcut Creation** - ✅ Implemented in v2.5
- [x] **Renamed to KirimLocal** - ✅ Implemented in v2.5
- [ ] **Desktop Notifications** - Notifikasi menggunakan `notify-send` saat file diterima.
- [ ] **Multi-target Send** - Kirim file ke beberapa perangkat sekaligus.
- [ ] **QR Code Discovery** - Tampilkan QR code untuk koneksi cepat dari HP.
- [ ] **Shell Completion** - Auto-complete untuk bash/zsh.

## 🔍 Receive Mode Improvements

- [ ] **Pipeline Error Handling** - Gunakan `set -o pipefail` atau `PIPESTATUS` untuk mendeteksi error di pipeline `socat | pv | tar`.
- [ ] **Array Quoting** - Ubah `$socat_cmd` menjadi array `socat_cmd=(...)` dan panggil dengan `"${socat_cmd[@]}"` untuk keamanan.
- [ ] **Deduplicate Menu** - Ekstrak menu opsi port error (line 369-380 & 391-403) ke fungsi `prompt_port_action()`.
- [ ] **Magic Number Constant** - Ubah hardcoded `duration -lt 2` menjadi konstanta `MIN_LISTENER_DURATION=2`.

## 📥 File Receiving UX

- [ ] **Handshake Protocol** - Sender kirim metadata dulu (daftar file + total size), receiver konfirmasi sebelum transfer dimulai.
- [ ] **Accept/Reject Prompt** - Tampilkan list file yang akan masuk, user pilih terima atau tolak.
- [ ] **Overwrite Protection** - Cek file existing, tanya user mau overwrite atau rename.
- [x] **Percentage Progress** - ✅ Implemented in v2.5
- [ ] **Per-file Progress** - Indikasi file mana yang sedang di-transfer dari total daftar file.
