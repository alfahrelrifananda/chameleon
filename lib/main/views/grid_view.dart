import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:gnoo/main/pages/post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main_page.dart';
import '../board/boards/search_subpage.dart';
import 'grid/post_info.dart';
import 'grid/reels_view_page.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class GridBoardView extends StatefulWidget {
  const GridBoardView({
    Key? key,
    required this.posts,
    required this.onRefresh,
    required this.scrollController,
    this.isProfileView = false,
    this.onDeletePost,
    this.albumId,
    this.onDeleteFromAlbum,
  }) : super(key: key);

  final List<Post> posts;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final bool isProfileView;
  final Future<void> Function(Post post)? onDeletePost;
  final String? albumId;
  final Future<void> Function(Post post)? onDeleteFromAlbum;

  @override
  State<GridBoardView> createState() => GridBoardViewState();
}

class GridBoardViewState extends State<GridBoardView>
    with SingleTickerProviderStateMixin {
  List<Post> _posts = [];
  bool _isAppBarVisible = true;
  double _lastScrollPosition = 0;
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _slideAnimation;
  // Add a map to track post IDs to prevent duplicates
  final Map<String, Post> _postsMap = {};

  @override
  void initState() {
    super.initState();
    _updatePostsList(widget.posts);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Create slide animation
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: -12.0, // Negative padding value
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    widget.scrollController.addListener(_scrollListener);
  }

  // Helper method to update posts list and map
  void _updatePostsList(List<Post> newPosts) {
    _postsMap.clear();
    for (final post in newPosts) {
      _postsMap[post.fotoId] = post;
    }
    _posts = _postsMap.values.toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    final currentScroll = widget.scrollController.position.pixels;
    final mainPage = MainPage.of(context);

    if (currentScroll > _lastScrollPosition && currentScroll > 0) {
      // Scrolling down
      if (_isAppBarVisible) {
        setState(() => _isAppBarVisible = false);
        mainPage?.setNavBarVisible(false);
        _animationController.forward(); // Animate slide up
      }
    } else {
      // Scrolling up
      if (!_isAppBarVisible) {
        setState(() => _isAppBarVisible = true);
        mainPage?.setNavBarVisible(true);
        _animationController.reverse(); // Animate slide down
      }
    }

    _lastScrollPosition = currentScroll;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AnimatedAppBar(
        isVisible: _isAppBarVisible,
        colorScheme: colorScheme,
        onMenuPressed: () {
          MainPage.of(context)?.openDrawer();
        },
        onSearchPressed: () {
          Navigator.push(
            context,
            PageTransition(
              type: PageTransitionType.sharedAxisVertical,
              child: SearchPage(),
            ),
          );
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     // Show loading indicator
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //         content: Text('Refreshing...'),
      //         duration: Duration(seconds: 1),
      //       ),
      //     );

      //     // Call the refresh function
      //     await widget.onRefresh();

      //     if (mounted) {
      //       // Show success message
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         SnackBar(
      //           content: const Text('Refresh complete!'),
      //           backgroundColor: Theme.of(context).colorScheme.primary,
      //           duration: const Duration(seconds: 1),
      //         ),
      //       );
      //     }
      //   },
      //   tooltip: 'Refresh',
      //   child: const Icon(Icons.refresh),
      // ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        displacement: 100.0,
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              sliver: _posts.isEmpty
                  ? SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height / 2,
                        child: Center(
                          child: Text(
                            'Tidak ada postingan',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    )
                  : SliverMasonryGrid.count(
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
            ),
            // Add end-of-content placeholder if there are posts
            if (_posts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32, top: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: colorScheme.primary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Tidak ada postingan lagi",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Semua postingan sudah dimuat",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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

  Widget _buildPostTile(Post post) {
    return GestureDetector(
      onLongPress: () {
        if (widget.albumId != null && widget.onDeleteFromAlbum != null) {
          _handleDeleteFromAlbum(context, post);
        }
      },
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.sharedAxisScale,
            child: ReelsViewPage(
              posts: _posts,
              imageUrl: post.lokasiFile,
              initialIndex: _posts.indexWhere((p) => p.fotoId == post.fotoId),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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
          if (widget.isProfileView && widget.onDeletePost != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleDelete(context, post),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, Post post) async {
    final colorScheme = Theme.of(context).colorScheme;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Postingan'),
          content:
              const Text('Apakah Anda yakin ingin menghapus postingan ini?'),
          actions: [
            TextButton(
              child: Text(
                'Batal',
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                'Hapus',
                style: TextStyle(color: colorScheme.error),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && widget.onDeletePost != null) {
      try {
        await widget.onDeletePost!(post);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Postingan berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus postingan')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteFromAlbum(BuildContext context, Post post) async {
    final colorScheme = Theme.of(context).colorScheme;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Postingan dari Album'),
          content: const Text(
              'Apakah Anda yakin ingin menghapus postingan ini dari album?'),
          actions: [
            TextButton(
              child: Text(
                'Batal',
                style: TextStyle(color: colorScheme.primary),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                'Hapus',
                style: TextStyle(color: colorScheme.error),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true &&
        widget.onDeleteFromAlbum != null &&
        widget.albumId != null) {
      try {
        await widget.onDeleteFromAlbum!(post);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Postingan berhasil dihapus dari album')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Gagal menghapus postingan dari album')),
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant GridBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts != oldWidget.posts) {
      setState(() {
        _updatePostsList(widget.posts);
      });
    }

    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController.removeListener(_scrollListener);
      widget.scrollController.addListener(_scrollListener);
    }
  }
}

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
              cacheManager: DefaultCacheManager(),
              memCacheWidth: 800,
              memCacheHeight: 800,
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
  final bool keepAlive;

  const KeepAliveBuilder({
    Key? key,
    required this.child,
    this.keepAlive = true,
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

class AnimatedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isVisible;
  final ColorScheme colorScheme;
  final VoidCallback onMenuPressed;
  final VoidCallback onSearchPressed;

  const AnimatedAppBar({
    Key? key,
    required this.isVisible,
    required this.colorScheme,
    required this.onMenuPressed,
    required this.onSearchPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(75);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: const Offset(0, 0),
          ).animate(animation),
          child: child,
        );
      },
      child: isVisible
          ? AppBar(
              key: const ValueKey<String>('AppBar'),
              backgroundColor: Colors.transparent,
              toolbarHeight: 75,
              title: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: onSearchPressed,
                      child: Ink(
                        height: 60,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: colorScheme.surfaceVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.menu_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: onMenuPressed,
                                    ),
                                    StreamBuilder(
                                      stream: FirebaseFirestore.instance
                                          .collection('koleksi_users')
                                          .doc(currentUser?.uid)
                                          .collection('koleksi_notifications')
                                          .where('read', isEqualTo: false)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final int unreadCount =
                                            snapshot.data?.docs.length ?? 0;
                                        if (unreadCount <= 0)
                                          return const SizedBox.shrink();

                                        return Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .error, // Or colorScheme.primary if you prefer
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Penelusuran ...",
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.search,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('Empty')),
    );
  }
}
