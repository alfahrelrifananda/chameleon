import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateAlbumPage extends StatefulWidget {
  const CreateAlbumPage({Key? key}) : super(key: key);

  @override
  State<CreateAlbumPage> createState() => _CreateAlbumPageState();
}

class _CreateAlbumPageState extends State<CreateAlbumPage> {
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buat Album Baru',
                  style: textTheme.displaySmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _judulController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    labelText: 'Judul Album',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  maxLength: 50, // Limit title to 50 characters
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul album tidak boleh kosong!';
                    }
                    if (value.trim().isEmpty) {
                      return 'Judul Album tidak boleh hanya berisi spasi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deskripsiController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    labelText: 'Deskripsi Album',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  maxLength: 100, // Limit description to 100 characters
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Deskripsi album tidak boleh kosong!';
                    }
                    if (value.trim().isEmpty) {
                      return 'Deskripsi Album tidak boleh hanya berisi spasi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isLoading = true);
                            final String judul = _judulController.text.trim();
                            final String deskripsi =
                                _deskripsiController.text.trim();

                            await _createAlbum(judul, deskripsi);
                            setState(() => _isLoading = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Buat Album'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createAlbum(String judul, String deskripsi) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in.')),
          );
        }
        return;
      }

      final newAlbumDoc =
          await FirebaseFirestore.instance.collection('koleksi_albums').add({
        'judulAlbum': judul,
        'deskripsiAlbum': deskripsi,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final String albumId = newAlbumDoc.id;

      await newAlbumDoc.update({
        'albumId': albumId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Album berhasil dibuat!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error creating album: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Terjadi kesalahan saat membuat album.')),
        );
      }
    }
  }
}
