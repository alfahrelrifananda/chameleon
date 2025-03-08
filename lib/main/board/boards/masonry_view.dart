import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gnoo/main/pages/post_model.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import '../../main_page.dart';
import 'search_subpage.dart';
import 'masonry/full_screen_view.dart';
import 'masonry/author_info.dart';
import 'masonry/post_action_bar.dart';
import 'masonry/post_detail_bottom_sheet.dart';

class MasonryBoardView extends StatefulWidget {
  const MasonryBoardView({
    Key? key,
    required this.posts,
    required this.onRefresh,
    required this.scrollController,
  }) : super(key: key);

  final List<Post> posts;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;

  @override
  _MasonryBoardViewState createState() => _MasonryBoardViewState();
}

class _MasonryBoardViewState extends State<MasonryBoardView>
    with SingleTickerProviderStateMixin {
  bool _isAppBarVisible = true;
  double _lastScrollPosition = 0;
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _slideAnimation;
  bool isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _animationController.dispose();
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    final currentScroll = widget.scrollController.position.pixels;
    final mainPage = MainPage.of(context);

    if (widget.scrollController.position.pixels >=
        widget.scrollController.position.maxScrollExtent - 200) {
      // Trigger load more through parent if needed
    }

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
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        displacement: 100.0,
        child: ListView.builder(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
            left: 12,
            right: 12,
            bottom: 12,
          ),
          itemCount: widget.posts.length + 1, // Add one for the placeholder
          itemBuilder: (context, index) {
            // Return post item for regular indices
            if (index < widget.posts.length) {
              return _buildPostItem(context, widget.posts[index]);
            }
            // Return end-of-content placeholder for the last item
            else {
              return _buildEndOfContentPlaceholder(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEndOfContentPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }

  @override
  void didUpdateWidget(MasonryBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts != oldWidget.posts) {
      setState(() {});
    }
  }

  Widget _buildPostItem(BuildContext context, Post post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AuthorInfo(userId: post.userId),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                      12), // Match the container's borderRadius
                  onTap: () => _showPostDetails(context, post),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.judulFoto,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.deskripsiFoto,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimestamp(post.tanggalUnggah),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Post content
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(
                    imageUrl: post.lokasiFile,
                    heroTag: 'post-image-${post.fotoId}',
                  ),
                ),
              );
            },
            child: Hero(
              tag: 'post-image-${post.fotoId}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 5 / 4, // Atur aspek rasio di sini
                  child: post.lokasiFile.toLowerCase().endsWith('.gif')
                      ? Image.network(
                          post.lokasiFile,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                    : null,
                                color: colorScheme.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                              size: 48,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: post.lokasiFile,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: colorScheme.surfaceVariant,
                            highlightColor:
                                colorScheme.onSurfaceVariant.withOpacity(0.2),
                            child: Container(
                              color: colorScheme.surfaceVariant,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                              size: 48,
                            ),
                          ),
                          fit: BoxFit.cover, // Pastikan gambar di-crop
                        ),
                ),
              ),
            ),
          ),
          // Action buttons with animation
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: PostActionBar(
                post: post,
                currentUserId: currentUser.uid,
              ),
            ),
          // Preview content
        ],
      ),
    );
  }

  void _showPostDetails(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostDetailsSheet(post: post),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays > 8) {
      return DateFormat('dd MMM yyyy').format(date);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} hari yang lalu';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} jam yang lalu';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
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
