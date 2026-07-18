import 'dart:io' show File;
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 

import 'package:tubes/services/api_services.dart'; 
import 'package:tubes/models/post.dart'; 
import 'package:tubes/screens/qr_scanner_screen.dart'; 
import 'package:tubes/screens/login_screen.dart'; 

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = false;
  
  XFile? _selectedImage;
  XFile? _profileImage; 
  Uint8List? _profileImageBytesWeb; 
  final ApiService _apiService = ApiService();
  
  static const Color primaryColor = Color(0xFF0A192F);     
  static const Color accentColor = Color(0xFFD4AF37);       
  static const Color secondaryColor = Color(0xFF172A45);   
  static const Color backgroundColor = Color(0xFFF4F7FA);  
  static const Color textDark = Color(0xFF1E293B);         
  static const Color cardColor = Colors.white;

  final List<Post> _uploadedAssets = [
    Post(
      id: 812941,
      title: 'LAPTOP ASUS ROG',
      body: 'Jenis: LAPTOP ASUS ROG | Jml: 5 | Berat: 12.5kg | Ke: GUDANG SURABAYA | Ket: Barang elektronik harap hati-hati | Waktu: 09 Jul 2026, 10:00',
      status: 'DIKIRIM',
    ),
    Post(
      id: 391024,
      title: 'SEMEN TIGA RODA',
      body: 'Jenis: SEMEN TIGA RODA | Jml: 40 | Berat: 2000kg | Ke: GUDANG MADIUN | Ket: Taruh di area tertutup | Waktu: 09 Jul 2026, 11:30',
      status: 'DIKIRIM',
    ),
    Post(
      id: 571922,
      title: 'KABEL FO ROLL',
      body: 'Jenis: KABEL FO ROLL | Jml: 2 | Berat: 150kg | Ke: GUDANG JAKARTA | Ket: Proyek backbone | Waktu: 08 Jul 2026, 15:45',
      status: 'SELESAI',
    ),
  ];
  
  String _selectedLocation = 'GUDANG SURABAYA';

  final TextEditingController _jenisBarangController = TextEditingController();
  final TextEditingController _jumlahBarangController = TextEditingController(text: '1');
  final TextEditingController _beratBarangController = TextEditingController(text: '0.5');
  final TextEditingController _keteranganController = TextEditingController();

  final TextEditingController _passwordLamaController = TextEditingController();
  final TextEditingController _passwordBaruController = TextEditingController();

  final List<String> _titles = [
    'Kirim Cepat (Origin)',
    'Kirim Cepat (Manifest Gudang)',
    'Riwayat Global',
    'Konfirmasi Penerimaan', 
    'Profil Akun Admin'
  ];

  final Map<String, Map<String, String>> _lokasiDetail = {
    'GUDANG SURABAYA': {'jarak': '312 km', 'estimasi': '1 - 2 Hari', 'cuaca': 'Cerah Berawan', 'suhu': '32°C'},
    'GUDANG JAKARTA': {'jarak': '441 km', 'estimasi': '2 - 3 Hari', 'cuaca': 'Hujan Ringan', 'suhu': '27°C'},
    'GUDANG MADIUN': {'jarak': '205 km', 'estimasi': '1 Hari', 'cuaca': 'Cerah', 'suhu': '33°C'},
    'GUDANG BANDUNG': {'jarak': '367 km', 'estimasi': '2 Hari', 'cuaca': 'Berawan', 'suhu': '24°C'},
  };

  @override
  void dispose() {
    _jenisBarangController.dispose();
    _jumlahBarangController.dispose();
    _beratBarangController.dispose();
    _keteranganController.dispose();
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    super.dispose();
  }

  void _resetFormBarang() {
    _jenisBarangController.clear();
    _jumlahBarangController.text = '1';
    _beratBarangController.text = '0.5';
    _keteranganController.clear();
    _selectedImage = null;
  }

  String _getFormatTanggalManual(DateTime dateTime) {
    const daftarBulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return "${dateTime.day.toString().padLeft(2, '0')} ${daftarBulan[dateTime.month - 1]} ${dateTime.year}";
  }

  Future<void> _gantiFotoProfilPribadi() async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() { _profileImageBytesWeb = bytes; _profileImage = image; });
        } else {
          setState(() { _profileImage = image; });
        }
        _showSnackBar('Foto profil berhasil diperbarui!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Gagal mengakses kamera: $e', Colors.red);
    }
  }

  Future<void> _logoutSistem() async {
    setState(() { _isLoading = true; });
    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      _showSnackBar('Berhasil keluar dari sistem.', Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()), 
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Gagal memproses logout: $e', Colors.red);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _aksiCetakLabel({required String itemId, required String origin, required String destination}) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(70 * PdfPageFormat.mm, 70 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('LOGISTIK BOX LABEL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.SizedBox(width: 80, height: 80, child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: itemId, drawText: false)),
                  pw.SizedBox(height: 5),
                  pw.Text('ITEM ID: $itemId', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Dari: $origin | Ke: $destination', style: const pw.TextStyle(fontSize: 6)),
                ],
              ),
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Label_$itemId');
    } catch (e) {
      _showSnackBar('Gagal mencetak: $e', Colors.red);
    }
  }

  void tampilkanModalQR(BuildContext context, String itemId, String origin, String destination) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
              const SizedBox(height: 12),
              const Text('PROSES BERHASIL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryColor, letterSpacing: 0.5)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(data: itemId, version: QrVersions.auto, size: 140.0),
              ),
              const SizedBox(height: 16),
              Text('ID: $itemId', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: secondaryColor)),
              const SizedBox(height: 8),
              Text('$origin ➔ $destination', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () { Navigator.pop(context); _aksiCetakLabel(itemId: itemId, origin: origin, destination: destination); },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak Dokumen Label', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void tampilkanModalFormBarang(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text('MANIFES DATA BARANG', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryColor, letterSpacing: 0.5))),
                const SizedBox(height: 16),
                _buildElegantTextField(_jenisBarangController, 'Jenis Barang', Icons.inventory_2_outlined),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildElegantTextField(_jumlahBarangController, 'Jumlah', Icons.format_list_numbered, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildElegantTextField(_beratBarangController, 'Berat (kg)', Icons.scale_outlined, isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 14),
                _buildElegantTextField(_keteranganController, 'Keterangan Tambahan', Icons.sticky_note_2_outlined, maxLines: 2),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, 
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor, foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                    onPressed: () {
                      if (_jenisBarangController.text.isEmpty) { _showSnackBar('Jenis barang wajib diisi!', Colors.orange); return; }
                      Navigator.pop(context);
                      _pickAndUploadImage();
                    },
                    icon: const Icon(Icons.camera_enhance_rounded, size: 18),
                    label: const Text('Ambil Foto & Daftarkan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantTextField(TextEditingController controller, String label, IconData icon, {bool isNumeric = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentColor, width: 1.5)),
          ),
        ),
      ],
    );
  }

  void _tampilkanDialogGantiPassword() {
    _passwordLamaController.clear();
    _passwordBaruController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keamanan Autentikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _passwordLamaController, obscureText: true, decoration: const InputDecoration(labelText: 'Password Lama', prefixIcon: Icon(Icons.lock_outline, size: 18))),
            const SizedBox(height: 10),
            TextField(controller: _passwordBaruController, obscureText: true, decoration: const InputDecoration(labelText: 'Password Baru', prefixIcon: Icon(Icons.lock_reset, size: 18))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (_passwordLamaController.text.isEmpty || _passwordBaruController.text.isEmpty) return;
              Navigator.pop(context);
              _showSnackBar('Password berhasil diperbarui.', Colors.green);
            },
            child: const Text('Update'),
          )
        ],
      ),
    );
  }

  Future<void> _hubungiTimIT() async {
    final Uri whatsappUri = Uri.parse("https://wa.me/628123456789?text=Halo%20Tim%20IT%20Logistik...");
    try {
      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('Menghubungkan ke IT Support...', Colors.green);
      } else {
        throw 'Error';
      }
    } catch (_) {
      final Uri telUri = Uri.parse("tel:021500999");
      if (await canLaunchUrl(telUri)) await launchUrl(telUri);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), content: Text(message)));
  }

  Future<void> _prosesPenerimaanBarang(String qrData) async {
    final int? scannedId = int.tryParse(qrData.trim());
    if (scannedId == null) return;
    setState(() { _isLoading = true; });
    try {
      setState(() {
        int index = _uploadedAssets.indexWhere((element) => element.id == scannedId);
        if (index != -1) {
          _uploadedAssets[index] = Post(id: _uploadedAssets[index].id, title: _uploadedAssets[index].title, body: _uploadedAssets[index].body, status: 'SELESAI');
        }
      });
      _showSnackBar('Manifes Penerimaan Berhasil Disimpan.', Colors.green);
    } finally { 
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;
    setState(() { _isLoading = true; _selectedImage = image; });
    try {
      final DateTime waktuSekarang = DateTime.now();
      await _apiService.uploadFileBarang(_selectedImage!, '${waktuSekarang.millisecondsSinceEpoch}.jpg');
      
      int randomId = Random().nextInt(900000) + 100000;
      String formattedDate = _getFormatTanggalManual(waktuSekarang);
      String bodyText = 'Jenis: ${_jenisBarangController.text} | Jml: ${_jumlahBarangController.text} | Berat: ${_beratBarangController.text}kg | Ke: $_selectedLocation | Waktu: $formattedDate';

      Post newAsset = Post(id: randomId, title: _jenisBarangController.text.toUpperCase(), body: bodyText, status: 'DIKIRIM');
      try { await _apiService.createAssetPost(newAsset); } catch (_) {}
      
      setState(() { _uploadedAssets.insert(0, newAsset); });
      tampilkanModalQR(context, randomId.toString(), 'Gudang Semarang', _selectedLocation);
      _resetFormBarang();
    } catch (e) { 
      _showSnackBar('Gagal memproses data.', Colors.red); 
    } finally { 
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16, letterSpacing: 0.5)),
        backgroundColor: primaryColor, 
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: accentColor)) : IndexedStack(
        index: _currentIndex,
        children: [ _buildKirimTab(), _buildTugasTab(), _buildRiwayatTab(), _buildTerimaTab(), _buildAkunTab() ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) { setState(() { _currentIndex = index; }); },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_outlined), activeIcon: Icon(Icons.space_dashboard), label: 'Kirim'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Tugas'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Riwayat'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_outlined), activeIcon: Icon(Icons.qr_code_scanner), label: 'Terima'), 
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined), activeIcon: Icon(Icons.manage_accounts), label: 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildKirimTab() {
    String cuacaTujuan = _lokasiDetail[_selectedLocation]?['cuaca'] ?? 'Cerah';
    String suhuTujuan = _lokasiDetail[_selectedLocation]?['suhu'] ?? '30°C';
    String tanggalSaja = _getFormatTanggalManual(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [secondaryColor, primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1E3A5F),
                  child: Icon(Icons.wb_cloudy_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SISTEM RUTE TUJUAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade200, letterSpacing: 1)),
                      const SizedBox(height: 2),
                      Text('$_selectedLocation ➔ $cuacaTujuan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
                Text(suhuTujuan, style: const TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 16))
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Text('Welcome Back, Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
            const Spacer(), 
            Text(tanggalSaja, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)), 
            child: Row(children: [
              const Icon(Icons.roofing_rounded, size: 32, color: primaryColor), 
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: const [ 
                  Text('GUDANG SEMARANG HUB', style: TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)), 
                  Text('Titik Keberangkatan Asal', style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.w500)) 
                ],
              )
            ]),
          ),
          const SizedBox(height: 24),
          const Text('DESTINASI DISTRIBUSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black45, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2, 
            children: [
              _buildLocationCard('GUDANG SURABAYA'), _buildLocationCard('GUDANG JAKARTA'), 
              _buildLocationCard('GUDANG MADIUN'), _buildLocationCard('GUDANG BANDUNG'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _resetFormBarang(); tampilkanModalFormBarang(context); }, 
              style: ElevatedButton.styleFrom(
                elevation: 3, shadowColor: primaryColor.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              child: Text('BUAT MANIFES KE PUSAT ${ _selectedLocation.split(' ')[1] }', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLocationCard(String title) {
    bool isSel = _selectedLocation == title;
    String jarak = _lokasiDetail[title]?['jarak'] ?? '0 km';
    String estimasi = _lokasiDetail[title]?['estimasi'] ?? '-';
    return InkWell(
      onTap: () { setState(() { _selectedLocation = title; }); },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : cardColor, 
          border: Border.all(color: isSel ? accentColor : Colors.grey.shade200, width: isSel ? 2 : 1), 
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSel ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))] : []
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [ 
            Icon(Icons.business_center_rounded, color: isSel ? accentColor : Colors.blueGrey.shade300, size: 24), 
            const SizedBox(height: 8), 
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? primaryColor : textDark), textAlign: TextAlign.center), 
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(jarak, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                Text(estimasi, style: const TextStyle(fontSize: 10, color: secondaryColor, fontWeight: FontWeight.w600)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTugasTab() {
    final daftarTugas = _uploadedAssets.where((post) => post.status == 'DIKIRIM').toList();
    if (daftarTugas.isEmpty) return const Center(child: Text('Tidak ada pengiriman aktif.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: daftarTugas.length,
      itemBuilder: (context, index) {
        final asset = daftarTugas[index];
        return Card(
          elevation: 0, color: cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade100)),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3CD), child: Icon(Icons.local_shipping_rounded, color: Colors.orange, size: 20)),
            title: Text(asset.title, style: const TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)),
            subtitle: Text(asset.body, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
              child: const Text('OTW', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRiwayatTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: _uploadedAssets.length,
      itemBuilder: (context, index) {
        final a = _uploadedAssets[index]; 
        bool isSelesai = a.status == 'SELESAI';
        return Card(
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade100)),
          child: ListTile(
            leading: Icon(isSelesai ? Icons.check_circle_rounded : Icons.pending_rounded, color: isSelesai ? Colors.teal : Colors.blueAccent),
            title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
            subtitle: Text(a.body, style: const TextStyle(fontSize: 11)),
          ),
        );
      },
    );
  }

  Widget _buildTerimaTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_rounded, size: 80, color: primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () async {
              final String? hasilScanQr = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen()));
              if (hasilScanQr != null && hasilScanQr.isNotEmpty) _prosesPenerimaanBarang(hasilScanQr);
            },
            icon: const Icon(Icons.center_focus_weak_rounded),
            label: const Text('SCAN QR TERIMA MANIFEST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAkunTab() {
    final listKirim = _uploadedAssets.where((e) => e.status == 'DIKIRIM').toList();
    final listTerima = _uploadedAssets.where((e) => e.status == 'SELESAI').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profil
          const Center(
            child: Text(
              'Admin Logistik Utama', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)
            ),
          ),
          const Center(
            child: Text(
              'HQ Platform Operator • Semarang', 
              style: TextStyle(color: Colors.grey, fontSize: 12)
            ),
          ),
          
          const SizedBox(height: 24),

          // Tombol Aksi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textDark,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _tampilkanDialogGantiPassword,
                    icon: const Icon(Icons.vpn_key_outlined, size: 16),
                    label: const Text('Ganti Sandi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _hubungiTimIT,
                    icon: const Icon(Icons.headset_mic_outlined, size: 16),
                    label: const Text('Hubungi IT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Section Riwayat Aktivitas Pengiriman
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('RIWAYAT AKTIVITAS PENGIRIMAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                Text('${listKirim.length} Item', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: listKirim.length,
            itemBuilder: (context, index) {
              final item = listKirim[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                      const SizedBox(height: 4),
                      Text(item.body, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Section Riwayat Manifes Diterima
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.teal),
                    SizedBox(width: 4),
                    Text('RIWAYAT MANIFES DITERIMA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                Text('${listTerima.length} Item', style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: listTerima.length,
            itemBuilder: (context, index) {
              final item = listTerima[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                      const SizedBox(height: 4),
                      Text(item.body, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
          
          // Tombol Keluar Minimalis Sesuai Gambar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: InkWell(
              onTap: _logoutSistem,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Keluar dari Sistem', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}