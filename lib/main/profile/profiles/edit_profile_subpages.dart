import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _namaLengkapController;
  late TextEditingController _alamatController;
  late TextEditingController _emailController;
  late TextEditingController _createdAtController;
  bool _isLoading = false;
  String? _uid;
  Timestamp? _createdAt;
  dynamic _image;
  String? _profileImageUrl;
  bool _isImageRemoved = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _namaLengkapController = TextEditingController();
    _alamatController = TextEditingController();
    _emailController = TextEditingController();
    _createdAtController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _namaLengkapController.dispose();
    _alamatController.dispose();
    _emailController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _uid = prefs.getString('uid');

      if (_uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('koleksi_users')
            .doc(_uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _usernameController.text = userData['username'] ?? '';
            _namaLengkapController.text = userData['nama_lengkap'] ?? '';
            _alamatController.text = userData['alamat'] ?? '';
            _emailController.text = userData['email'] ?? '';
            _createdAt = userData['created_at'] as Timestamp?;
            _createdAtController.text = _createdAt != null
                ? DateFormat('dd MMMM yyyy, HH:mm:ss')
                    .format(_createdAt!.toDate())
                : '';
            _profileImageUrl = userData['profile_image_url'];
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar("Gagal memuat data pengguna: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _compressImage(dynamic imageFile) async {
    int targetSize = 256;

    late Uint8List imageBytes;
    if (kIsWeb) {
      imageBytes = await imageFile.readAsBytes();
    } else {
      imageBytes = await File(imageFile.path).readAsBytes();
    }

    img.Image? image = img.decodeImage(imageBytes);
    img.Image resizedImage = img.copyResize(
      image!,
      width: targetSize,
      height: targetSize,
    );

    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newUsername = _usernameController.text.trim();
      final isAvailable = await _isUsernameAvailable(newUsername);

      if (!isAvailable) {
        _showErrorSnackBar(
            "Nama pengguna '$newUsername' sudah digunakan. Silakan pilih nama pengguna lain.");
        setState(() => _isLoading = false);
        return;
      }
      String? imageUrl;

      if (_isImageRemoved) {
        imageUrl = null;

        if (_profileImageUrl != null) {
          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('profile_images/$_uid.jpg');
            await storageRef.delete();
          } catch (e) {
            print("Failed to delete old image: $e");
          }
        }
      } else if (_image != null) {
        Uint8List compressedImage = await _compressImage(_image);
        final storageRef =
            FirebaseStorage.instance.ref().child('profile_images/$_uid.jpg');
        await storageRef.putData(compressedImage);
        imageUrl = await storageRef.getDownloadURL();
      } else {
        imageUrl = _profileImageUrl;
      }

      await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(_uid)
          .update({
        'username': newUsername,
        'nama_lengkap': _namaLengkapController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'profile_image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil berhasil diperbarui!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar("Gagal memperbarui profil: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Sesuaikan Gambar',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Sesuaikan Gambar',
            ),
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              minCropBoxHeight: 234,
              cropBoxResizable: true,
              size: CropperSize(width: 300, height: 400),
            )
          ],
        );
        if (croppedFile != null) {
          setState(() {
            _image = croppedFile;
            _isImageRemoved = false;
          });
        }
      }
    } catch (e) {
      print('Error picking or cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Gagal memilih atau memotong gambar. Silakan coba lagi.'),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                _pickAndCropImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil Foto'),
              onTap: () {
                _pickAndCropImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
            if (_image != null || _profileImageUrl != null)
              ListTile(
                leading: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Hapus Foto Profil',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  setState(() {
                    _image = null;
                    _isImageRemoved = true;
                  });
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  void _removeProfilePicture() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hapus Foto Profil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Anda yakin ingin menghapus foto profil?',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _image = null;
                        _isImageRemoved = true;
                      });
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('koleksi_users')
        .where('username', isEqualTo: username)
        .where(FieldPath.documentId, isNotEqualTo: _uid) // Exclude current user
        .limit(1)
        .get();

    return querySnapshot.docs.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 120,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Ubah Profil',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: true,
                    background: Container(
                      color: colorScheme.surface,
                    ),
                  ),
                  elevation: 4,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfilePicture(colorScheme, textTheme),
                          const SizedBox(height: 32),
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Nama Pengguna',
                            icon: Icons.person_outline,
                            maxLength: 25,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama Pengguna tidak boleh kosong';
                              }
                              if (value.length > 25) {
                                return 'Nama Pengguna maksimal 25 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _namaLengkapController,
                            label: 'Nama Lengkap',
                            maxLength: 50,
                            icon: Icons.badge_outlined,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                            validator: (value) {
                              if (value != null && value.length > 50) {
                                return 'Nama Lengkap maksimal 50 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _alamatController,
                            label: 'Alamat',
                            icon: Icons.location_on_outlined,
                            maxLines: 3,
                            maxLength: 100,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                            validator: (value) {
                              if (value != null && value.length > 100) {
                                return 'Alamat maksimal 100 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildReadOnlyInfo('Email', _emailController.text,
                              Icons.email_outlined, colorScheme, textTheme),
                          const SizedBox(height: 16),
                          _buildReadOnlyInfo(
                              'Tanggal Akun Dibuat',
                              _createdAtController.text,
                              Icons.date_range_outlined,
                              colorScheme,
                              textTheme),
                          const SizedBox(height: 32),
                          _buildSaveButton(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfilePicture(ColorScheme colorScheme, TextTheme textTheme) {
    // Determine which image source to use for display
    ImageProvider? imageProvider;
    bool hasImage = false;

    if (!_isImageRemoved) {
      if (_image != null) {
        if (kIsWeb) {
          imageProvider = NetworkImage(_image!.path);
          hasImage = true;
        } else {
          imageProvider = FileImage(File(_image!.path));
          hasImage = true;
        }
      } else if (_profileImageUrl != null) {
        imageProvider = NetworkImage(_profileImageUrl!);
        hasImage = true;
      }
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () {
              // Open full-screen photo view if there's an image
              if (hasImage && imageProvider != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        iconTheme: const IconThemeData(color: Colors.white),
                      ),
                      body: Container(
                        color: Colors.black,
                        child: PhotoView(
                          imageProvider: imageProvider,
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2,
                          backgroundDecoration: const BoxDecoration(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // If no image, show image picker options
                kIsWeb
                    ? _pickAndCropImage(ImageSource.gallery)
                    : _showImagePickerOptions();
              }
            },
            child: CircleAvatar(
              radius: 64,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: imageProvider,
              child: (_isImageRemoved ||
                      (_image == null && _profileImageUrl == null))
                  ? Icon(
                      Icons.person,
                      size: 64,
                      color: colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: kIsWeb
                  ? () => _pickAndCropImage(ImageSource.gallery)
                  : _showImagePickerOptions,
              child: CircleAvatar(
                backgroundColor: colorScheme.secondary,
                child: Icon(
                  Icons.edit,
                  color: colorScheme.onSecondary,
                ),
              ),
            ),
          ),
          if (!_isImageRemoved && (_image != null || _profileImageUrl != null))
            Positioned(
              bottom: 0,
              left: 0,
              child: CircleAvatar(
                backgroundColor: colorScheme.error,
                child: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: colorScheme.onError,
                    size: 20,
                  ),
                  onPressed: _removeProfilePicture,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfo(String label, String value, IconData icon,
      ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _isLoading ? null : _saveProfile,
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
          : const Text('Simpan Perubahan'),
    );
  }
}
