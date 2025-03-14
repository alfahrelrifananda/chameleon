import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:photo_view/photo_view.dart';

import '../board/boards/notification_subpage.dart';

class UploadPosts extends StatefulWidget {
  final Uint8List? initialImage;

  const UploadPosts({
    Key? key,
    this.initialImage,
  }) : super(key: key);

  @override
  State<UploadPosts> createState() => _UploadPostsState();
}

class _UploadPostsState extends State<UploadPosts> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _tagsController = TextEditingController();
  XFile? _image;
  bool _isLoading = false;
  List<String> _tags = [];
  Uint8List? _imageBytes;

  final ImagePicker _picker = ImagePicker();

  // Add NotificationHandler instance
  final NotificationHandler _notificationHandler = NotificationHandler();

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _imageBytes = widget.initialImage;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (kIsWeb) {
        // Web: Use pickMedia to allow GIFs
        final XFile? imageFile = await _picker.pickMedia();
        if (imageFile != null) {
          final Uint8List imageBytes = await imageFile.readAsBytes();

          setState(() {
            _image = imageFile;
            _imageBytes = imageBytes; // Store bytes for correct upload handling
          });
        }
      } else {
        // Mobile: Use pickMedia to prevent GIF conversion
        final XFile? pickedFile = await _picker.pickMedia();
        if (pickedFile != null) {
          final Uint8List imageBytes = await pickedFile.readAsBytes();

          setState(() {
            _image = pickedFile;
            _imageBytes = imageBytes; // Store bytes for correct upload handling
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal memilih gambar. Silakan coba lagi.')),
        );
      }
    }
  }

  Future<void> _uploadPost() async {
    if (_formKey.currentState!.validate() &&
        (_image != null || _imageBytes != null)) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final postRef =
            FirebaseFirestore.instance.collection('koleksi_posts').doc();
        final String fotoId = postRef.id;

        final storageRef = FirebaseStorage.instance.ref();
        String contentType;
        Uint8List uploadData;
        String extension;

        // Function to check if data is GIF
        bool isGif(List<int> bytes) {
          if (bytes.length < 4) return false;
          return (bytes[0] == 0x47 && // G
              bytes[1] == 0x49 && // I
              bytes[2] == 0x46 && // F
              bytes[3] == 0x38); // 8
        }

        // Determine image source and process it
        if (_imageBytes != null) {
          // Handle AI-generated image
          uploadData = _imageBytes!;
        } else if (kIsWeb) {
          // Handle Web Upload
          uploadData = await _image!.readAsBytes();
        } else {
          // Handle Mobile Upload
          uploadData = await File(_image!.path).readAsBytes();
        }

        // Check if image is a GIF or not
        if (isGif(uploadData)) {
          contentType = 'image/gif';
          extension = 'gif';
        } else {
          contentType = 'image/jpeg';
          final image = img.decodeImage(uploadData);
          if (image == null) throw Exception('Gagal mengkonversi gambar');
          uploadData = Uint8List.fromList(img.encodeJpg(image, quality: 90));
          extension = 'jpg';
        }

        // Create the storage reference
        final imageRef = storageRef.child('koleksi_posts/$fotoId.$extension');

        // Upload the file
        await imageRef.putData(
            uploadData, SettableMetadata(contentType: contentType));

        // Get the URL
        final imageUrl = await imageRef.getDownloadURL();

        // Save post details to Firestore
        await postRef.set({
          'fotoId': fotoId,
          'judulFoto': _judulController.text,
          'deskripsiFoto': _deskripsiController.text,
          'tanggalUnggah': Timestamp.now(),
          'lokasiFile': imageUrl,
          'albumId': null,
          'userId': user.uid,
          'tags': _tags,
          'likes': 0,
          'fileType': contentType, // Store file type for reference
        });

        // Fetch user's username
        final userDoc = await FirebaseFirestore.instance
            .collection('koleksi_users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        final currentUsername = userData['username'] ?? 'Unknown User';

        // Get all followers
        final followersSnapshot = await FirebaseFirestore.instance
            .collection('koleksi_follows')
            .doc(user.uid)
            .collection('userFollowers')
            .get();

        // Send notification to each follower
        for (var followerDoc in followersSnapshot.docs) {
          final followerId = followerDoc.id;

          await _notificationHandler.createCommentNotification(
            recipientUserId: followerId,
            senderUserId: user.uid,
            senderUsername: currentUsername,
            postId: fotoId,
            commentId: '',
            content: 'Mengunggah postingan baru: ${_judulController.text}',
            type: NotificationType.newPost,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post berhasil diunggah!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("Error uploading post: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Terjadi kesalahan saat mengunggah.')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addTag() {
    if (_tagsController.text.isNotEmpty) {
      setState(() {
        _tags.add(_tagsController.text.trim());
        _tagsController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _showFullScreenImage(ImageProvider imageProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: imageProvider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Unggah Post Baru',
                  style: textTheme.displaySmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 32),
                // Image Preview
                InkWell(
                  onTap: () {
                    if (_imageBytes != null) {
                      _showFullScreenImage(MemoryImage(_imageBytes!));
                    } else if (_image != null) {
                      if (kIsWeb) {
                        _showFullScreenImage(NetworkImage(_image!.path));
                      } else {
                        _showFullScreenImage(FileImage(File(_image!.path)));
                      }
                    } else {
                      // If no image, show image picker
                      kIsWeb
                          ? _pickImage(ImageSource.gallery)
                          : _showImageSourceOptions();
                    }
                  },
                  child: Stack(
                    children: [
                      // Image Container - Make it full width
                      Container(
                        width: double.infinity, // This ensures full width
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceVariant.withOpacity(0.5),
                          image: (_imageBytes != null)
                              ? DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : (_image != null)
                                  ? DecorationImage(
                                      image: kIsWeb
                                          ? NetworkImage(_image!.path)
                                          : FileImage(File(_image!.path))
                                              as ImageProvider<Object>,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (_imageBytes == null && _image == null)
                            ? Center(
                                child: Icon(
                                  Icons.add_a_photo,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                      ),

                      // Pencil icon that appears only when an image is selected
                      if (_imageBytes != null || _image != null)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                kIsWeb
                                    ? _pickImage(ImageSource.gallery)
                                    : _showImageSourceOptions();
                              },
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Judul Foto
                TextFormField(
                  controller: _judulController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurface),
                  maxLength: 50, // Limit description to 100 characters
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    labelText: 'Judul Foto',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul foto tidak boleh kosong';
                    }
                    if (value.trim().isEmpty) {
                      return 'Judul foto tidak boleh hanya berisi spasi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Deskripsi Foto
                TextFormField(
                  controller: _deskripsiController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurface),
                  maxLength: 100, // Limit description to 100 characters
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    labelText: 'Deskripsi Foto',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Deskripsi foto tidak boleh kosong';
                    }
                    if (value.trim().isEmpty) {
                      return 'Deskripsi foto tidak boleh hanya berisi spasi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tags
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag,
                          style:
                              TextStyle(color: colorScheme.onSurfaceVariant)),
                      onDeleted: () => _removeTag(tag),
                      deleteIconColor: colorScheme.error,
                      backgroundColor:
                          colorScheme.surfaceVariant.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Add Tag
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagsController,
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor:
                              colorScheme.surfaceVariant.withOpacity(0.5),
                          labelText: 'Tambahkan Tag',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add, color: colorScheme.primary),
                            onPressed: _addTag,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Upload Button
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: colorScheme.primary,
                        ),
                      )
                    : FilledButton(
                        onPressed: _uploadPost,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text('Unggah'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceOptions() {
    if (kIsWeb) {
      _pickImage(ImageSource.gallery);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: colorScheme.primary),
                title: Text('Galeri',
                    style: TextStyle(color: colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              // ListTile(
              //   leading: Icon(Icons.photo_camera, color: colorScheme.primary),
              //   title: Text('Kamera',
              //       style: TextStyle(color: colorScheme.onSurface)),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _pickImage(ImageSource.camera);
              //   },
              // ),
            ],
          );
        },
      );
    }
  }
}
