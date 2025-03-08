import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:share_plus/share_plus.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PhotoViewController _controller;
  bool _isZoomed = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
    _controller.outputStateStream.listen((PhotoViewControllerValue state) {
      setState(() {
        _isZoomed = state.scale! > 1.0;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.status;
        if (status.isDenied) {
          final result = await Permission.manageExternalStorage.request();
          return result.isGranted;
        }
        return status.isGranted;
      } else {
        final status = await Permission.storage.status;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<void> _downloadImage() async {
    if (kIsWeb) {
      _showWebDownloadInfo();
      return;
    }

    final bool hasPermission = await _requestStoragePermission();

    if (hasPermission) {
      final imageSize = await _getImageSize();
      if (imageSize != null) {
        _showDownloadConfirmation(imageSize);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan ukuran gambar')),
        );
      }
    } else {
      if (await Permission.storage.isPermanentlyDenied ||
          await Permission.manageExternalStorage.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin penyimpanan diperlukan untuk mengunduh'),
          ),
        );
      }
    }
  }

  Future<int?> _getImageSize() async {
    try {
      final response = await http.head(Uri.parse(widget.imageUrl));
      return int.tryParse(response.headers['content-length'] ?? '');
    } catch (e) {
      print('Error getting image size: $e');
      return null;
    }
  }

  void _showDownloadConfirmation(int imageSize) {
    final sizeInMB = (imageSize / (1024 * 1024)).toStringAsFixed(2);
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Konfirmasi Unduhan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Ukuran gambar: $sizeInMB MB',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    child: Text('Batal'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  FilledButton(
                    child: Text('Unduh'),
                    onPressed: () {
                      Navigator.pop(context);
                      _startDownload();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Izin Diperlukan'),
          content: Text(
              'Aplikasi memerlukan izin penyimpanan untuk mengunduh gambar. Silakan buka pengaturan aplikasi untuk memberikan izin.'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: Text('Buka Pengaturan'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDownload() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mengunduh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 16),
              Text('${(_downloadProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        );
      },
    );

    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Untuk Android, gunakan folder Download publik
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getExternalStorageDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Tidak dapat menemukan direktori unduhan');
      }

      String chameleonPath = '${downloadsDir.path}/Chameleon/Post';
      Directory chameleonDir = Directory(chameleonPath);
      if (!await chameleonDir.exists()) {
        await chameleonDir.create(recursive: true);
      }

      final fileName = 'chameleon_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('$chameleonPath/$fileName');

      final request = http.Request('GET', Uri.parse(widget.imageUrl));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      List<int> bytes = [];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        final downloadedLength = bytes.length;
        setState(() {
          _downloadProgress = downloadedLength / contentLength;
        });
      }

      await file.writeAsBytes(bytes);

      Navigator.of(context).pop(); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gambar berhasil diunduh ke Download/Chameleon')),
      );
    } catch (error) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh gambar: $error')),
      );
    }
  }

  void _showWebDownloadInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Unduh Gambar di Web'),
          content: Text(
              'Untuk mengunduh gambar di web, klik kanan pada gambar dan pilih "Simpan gambar sebagai..."'),
          actions: <Widget>[
            TextButton(
              child: Text('Mengerti'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            color: colorScheme.onSurface,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: "Tutup",
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.download),
              color: colorScheme.onSurface,
              onPressed: _downloadImage,
              tooltip: "Unduh gambar",
            ),
          ),
          if (!kIsWeb)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              
            ),
        ],
      ),
      body: Container(
        constraints: BoxConstraints.expand(
          height: MediaQuery.of(context).size.height,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PhotoView(
              imageProvider: NetworkImage(widget.imageUrl),
              controller: _controller,
              heroAttributes: PhotoViewHeroAttributes(tag: widget.heroTag),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration:
                  BoxDecoration(color: colorScheme.background),
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event?.expectedTotalBytes != null
                      ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                      : null,
                  color: colorScheme.primary,
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Gagal memuat gambar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onError,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _isZoomed ? 0.0 : 0.7,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_out_map,
                      color: colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cubit untuk memperbesar',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
