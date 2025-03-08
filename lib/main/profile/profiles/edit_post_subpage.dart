import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_view/photo_view.dart';
import '../../pages/post_model.dart';

class EditPostPage extends StatefulWidget {
  final Post post;

  const EditPostPage({Key? key, required this.post}) : super(key: key);

  @override
  _EditPostPageState createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  bool _isLoading = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.judulFoto);
    _descriptionController =
        TextEditingController(text: widget.post.deskripsiFoto);
    _tagsController = TextEditingController();
    _tags = List.from(widget.post.tags);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance
            .collection('koleksi_posts')
            .doc(widget.post.fotoId)
            .update({
          'judulFoto': _titleController.text,
          'deskripsiFoto': _descriptionController.text,
          'tags': _tags,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post berhasil diperbarui!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print("Error updating post: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Terjadi kesalahan saat memperbarui post.')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePost() async {
    setState(() => _isLoading = true);

    try {
      // Delete the image from Firebase Storage
      await FirebaseStorage.instance
          .refFromURL(widget.post.lokasiFile)
          .delete();

      // Delete all instances of this post from all albums
      final QuerySnapshot albumsWithPost =
          await FirebaseFirestore.instance.collection('koleksi_albums').get();

      // For each album, check and delete the post if it exists
      for (var album in albumsWithPost.docs) {
        final savedPostRef =
            album.reference.collection('saved_posts').doc(widget.post.fotoId);

        final savedPostDoc = await savedPostRef.get();
        if (savedPostDoc.exists) {
          await savedPostRef.delete();
        }
      }

      // Delete the post document from Firestore
      await FirebaseFirestore.instance
          .collection('koleksi_posts')
          .doc(widget.post.fotoId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post berhasil dihapus!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error deleting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Terjadi kesalahan saat menghapus post.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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

  void _showDeleteConfirmation() {
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
                'Hapus Post',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah Anda yakin ingin menghapus post ini? Tindakan ini tidak dapat dibatalkan.',
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
                    onPressed: () => Navigator.of(context).pop(),
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
                      Navigator.of(context).pop();
                      _deletePost();
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

  void _showFullScreenImage() {
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
            imageProvider: NetworkImage(widget.post.lokasiFile),
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
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _showDeleteConfirmation,
          ),
        ],
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
                  'Edit Post',
                  style: textTheme.displaySmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 32),
                // Image Preview (non-editable)
                GestureDetector(
                  onTap: () => _showFullScreenImage(),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(widget.post.lokasiFile),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Judul Foto
                TextFormField(
                  controller: _titleController,
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
                  controller: _descriptionController,
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

                // Update Button
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: colorScheme.primary,
                        ),
                      )
                    : FilledButton(
                        onPressed: _updatePost,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text('Perbarui Post'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
