# Membangun Sistem Rekomendasi Fase Bencana dengan Flutter & Python

Dokumen ini merinci proses pembangunan aplikasi seluler "Sistem Rekomendasi Rencana Fase Bencana", sebuah alat pendukung keputusan yang dirancang untuk bekerja secara offline dengan model AI di perangkat.

### Abstrak Proyek

Manajemen bencana seringkali terkendala oleh data risiko yang kompleks dan sulit diterjemahkan menjadi aksi nyata. Proyek ini bertujuan untuk menjembatani kesenjangan tersebut dengan menciptakan aplikasi seluler yang memberikan rekomendasi taktis spesifik untuk tiga fase bencana: **Pra-Bencana (Kewaspadaan)**, **Saat-Bencana (Evakuasi)**, dan **Pasca-Bencana (Rehabilitasi)**. Solusi ini menggunakan pendekatan hybrid, menggabungkan model Machine Learning (TensorFlow Lite) untuk analisis pola kompleks dengan algoritma perankingan (SQL) yang efisien untuk tugas berbasis aturan, yang semuanya berjalan secara lokal di perangkat pengguna.

**Teknologi Utama:**

- **Backend & Model:** Python, Pandas, TensorFlow/Keras, Scikit-learn
- **Aplikasi Mobile:** Flutter, Riverpod (State Management), SQFlite
- **Database:** SQLite
- **Model AI:** TensorFlow Lite (TFLite)

### Prasyarat

- Flutter SDK terinstal.
- Lingkungan Python (disarankan menggunakan virtual environment seperti `venv` atau `conda`).
- Pengetahuan dasar tentang Python, Flutter, dan SQL.
- Tiga file data sumber: `bahaya.csv`, `kerentanan.csv`, `kapasitas.csv`.

---

## BAGIAN 1: Backend - Persiapan Data & Pembangunan Model (Python)

Bagian ini mencakup semua proses yang dilakukan di lingkungan Python untuk menyiapkan aset yang akan digunakan oleh aplikasi Flutter.

### Langkah 1.1: Membuat Database SQLite

Langkah pertama adalah mengubah data mentah dari beberapa file CSV menjadi satu file database SQLite yang terstruktur dan ternormalisasi. Ini memastikan data menjadi portabel, efisien untuk di-query, dan siap digunakan oleh aplikasi.

_(Gunakan skrip Python pertama yang Anda buat untuk mengonversi `bahaya.csv`, `kerentanan.csv`, dan `kapasitas.csv` menjadi satu file `data.db` dengan tabel `lokasi`, `bahaya`, `kerentanan`, dan `kapasitas`.)_

### Langkah 1.2: Membangun Model AI untuk Pra-Bencana

Untuk fase Pra-Bencana, kita memerlukan model AI untuk menemukan "kemiripan" profil bahaya. Kita menggunakan arsitektur **Autoencoder** untuk mengekstrak fitur penting (embedding) dari data.

**Logika:**

1.  **Feature Engineering:** Menggunakan **semua atribut** dari tabel `bahaya` (`rendah`, `sedang`, `tinggi`, `total`, `kelas_bahaya`, `kelas_resiko`) sebagai input.
2.  **Pra-pemrosesan:**
    - Kolom numerik dinormalisasi ke rentang 0-1 menggunakan `MinMaxScaler`.
    - Kolom kategorikal diubah menjadi format numerik menggunakan `One-Hot Encoding`.
3.  **Pelatihan:** Model Autoencoder dilatih untuk merekonstruksi fitur-fitur ini. Proses ini "memaksa" model untuk mempelajari representasi data yang paling efisien dalam sebuah _embedding vector_.
4.  **Konversi & Ekspor:** Bagian **Encoder** dari model (yang bertugas membuat embedding) diekspor ke format `encoder_model.tflite` dengan mode kompatibilitas untuk memastikan bisa berjalan di berbagai perangkat. Semua embedding untuk seluruh dataset juga dihitung dan disimpan dalam `all_embeddings.json` untuk pencarian yang sangat cepat di aplikasi.

**Kode Lengkap pada file `build_model.py`:**

---

## BAGIAN 2: Frontend - Aplikasi Rekomendasi (Flutter)

Bagian ini merinci pembangunan aplikasi Flutter yang menggunakan aset dari Bagian 1.

### Langkah 2.1: Setup Proyek & Aset

1.  Buat proyek Flutter baru: `flutter create disaster_reco`.
2.  Buat folder `assets` di dalam root proyek.
3.  Salin semua file dari folder `assets_for_flutter` (yang dihasilkan Python) ke dalam folder `assets` ini.
4.  Tambahkan dependensi di `pubspec.yaml`:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      sqflite: ^2.3.3+1
      path_provider: ^2.1.3
      tflite_flutter: ^0.10.4
      flutter_riverpod: ^2.5.1
      intl: ^0.19.0
    ```
5.  Daftarkan folder `assets` di `pubspec.yaml`:
    ```yaml
    flutter:
      assets:
        - assets/
    ```

### Langkah 2.2: Lapisan Servis (`database_helper.dart` & `tflite_service.dart`)

Ini adalah fondasi aplikasi kita, berinteraksi langsung dengan aset.

- **`database_helper.dart`:** Bertanggung jawab untuk menyalin database `data.db` dari aset ke penyimpanan lokal saat pertama kali aplikasi dijalankan. File ini juga berisi semua query SQL yang dibutuhkan, termasuk **logika perankingan hierarkis yang canggih** untuk fase Saat dan Pasca Bencana.
- **`tflite_service.dart`:** Bertugas memuat model `encoder_model.tflite` dan data `all_embeddings.json`. Fungsi utamanya adalah melakukan perhitungan **Cosine Similarity** untuk menemukan rekomendasi di fase Pra-Bencana.

### Langkah 2.3: Lapisan Logika (`recommendation_provider.dart`)

Menggunakan **Riverpod**, file ini bertindak sebagai "otak" aplikasi.

- Ia menjadi jembatan antara UI dan lapisan servis.
- Saat UI meminta rekomendasi, provider memanggil fungsi yang sesuai dari `database_helper` atau `tflite_service`.
- Ia mengelola state aplikasi (loading, success, error) sehingga UI dapat merespons secara reaktif.

### Langkah 2.4: Lapisan Antarmuka (UI)

UI dibangun secara modular dengan tiga tab utama untuk setiap fase.

- **Input Dinamis:** Semua menu dropdown (Provinsi, Kabupaten, dll.) mengambil data secara dinamis dari database SQLite, bukan data dummy.
- **Tampilan Hasil:** Hasil rekomendasi ditampilkan dalam bentuk kartu (`RecommendationCard`) yang informatif.
- **Fitur Detail:** Setiap kartu rekomendasi memiliki tombol "Detail" yang akan menampilkan semua data mentah dari tabel yang relevan (`bahaya`, `kerentanan`, atau `kapasitas`) dalam sebuah dialog popup.
- **State Management:** UI secara otomatis menampilkan indikator loading saat data diproses dan pesan error jika terjadi masalah, berkat integrasi dengan Riverpod.

---

### Kesimpulan & Logika Final

Proyek ini berhasil menghasilkan sebuah prototipe aplikasi yang kuat dengan pendekatan hybrid:

- **Pra-Bencana** menggunakan **AI** untuk menemukan kemiripan pola yang kompleks.
- **Saat & Pasca Bencana** menggunakan **logika perankingan SQL hierarkis** yang sangat efisien untuk tugas-tugas berbasis aturan yang jelas.

Arsitektur ini memastikan setiap fase ditangani dengan metode yang paling sesuai, menciptakan alat pendukung keputusan yang cerdas, cepat, andal, dan siap untuk diuji coba di lapangan.
