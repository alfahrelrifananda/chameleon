import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenImageGallery extends StatefulWidget {
  final AssetEntity initialAsset;
  final List<AssetEntity> assets;
  final VoidCallback? onDeleted;

  const FullScreenImageGallery({
    Key? key,
    required this.initialAsset,
    required this.assets,
    this.onDeleted,
  }) : super(key: key);

  @override
  _FullScreenImageGalleryState createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.assets.indexOf(widget.initialAsset);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List?>>(
        future: _fetchImagesBytes(widget.assets),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          final imagesData = snapshot.data!;

          return PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final imageData = imagesData[index];

              if (imageData == null) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                );
              }

              return PhotoViewGalleryPageOptions(
                imageProvider: MemoryImage(imageData),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            itemCount: widget.assets.length,
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          );
        },
      ),
    );
  }

  Future<List<Uint8List?>> _fetchImagesBytes(List<AssetEntity> assets) async {
    return Future.wait(assets.map((asset) => asset.originBytes));
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Gambar'),
          content: const Text('Apakah Anda yakin ingin menghapus gambar ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        final List<String> result = await PhotoManager.editor
            .deleteWithIds([widget.assets[_currentIndex].id]);

        if (result.isNotEmpty) {
          if (context.mounted) {
            widget.onDeleted?.call();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image deleted successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception('Failed to delete image');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete image: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
