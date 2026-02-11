# KirimLocal - Fast Local File Sharing

**KirimLocal** adalah alat berbasis CLI (command-line interface) untuk berbagi file secara cepat dan aman di jaringan lokal. Alat ini dirancang untuk memudahkan transfer file antar perangkat dalam jaringan yang sama tanpa perlu mengunggah ke layanan cloud.

## Fitur Utama

- **Transfer Cepat**: Menggunakan protokol efisien untuk transfer file dalam jaringan lokal
- **Enkripsi TLS**: Transfer file aman dengan enkripsi TLS
- **Kompresi**: Opsi kompresi gzip untuk file teks
- **Verifikasi Checksum**: Verifikasi integritas file setelah transfer
- **Clipboard Sharing**: Berbagi teks/link secara instan melalui clipboard
- **Auto-discovery**: Secara otomatis mendeteksi perangkat lain di jaringan
- **Antarmuka Pengguna yang Ramah**: Antarmuka berbasis teks dengan warna dan ikon
- **Cross-platform**: Kompatibel dengan Linux, macOS, dan Windows (melalui WSL)
- **Desktop Shortcut**: Pembuatan shortcut desktop otomatis

## Instalasi

### Instalasi Global (Disarankan)

Jalankan KirimLocal dan pilih opsi "Install Global" dari menu utama:

```bash
bash kirimlocal.sh
# Pilih opsi 'i' untuk instalasi global
```

Atau, instal secara langsung:

```bash
sudo ln -sf "$(pwd)/kirimlocal.sh" /usr/local/bin/kirimlocal
```

### Penggunaan Langsung

```bash
bash kirimlocal.sh
```

## Penggunaan

### Mode Interaktif

```bash
kirimlocal
```

Ini akan membuka menu interaktif dengan opsi:
- **1)** Receive Files: Menunggu file masuk dari perangkat lain
- **2)** Send Files: Mencari perangkat dan mengirim file
- **3)** Share Clipboard: Berbagi konten clipboard ke perangkat lain
- **h)** History: Melihat riwayat transfer
- **i)** Install Global: Instalasi ke PATH sistem
- **d)** Create Desktop Shortcut: Buat shortcut desktop
- **q)** Quit: Keluar dari aplikasi

### Mode Command Line

```bash
# Mode penerima
kirimlocal -r

# Kirim file
kirimlocal -s file1.txt file2.pdf

# Kirim dengan kompresi
kirimlocal -s -z file1.txt file2.txt

# Kirim dengan verifikasi checksum
kirimlocal -s -c file.zip

# Gunakan port kustom
kirimlocal -p 8888 -r

# Gunakan enkripsi TLS
kirimlocal -e -s file.txt

# Gunakan direktori unduhan kustom
kirimlocal -d ~/my_downloads -r
```

## Fitur-Fitur Lanjutan

### Enkripsi TLS
Gunakan flag `-e` untuk mengamankan transfer file dengan enkripsi TLS:

```bash
kirimlocal -e -s rahasia.docx
```

### Kompresi
Gunakan flag `-z` untuk mengompresi file sebelum dikirim (berguna untuk file teks):

```bash
kirimlocal -z -s log.txt
```

### Verifikasi Checksum
Gunakan flag `-c` untuk memverifikasi integritas file setelah transfer:

```bash
kirimlocal -c -s penting.zip
```

### Clipboard Sharing
Fitur baru yang memungkinkan berbagi konten clipboard secara instan:

1. Pilih opsi "Share Clipboard" dari menu utama
2. Kirim konten clipboard ke perangkat lain
3. Konten otomatis disalin ke clipboard penerima jika berupa teks

## Kompatibilitas Distro

KirimLocal dirancang untuk kompatibel dengan berbagai distribusi Linux populer:

- **Debian/Ubuntu-based**: Menggunakan `/usr/local/bin` atau `/usr/bin` dengan sudo
- **Red Hat/Fedora-based**: Kompatibel dengan DNF/YUM package management
- **Arch Linux-based**: Kompatibel dengan Pacman package management
- **SUSE/openSUSE-based**: Kompatibel dengan Zypper package management
- **Alpine Linux-based**: Kompatibel dengan APK package management
- **Generic POSIX Systems**: Fallback ke instalasi lokal pengguna

## Sistem Test

KirimLocal dilengkapi dengan sistem test komprehensif yang mencakup:

- **Unit Tests**: Pengujian fungsi-fungsi individual
- **Integration Tests**: Pengujian alur kerja end-to-end
- **Validation Tests**: Pengujian validasi input/output
- **UI Tests**: Pengujian komponen antarmuka

Jalankan test dengan:

```bash
bash test/run_tests.sh
```

## Kontribusi

Kontribusi sangat diterima! Silakan fork repositori ini dan kirim pull request untuk perbaikan atau fitur baru.

## Lisensi

Proyek ini dilisensikan di bawah lisensi MIT - lihat file [LICENSE](LICENSE) untuk detailnya.

## Roadmap

Fitur-fitur yang akan datang:

- [ ] **Desktop Notifications**: Notifikasi saat file diterima
- [ ] **Multi-target Send**: Kirim file ke beberapa perangkat sekaligus
- [ ] **QR Code Discovery**: Tampilkan QR code untuk koneksi cepat dari HP
- [ ] **Shell Completion**: Auto-complete untuk bash/zsh

## Troubleshooting

Jika mengalami masalah:
1. Pastikan port 9999 (untuk transfer) dan 9998 (untuk discovery) tidak digunakan oleh aplikasi lain
2. Pastikan semua dependensi terinstal: `socat`, `pv`, `tar`, `hostname`, `openssl`
3. Untuk masalah clipboard, pastikan perintah clipboard (pbcopy/pbpaste, xclip, xsel, atau wl-clipboard) terinstal
4. Jika instalasi global gagal, coba metode instalasi lokal ke `~/.local/bin`

## Dukungan

Jika Anda menemukan masalah atau memiliki saran, silakan buka issue di repositori GitHub.