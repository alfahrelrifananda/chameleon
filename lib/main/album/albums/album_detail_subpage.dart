import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gnoo/main/album/albums/album_model.dart';
import 'package:gnoo/main/pages/post_model.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../views/grid/post_info.dart';
import '../../views/grid/reels_view_page.dart';

// ignore: must_be_immutable
class AlbumDetailPage extends StatefulWidget {
  Album album; // Hapus final

  AlbumDetailPage({Key? key, required this.album}) : super(key: key);

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _albumTitleController = TextEditingController();
  final TextEditingController _albumDescController = TextEditingController();

  String? _initialAlbumTitle;
  String? _initialAlbumDesc;

  List<Post> _posts = [];
  bool _isEditing = false;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _albumTitleController.text = widget.album.judulAlbum;
    _albumDescController.text = widget.album.deskripsiAlbum;
    _initialAlbumTitle = widget.album.judulAlbum; // Simpan nilai awal
    _initialAlbumDesc = widget.album.deskripsiAlbum; // Simpan nilai awal
    _loadPosts();
  }

  @override
  void dispose() {
    _albumTitleController.dispose();
    _albumDescController.dispose();
    super.dispose();
  }

  // Check if user has permission to edit/delete
  Future<bool> _checkUserPermission() async {
    try {
      final albumDoc = await _firestore
          .collection('koleksi_albums')
          .doc(widget.album.albumId)
          .get();

      return albumDoc.data()?['userId'] == currentUser?.uid;
    } catch (e) {
      print("Error checking user permission: $e");
      return false;
    }
  }

  Future<void> _loadPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _firestore
          .collection('koleksi_albums')
          .doc(widget.album.albumId)
          .collection('saved_posts')
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoading = false;
          });
        }
        return;
      }

      final postIds =
          snapshot.docs.map((doc) => doc['fotoId'] as String).toList();

      // Gunakan whereIn dengan hati-hati, ada limit 30 item.
      // Jika postIds > 30, bagi menjadi beberapa request.
      if (postIds.length > 30) {
        if (mounted) {
          setState(() {
            _error =
                "Terlalu banyak postingan dalam album ini (lebih dari 30).";
            _isLoading = false;
          });
        }
        return;
      }

      final postsSnapshot = await _firestore
          .collection('koleksi_posts')
          .where(FieldPath.documentId, whereIn: postIds)
          .get();

      final loadedPosts =
          postsSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      if (mounted) {
        setState(() {
          _posts = loadedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Terjadi kesalahan saat memuat data.';
        });
      }
    }
  }

  Future<void> _deletePostFromAlbum(Post post) async {
    final hasPermission = await _checkUserPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Anda tidak memiliki izin untuk menghapus postingan dari album ini'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await _firestore
          .collection('koleksi_albums')
          .doc(widget.album.albumId)
          .collection('saved_posts')
          .doc(post.fotoId)
          .delete();

      setState(() {
        _posts.removeWhere((p) => p.fotoId == post.fotoId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Postingan berhasil dihapus dari album')),
        );
      }
    } catch (e) {
      print("Error deleting post from album: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus postingan dari album')),
        );
      }
    }
  }

  Future<void> _updateAlbumDetails() async {
    final hasPermission = await _checkUserPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Anda tidak memiliki izin untuk mengubah detail album ini'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isEditing = false;
          // Kembalikan ke nilai awal jika tidak punya izin
          _albumTitleController.text = _initialAlbumTitle ?? '';
          _albumDescController.text = _initialAlbumDesc ?? '';
        });
      }
      return;
    }

    // Cek apakah ada perubahan. Gunakan ?? '' untuk handle null.
    if (_albumTitleController.text == (_initialAlbumTitle ?? '') &&
        _albumDescController.text == (_initialAlbumDesc ?? '')) {
      if (mounted) {
        //Tambahkan ini
        setState(() {
          _isEditing = false; // Tidak ada perubahan
        });
      }
      return;
    }

    try {
      await _firestore
          .collection('koleksi_albums')
          .doc(widget.album.albumId)
          .update({
        'judulAlbum': _albumTitleController.text,
        'deskripsiAlbum': _albumDescController.text,
      });

      // Update nilai awal *dan* buat instance Album BARU
      _initialAlbumTitle = _albumTitleController.text;
      _initialAlbumDesc = _albumDescController.text;

      if (mounted) {
        //Tambahkan ini.
        // *Gunakan copyWith untuk membuat objek Album baru*
        setState(() {
          widget.album = widget.album.copyWith(
            judulAlbum: _albumTitleController.text,
            deskripsiAlbum: _albumDescController.text,
          );
          _isEditing = false; //Pindahkan ini ke sini
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detail album berhasil diperbarui')),
        );
      }
    } catch (e) {
      print("Error updating album details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui detail album')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Album' : widget.album.judulAlbum,
            style: TextStyle(color: colorScheme.onSurface)),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.done : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateAlbumDetails();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAlbumHeader(context),
            ),
            _buildPhotoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album thumbnail
            _buildAlbumThumbnail(colorScheme),
            const SizedBox(width: 16),
            // Album details
            Expanded(
              child: _isEditing
                  ? _buildEditableAlbumDetails(colorScheme)
                  : _buildAlbumDetails(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumThumbnail(ColorScheme colorScheme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('koleksi_albums')
            .doc(widget.album.albumId)
            .collection('saved_posts')
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Shimmer.fromColors(
              baseColor: colorScheme.surfaceVariant,
              highlightColor: colorScheme.surface,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.photo_album,
                  size: 40, color: colorScheme.onSurfaceVariant),
            );
          }

          final savedPost = snapshot.data!.docs.first;
          final fotoId = savedPost['fotoId'];

          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('koleksi_posts').doc(fotoId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Shimmer.fromColors(
                  baseColor: colorScheme.surfaceVariant,
                  highlightColor: colorScheme.surface,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.error, size: 40, color: colorScheme.error),
                );
              }

              final post = snapshot.data!;
              final imageUrl = post['lokasiFile'];

              return Hero(
                tag: 'album_thumb_${widget.album.albumId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: colorScheme.surfaceVariant,
                      highlightColor: colorScheme.surface,
                      child: Container(color: colorScheme.surfaceVariant),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.errorContainer,
                      child:
                          Icon(Icons.error, size: 40, color: colorScheme.error),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAlbumDetails(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.album.judulAlbum,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.album.deskripsiAlbum,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        // Post count
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('koleksi_albums')
              .doc(widget.album.albumId)
              .collection('saved_posts')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (snapshot.hasError) {
              return Text(
                "0 Postingan",
                style: TextStyle(color: colorScheme.error),
              );
            }

            final postCount = snapshot.data?.docs.length ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$postCount Postingan",
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditableAlbumDetails(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _albumTitleController,
          decoration: InputDecoration(
            labelText: 'Judul Album',
            labelStyle: TextStyle(color: colorScheme.primary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          style: Theme.of(context).textTheme.titleMedium,
          maxLength: 50,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return Text(
              '$currentLength/$maxLength',
              style: TextStyle(
                color: currentLength >= maxLength!
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _albumDescController,
          decoration: InputDecoration(
            labelText: 'Deskripsi Album',
            labelStyle: TextStyle(color: colorScheme.primary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          maxLength: 100,
          maxLines: 3,
          buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) {
            return Text(
              '$currentLength/$maxLength',
              style: TextStyle(
                color: currentLength >= maxLength!
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadPosts,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Belum ada postingan di album ini",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemBuilder: (context, index) {
          return KeepAliveBuilder(
            child: AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 375),
              columnCount: 2,
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: _buildPostTile(_posts[index]),
                ),
              ),
            ),
          );
        },
        childCount: _posts.length,
      ),
    );
  }

  Widget _buildPostTile(Post post) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.sharedAxisScale,
            child: ReelsViewPage(
              posts: _posts,
              imageUrl: post.lokasiFile,
              initialIndex: _posts.indexOf(post),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatioImage(
                imageUrl: post.lokasiFile,
                builder: (context, child, aspectRatio) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    shadowColor: colorScheme.shadow.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: child,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.judulFoto,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    PostInfo(userId: post.userId, post: post),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              elevation: 4.0,
              shadowColor: colorScheme.shadow.withOpacity(0.3),
              shape: const CircleBorder(),
              color: colorScheme.surface,
              child: InkWell(
                onTap: () => _showDeleteConfirmation(post),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Post post) {
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
                'Hapus dari Album',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah Anda yakin ingin menghapus postingan ini dari album?\n\nPostingan tidak akan dihapus dari galeri utama.',
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
                    onPressed: () {
                      Navigator.pop(context);
                      _deletePostFromAlbum(post);
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
}

// AspectRatioImage widget from ProfilePage
class AspectRatioImage extends StatelessWidget {
  const AspectRatioImage({
    Key? key,
    required this.imageUrl,
    required this.builder,
  }) : super(key: key);

  final String imageUrl;
  final Widget Function(BuildContext context, Widget child, double aspectRatio)
      builder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatioLayoutBuilder(
      imageUrl: imageUrl,
      builder: (context, aspectRatio) {
        return builder(
          context,
          AspectRatio(
            aspectRatio: aspectRatio,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: colorScheme.surfaceVariant,
                highlightColor: colorScheme.surface,
                child: Container(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Container(
                color: colorScheme.errorContainer,
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
          aspectRatio,
        );
      },
      placeholder: builder(
        context,
        AspectRatio(
          aspectRatio: 1.0,
          child: Shimmer.fromColors(
            baseColor: colorScheme.surfaceVariant,
            highlightColor: colorScheme.surface,
            child: Container(color: Colors.white),
          ),
        ),
        1.0,
      ),
    );
  }
}

class AspectRatioLayoutBuilder extends StatefulWidget {
  const AspectRatioLayoutBuilder({
    Key? key,
    required this.imageUrl,
    required this.builder,
    required this.placeholder,
  }) : super(key: key);

  final String imageUrl;
  final Widget Function(BuildContext context, double aspectRatio) builder;
  final Widget placeholder;

  @override
  State<AspectRatioLayoutBuilder> createState() =>
      _AspectRatioLayoutBuilderState();
}

class _AspectRatioLayoutBuilderState extends State<AspectRatioLayoutBuilder> {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getImage();
  }

  @override
  void didUpdateWidget(AspectRatioLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _getImage();
    }
  }

  void _getImage() {
    final NetworkImage image = NetworkImage(widget.imageUrl);
    final ImageStream newStream =
        image.resolve(createLocalImageConfiguration(context));
    _updateSourceStream(newStream);
  }

  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key != newStream.key) {
      _imageStream?.removeListener(ImageStreamListener(_handleImageLoaded));
      _imageStream = newStream;
      _imageStream!.addListener(ImageStreamListener(_handleImageLoaded));
    }
  }

  void _handleImageLoaded(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _imageInfo = imageInfo;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _imageStream?.removeListener(ImageStreamListener(_handleImageLoaded));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageInfo == null) {
      return widget.placeholder;
    }

    final double aspectRatio =
        _imageInfo!.image.width / _imageInfo!.image.height;

    return widget.builder(context, aspectRatio);
  }
}

class KeepAliveBuilder extends StatefulWidget {
  final Widget child;
  final bool keepAlive; // Add the required parameter

  const KeepAliveBuilder({
    Key? key,
    required this.child,
    this.keepAlive = true, // Provide a default value
  }) : super(key: key);

  @override
  State<KeepAliveBuilder> createState() => _KeepAliveBuilderState();
}

class _KeepAliveBuilderState extends State<KeepAliveBuilder>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
