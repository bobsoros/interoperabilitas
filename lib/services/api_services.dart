import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Ditambahkan untuk penembakan API Eksternal
import 'package:image_picker/image_picker.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import 'package:tubes/models/post.dart';

// =========================================================================
// 1. BACKEND LOGIC: API SERVICE (SUPABASE & INTEGRASI API EKSTERNAL)
// =========================================================================
class ApiService {
  final supabase = Supabase.instance.client;

  /// Fungsi untuk mengunggah file gambar ke Supabase Storage (Aman untuk Web & Mobile)
  Future<String?> uploadFileBarang(XFile xFile, String fileName) async {
    try {
      int fileSizeInBytes = await xFile.length();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 5.0) {
        throw Exception('Ukuran file terlalu besar! Maksimal batasan adalah 5MB.');
      }

      final String path = 'barang/$fileName';

      // Mengubah file menjadi Bytes agar aman di Web maupun Mobile
      final Uint8List fileBytes = await xFile.readAsBytes();
      
      // Menggunakan 'gudang_files' sesuai dengan konfigurasi bucket Anda
      await supabase.storage.from('gudang_files').uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // Mengambil URL Publik hasil unggahan
      final String publicUrl = supabase.storage.from('gudang_files').getPublicUrl(path);
      return publicUrl;
      
    } catch (e) {
      throw Exception('Gagal mengunggah file: ${e.toString()}');
    }
  }

  /// Fungsi untuk menyimpan informasi data barang baru ke tabel 'posts'
  Future<Map<String, dynamic>> createAssetPost(Post newAsset) async {
    try {
      final response = await supabase
          .from('posts')
          .insert(newAsset.toJson())
          .select() // Mengambil data real-time yang baru digenerate oleh Supabase
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Gagal menyimpan data barang ke database: ${e.toString()}');
    }
  }

  /// Fungsi Utama: Upload gambar, simpan record ke table posts, & picu notifikasi sukses
  Future<Map<String, dynamic>?> uploadDanSimpanBarang({
    required BuildContext context, 
    required XFile fileGambar,
    required String namaFile,
    required String judulBarang,
    required String deskripsiBody,
    required int userId,
    required String status,
  }) async {
    try {
      // Step A: Upload gambar ke storage
      String? urlGambar = await uploadFileBarang(fileGambar, namaFile);

      if (urlGambar == null) {
        throw Exception('Gagal mendapatkan URL gambar dari storage.');
      }

      // Step B: Mengambil Waktu Universal Presisi dari API Waktu Publik sebelum simpan ke DB
      DateTime waktuServer = await ambilWaktuServerPresisi();

      // Step C: Buat data model Post (Mencatat waktu server yang valid)
      Post dataBarangBaru = Post(
        title: judulBarang,
        body: '$deskripsiBody | Diunggah pada: ${waktuServer.toIso8601String()}',
        userId: userId,
        status: status,
        imageUrl: urlGambar,
      );

      // Step D: Simpan ke tabel 'posts'
      final Map<String, dynamic> resultData = await createAssetPost(dataBarangBaru);
      
      // VALIDASI NOTIFIKASI: Pastikan widget masih aktif di pohon widget sebelum render UI
      if (!context.mounted) return resultData;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifikasi: Barang Telah Berhasil Dikirim!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32), 
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );

      return resultData;
      
    } catch (e) {
      print('Error uploadDanSimpanBarang: $e');
      if (!context.mounted) return null;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim barang: $e'),
          backgroundColor: Colors.red,
        ),
      );
      rethrow;
    }
  }

  /// Mengambil daftar tugas / riwayat posts dengan penanganan tipe data yang aman
  Future<List<Post>> getAssetPosts() async {
    try {
      final response = await supabase
          .from('posts') 
          .select()
          .order('id', ascending: false);

      final List<Post> parsedPosts = [];
      
      if (response is List) {
        for (var json in response) {
          try {
            if (json['title'] != null) {
              final Map<String, dynamic> sanitizedJson = Map<String, dynamic>.from(json);
              
              if (sanitizedJson['id'] != null) {
                sanitizedJson['id'] = sanitizedJson['id'].toString();
              }
              if (sanitizedJson['user_id'] != null) {
                sanitizedJson['user_id'] = sanitizedJson['user_id'].toString();
              }

              parsedPosts.add(Post.fromJson(sanitizedJson));
            }
          } catch (itemError) {
            debugPrint('Melewati baris data ID ${json['id']} karena tidak cocok dengan Model Post: $itemError');
          }
        }
      }
      
      return parsedPosts;
    } catch (e) {
      debugPrint('Error fatal getAssetPosts: $e');
      return []; 
    }
  }

  /// Fungsi mengambil data master dari tabel 'gudang' 
  Future<List<Map<String, dynamic>>> getDaftarGudang() async {
    try {
      final response = await supabase.from('gudang').select();
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      debugPrint('Error Fetch Data Gudang: $e');
      return [];
    }
  }

  // =========================================================================
  // INTEGRASI API EKSTERNAL TAMBAHAN (PUBLIC & GRATIS)
  // =========================================================================

  /// A. MODE LAPORAN CUACA RUTE LOGISTIK (OpenWeatherMap API)
  Future<Map<String, dynamic>> ambilCuacaTujuan(String namaKota) async {
    const String apiKey = '85c3bde7bc8516d7a46c1b356e9c1e45'; 
    final Uri url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$namaKota,ID&appid=$apiKey&units=metric&lang=id'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'suhu': '${data['main']['temp'].toStringAsFixed(0)}°C',
          'kondisi': data['weather'][0]['description'].toString(),
          'sukses': true,
        };
      }
      return {'kondisi': 'Gagal memuat cuaca', 'suhu': '--', 'sukses': false};
    } catch (e) {
      return {'kondisi': 'Koneksi terganggu', 'suhu': '--', 'sukses': false};
    }
  }

  /// B. MODE SINKRONISASI WAKTU PRESISI (WorldTimeAPI)
  Future<DateTime> ambilWaktuServerPresisi() async {
    final Uri url = Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Jakarta');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return DateTime.parse(data['datetime']);
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}

// =========================================================================
// 2. UI LOGIC: MODAL POP-UP DIALOG QR CODE (FIXED VISIBILITY)
// =========================================================================
void tampilkanModalQR({
  required BuildContext context, 
  required String itemId, 
  required String origin, 
  required String destination,
}) {
  final String validQrData = (itemId.isEmpty || itemId == 'null') ? "ID_TIDAK_TERDETEKSI" : itemId;

  showDialog(
    context: context,
    barrierDismissible: false, 
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Color(0xFF1A365D), width: 2), 
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Text(
                'BARANG BERHASIL DIUNGGAH!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
              ),
              const SizedBox(height: 5),
              const Text(
                'QR CODE BARANG DITEMPEL:',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              
              SizedBox(
                width: 160.0,
                height: 160.0,
                child: QrImageView(
                  data: validQrData,
                  version: QrVersions.auto,
                  size: 160.0,
                  gapless: false,
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text(
                        "Gagal memuat visual QR",
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ITEM ID: $validQrData',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Origin: $origin\nDest: $destination',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC51F1F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); 
                  },
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text(
                    'Cetak Label QR untuk Box', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}