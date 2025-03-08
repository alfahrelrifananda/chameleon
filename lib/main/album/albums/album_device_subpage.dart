import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'album_device_detail.dart';

class DeviceAlbumPage extends StatefulWidget {
  const DeviceAlbumPage({Key? key}) : super(key: key);

  @override
  _DeviceAlbumPageState createState() => _DeviceAlbumPageState();
}

class _DeviceAlbumPageState extends State<DeviceAlbumPage> {
  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  final double _thumbnailSize = 56.0;

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
      await _loadAlbums();
    } else {
      await _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _hasPermission = permission.isAuth;
        _isLoading = false;
      });
    }

    await prefs.setBool('hasPhotoPermission', permission.isAuth);

    if (permission.isAuth) {
      await _loadAlbums();
    }
  }

  Future<void> _handlePermission() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await PhotoManager.openSetting();
    await _checkPermission();
  }

  Future<void> _loadAlbums() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _fetchAlbums();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading albums: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAlbums() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        onlyAll: false,
      );

      if (mounted) {
        setState(() {
          _albums = albums;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching albums: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPermissionRequest() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    const assetPath = 'assets/images/search.svg';

    return Center(
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
                  return const Icon(Icons.photo_library_outlined, size: 64);
                }

                String svgContent = snapshot.data!;

                // Replace SVG colors to match app theme
                svgContent = svgContent
                    .replaceAll('#000000', colorScheme.primary.toHex())
                    .replaceAll('#263238', colorScheme.onSurface.toHex())
                    .replaceAll('#FFB573', colorScheme.secondary.toHex())
                    .replaceAll('#FFFFFF', colorScheme.surfaceVariant.toHex());

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
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Untuk menampilkan album foto, aplikasi memerlukan izin akses ke galeri Anda',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Berikan Izin'),
            onPressed: _handlePermission,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Album Perangkat'),
        actions: [
          if (_hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadAlbums,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _buildPermissionRequest()
              : _albums.isEmpty
                  ? const Center(child: Text('Tidak ada album yang ditemukan'))
                  : ListView.builder(
                      itemCount: _albums.length,
                      itemBuilder: (context, index) {
                        final album = _albums[index];
                        return FutureBuilder<AssetEntity?>(
                          future: album
                              .getAssetListRange(start: 0, end: 1)
                              .then((value) =>
                                  value.isNotEmpty ? value.first : null),
                          builder: (context, snapshot) {
                            return ListTile(
                              leading: SizedBox(
                                width: _thumbnailSize,
                                height: _thumbnailSize,
                                child: snapshot.data != null
                                    ? AssetThumbnail(
                                        asset: snapshot.data!,
                                        size: _thumbnailSize,
                                      )
                                    : const Icon(Icons.photo_album),
                              ),
                              title: Text(album.name),
                              subtitle: FutureBuilder<int>(
                                future: album.assetCountAsync,
                                builder: (context, snapshot) {
                                  return Text(snapshot.data != null
                                      ? '${snapshot.data} item'
                                      : 'Memuat...');
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AlbumDetailsPage(album: album),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
    );
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final double size;

  const AssetThumbnail({
    Key? key,
    required this.asset,
    required this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        ThumbnailSize(size.toInt(), size.toInt()),
      ),
      builder: (_, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
          );
        }
        return SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.photo),
        );
      },
    );
  }
}

class AlbumDetailsPage extends StatefulWidget {
  final AssetPathEntity album;

  const AlbumDetailsPage({Key? key, required this.album}) : super(key: key);

  @override
  _AlbumDetailsPageState createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    final assets = await widget.album.getAssetListRange(
      start: 0,
      end: await widget.album.assetCountAsync,
    );
    if (mounted) {
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    }
  }

  void _refreshAssets() {
    setState(() {
      _isLoading = true;
    });
    _fetchAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageGallery(
                          initialAsset: asset,
                          assets: _assets,
                          onDeleted: _refreshAssets,
                        ),
                      ),
                    );
                  },
                  child: AssetThumbnail(
                    asset: asset,
                    size: MediaQuery.of(context).size.width / 3,
                  ),
                );
              },
            ),
    );
  }
}

// Extension to convert Color to Hex string
extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
