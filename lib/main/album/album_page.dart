import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gnoo/main/album/albums/album_model.dart';
import 'package:gnoo/auth/login_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'albums/album_detail_subpage.dart';
import '../pages/settings_bottom_sheet.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  String? _currentUserId;
  late AnimationController _refreshAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription? _albumSubscription;

  // Override dari AutomaticKeepAliveClientMixin
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupAnimations();
    _setupAlbumListener();
  }

  void _setupAlbumListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _albumSubscription = FirebaseFirestore.instance
          .collection('koleksi_albums')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _setupAnimations() {
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _albumSubscription?.cancel();
    _refreshAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('uid');

    setState(() {
      _currentUserId = userId;
    });
    _fadeAnimationController.forward();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshAnimationController.forward(from: 0.0);

    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _isRefreshing = false;
    });

    _refreshAnimationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Diperlukan untuk AutomaticKeepAliveClientMixin

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Album',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.sharedAxisVertical,
                child: const SettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _currentUserId != null
              ? _buildAlbumListView()
              : _buildLoginPrompt(),
        ),
      ),
    );
  }

  Widget _buildAlbumListView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildAlbumList(context),
      ],
    );
  }

  Widget _buildAlbumList(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    const assetPath = 'assets/images/create_albums.svg';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('koleksi_albums')
          .where('userId', isEqualTo: currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print("Error di _buildAlbumList: ${snapshot.error}");
          return const SliverFillRemaining(
            child: Center(child: Text('Terjadi kesalahan.')),
          );
        }

        final albums = snapshot.data?.docs
                .map((doc) => Album.fromFirestore(doc))
                .where((album) => album.albumId != null)
                .toList() ??
            [];

        if (albums.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              // Add bottom padding here
              padding: const EdgeInsets.only(bottom: 80),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: FutureBuilder<String>(
                        future: DefaultAssetBundle.of(context)
                            .loadString(assetPath),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (!snapshot.hasData) {
                            return const SizedBox();
                          }

                          String svgContent = snapshot.data!;

                          svgContent = svgContent
                              .replaceAll('#000000',
                                  Theme.of(context).colorScheme.primary.toHex())
                              .replaceAll('#263238', '#263238')
                              .replaceAll('#FFB573', '#FFB573')
                              .replaceAll(
                                  '#FFFFFF',
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer
                                      .toHex());

                          return SvgPicture.string(
                            svgContent,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada album.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buat album baru untuk mulai menambahkan foto.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }

        // For the album grid, we need to add a SliverMainAxisGroup with padding
        return SliverMainAxisGroup(
          slivers: [
            _buildAlbumGrid(context, albums),
            // Add bottom padding sliver
            SliverToBoxAdapter(
              child: SizedBox(height: 80), // Adjust based on your navbar height
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlbumGrid(BuildContext context, List<Album> albums) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverAnimatedGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        initialItemCount: albums.length,
        itemBuilder:
            (BuildContext context, int index, Animation<double> animation) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildAlbumCard(context, albums[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () {
        _showDeleteConfirmationDialog(context, album.albumId!);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('koleksi_albums')
                  .doc(album.albumId)
                  .collection('saved_posts')
                  .orderBy('timestamp', descending: false)
                  .limit(4)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildPlaceholderAlbumCard(colorScheme, album);
                }

                if (snapshot.hasError) {
                  print(
                      "Error di FutureBuilder (saved_posts): ${snapshot.error}");
                  return _buildPlaceholderAlbumCard(colorScheme, album);
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildPlaceholderAlbumCard(colorScheme, album);
                }

                final savedPosts = snapshot.data!.docs;
                final List<Widget> imageWidgets = [];

                for (int i = 0; i < 4; i++) {
                  if (i < savedPosts.length) {
                    final fotoId = savedPosts[i]['fotoId'];
                    imageWidgets.add(_buildAlbumImage(fotoId, colorScheme));
                  } else {
                    imageWidgets.add(_buildPlaceholderImage(colorScheme));
                  }
                }

                return Material(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.sharedAxisVertical,
                          child: AlbumDetailPage(album: album),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GridView.count(
                        crossAxisCount: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: imageWidgets,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              album.judulAlbum,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumImage(String fotoId, ColorScheme colorScheme) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('koleksi_posts')
          .doc(fotoId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholderImage(colorScheme);
        }

        if (snapshot.hasError) {
          print(
              "Error di Inner FutureBuilder (koleksi_posts): ${snapshot.error}");
          return _buildPlaceholderImage(colorScheme);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildPlaceholderImage(colorScheme);
        }

        final post = snapshot.data!;
        final imageUrl = post['lokasiFile'];

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholderImage(colorScheme),
            errorWidget: (context, url, error) {
              print("Error loading image: $error");
              return _buildPlaceholderImage(colorScheme);
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderAlbumCard(ColorScheme colorScheme, Album album) {
    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: List.generate(
                4, (index) => _buildPlaceholderImage(colorScheme)),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    const assetPath = 'assets/images/login.svg';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 350,
            height: 350,
            padding: const EdgeInsets.all(8),
            child: FutureBuilder<String>(
              future: DefaultAssetBundle.of(context).loadString(assetPath),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                String svgContent = snapshot.data!;

                svgContent = svgContent
                    .replaceAll('#000000', theme.colorScheme.primary.toHex())
                    .replaceAll('#263238', '#263238')
                    .replaceAll('#FFB573', '#FFB573')
                    .replaceAll(
                        '#FFFFFF', theme.colorScheme.surfaceContainer.toHex());
                return SvgPicture.string(
                  svgContent,
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Masuk untuk melihat album Anda',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              ).then((_) {
                _checkLoginStatus();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Masuk',
              style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String albumId) {
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
                'Hapus Album',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah Anda yakin ingin menghapus album ini?',
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
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await _deleteAlbum(albumId);
                      if (mounted) Navigator.pop(context);
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

  Future<void> _deleteAlbum(String albumId) async {
    try {
      // Start a batch operation
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Get all saved posts in the album
      final savedPostsSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_albums')
          .doc(albumId)
          .collection('saved_posts')
          .get();

      // Add delete operations for each saved post
      for (final doc in savedPostsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Add delete operation for the album document
      batch.delete(
          FirebaseFirestore.instance.collection('koleksi_albums').doc(albumId));

      // Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Album berhasil dihapus!')),
        );
      }
    } catch (e) {
      print("Error deleting album: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Terjadi kesalahan saat menghapus album.')),
        );
      }
    }
  }
}

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
