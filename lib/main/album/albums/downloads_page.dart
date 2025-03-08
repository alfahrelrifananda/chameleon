import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final Map<String, List<AssetEntity>> _folderAssets = {};
  final Map<String, Directory> _folderDirs = {};
  final List<String> _folderNames = ['Post', 'AI'];
  bool _hasPermission = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePermission();
  }

  Future<void> _initializePermission() async {
    final prefs = await SharedPreferences.getInstance();
    final hasStoredPermission = prefs.getBool('hasPhotoPermission') ?? false;

    if (hasStoredPermission) {
      setState(() => _hasPermission = true);
      _initializeFolders();
    } else {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    final prefs = await SharedPreferences.getInstance();

    setState(() => _hasPermission = permission.isAuth);
    await prefs.setBool('hasPhotoPermission', permission.isAuth);

    if (permission.isAuth) {
      _initializeFolders();
    }
  }

  Future<void> _handlePermission() async {
    await PhotoManager.openSetting();
    await _checkPermission();
  }

  Future<void> _initializeFolders() async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getExternalStorageDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Cannot find downloads directory');
      }

      for (String folderName in _folderNames) {
        String chameleonPath = '${downloadsDir.path}/Chameleon/$folderName';
        Directory folderDir = Directory(chameleonPath);

        if (!await folderDir.exists()) {
          await folderDir.create(recursive: true);
        }

        _folderDirs[folderName] = folderDir;
        _folderAssets[folderName] = [];
      }

      if (mounted) setState(() {});
    } catch (error) {
      _showError('Error initializing folders: $error');
    }
  }

  Future<List<AssetEntity>> _loadFolderAssets(String folderName) async {
    try {
      // Cache key for this folder
      final cacheKey = 'folder_${folderName}_cache';
      final prefs = await SharedPreferences.getInstance();

      // Get folder directory
      final folderDir = _folderDirs[folderName];
      if (folderDir == null) return [];

      // Get last modified time of folder
      final folderStat = await folderDir.stat();
      final lastModified = folderStat.modified.millisecondsSinceEpoch;

      // Check if we have a valid cache
      final lastCheck = prefs.getInt(cacheKey) ?? 0;
      if (lastCheck >= lastModified) {
        // Return cached assets if available
        if (_folderAssets[folderName]?.isNotEmpty == true) {
          return _folderAssets[folderName]!;
        }
      }

      // Get only image files from the folder
      final List<File> folderImages = await folderDir
          .list()
          .where((entity) =>
              entity is File &&
              (entity.path.toLowerCase().endsWith('.jpg') ||
                  entity.path.toLowerCase().endsWith('.jpeg') ||
                  entity.path.toLowerCase().endsWith('.png')))
          .map((entity) => File(entity.path))
          .toList();

      // Optimize photo manager query
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          createTimeCond: DateTimeCond(
            min: DateTime.now().subtract(const Duration(days: 2)),
            max: DateTime.now(),
          ),
        ),
      );

      if (paths.isEmpty) return [];

      // Get recent assets only
      final List<AssetEntity> recentAssets =
          await paths.first.getAssetListRange(
        start: 0,
        end: 100,
      );

      final List<AssetEntity> matchedAssets = [];

      // Match files more efficiently
      for (var image in folderImages) {
        final imagePath = image.path;
        for (var asset in recentAssets) {
          final assetFile = await asset.file;
          if (assetFile?.path == imagePath) {
            matchedAssets.add(asset);
            break;
          }
        }
      }

      // Update cache timestamp
      await prefs.setInt(cacheKey, lastModified);

      // Cache the results in memory
      _folderAssets[folderName] = matchedAssets;

      return matchedAssets;
    } catch (error) {
      _showError('Error loading images: $error');
      return [];
    }
  }

  Future<void> _refreshAllFolders() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      for (String folderName in _folderNames) {
        final assets = await _loadFolderAssets(folderName);
        if (mounted) {
          setState(() {
            _folderAssets[folderName] = assets;
          });
        }
      }
      // Force media scan on Android
      if (Platform.isAndroid) {
        for (var dir in _folderDirs.values) {
          await scanMedia(dir.path);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> scanMedia(String filePath) async {
    try {
      if (Platform.isAndroid) {
        await PhotoManager.clearFileCache();
      }
    } catch (e) {
      debugPrint('Error scanning media: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, AssetEntity asset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImage(asset: asset),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    const assetPath = 'assets/images/search.svg';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Unduhan',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: FutureBuilder<String>(
                future: DefaultAssetBundle.of(context).loadString(assetPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }

                  String svgContent = snapshot.data!;

                  svgContent = svgContent
                      .replaceAll('#000000', colorScheme.primary.toHex())
                      .replaceAll('#263238', colorScheme.onSurface.toHex())
                      .replaceAll('#FFB573', colorScheme.secondary.toHex())
                      .replaceAll(
                          '#FFFFFF', colorScheme.surfaceVariant.toHex());

                  return SvgPicture.string(
                    svgContent,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Izin Galeri Diperlukan',
              style:
                  textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Untuk menampilkan foto, aplikasi memerlukan izin akses ke galeri Anda',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.photo_library_outlined),
              label: Text('Berikan Izin'),
              onPressed: _handlePermission,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return _buildPermissionRequest();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAllFolders,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllFolders,
        child: ListView.builder(
          itemCount: _folderNames.length,
          itemBuilder: (context, index) {
            final folderName = _folderNames[index];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    folderName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FutureBuilder<List<AssetEntity>>(
                  future: _loadFolderAssets(folderName),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final assets = snapshot.data ?? [];

                    if (assets.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('No photos found'),
                      );
                    }

                    return SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: assets.length,
                        itemBuilder: (context, imageIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: AssetThumbnail(
                                asset: assets[imageIndex],
                                size: 200,
                                onTap: () => _openFullScreenImage(
                                  context,
                                  assets[imageIndex],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final double size;
  final VoidCallback? onTap;

  const AssetThumbnail({
    Key? key,
    required this.asset,
    required this.size,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'image-${asset.id}',
        child: FutureBuilder<Uint8List?>(
          future: _loadOptimizedThumbnail(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final bytes = snapshot.data;
            if (bytes != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  cacheWidth: size.toInt(),
                  cacheHeight: size.toInt(),
                  gaplessPlayback: true,
                ),
              );
            }

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline),
            );
          },
        ),
      ),
    );
  }

  Future<Uint8List?> _loadOptimizedThumbnail() async {
    try {
      final thumbSize = (size * 1.5).toInt();
      return await asset.thumbnailDataWithSize(
        ThumbnailSize(thumbSize, thumbSize),
        quality: 85,
      );
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      return null;
    }
  }
}

class FullScreenImage extends StatefulWidget {
  final AssetEntity asset;

  const FullScreenImage({
    Key? key,
    required this.asset,
  }) : super(key: key);

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late Future<File?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = widget.asset.file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<File?>(
        future: _imageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.data == null) {
            return const Center(
              child: Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Hero(
            tag: 'image-${widget.asset.id}',
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
