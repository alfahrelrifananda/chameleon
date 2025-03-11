import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../pages/post_model.dart';
import '../pages/post_service.dart';
import '../views/grid/post_info.dart';
import '../views/grid/reels_view_page.dart';
import 'profiles/edit_post_subpage.dart';
import 'profiles/follow_post_page.dart';
import 'profiles/edit_profile_subpages.dart';
import 'profiles/follow_list_page.dart';
import '../pages/settings_bottom_sheet.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  String? _uid;
  String? _userName;
  String? _namaLengkap;
  String? _userPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  // ignore: unused_field
  bool _isLoading = true;
  // ignore: unused_field
  bool _dataLoaded = false;
  // ignore: unused_field
  final PostService _postService = PostService();
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  late AnimationController _rotationController;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _tabController = TabController(length: 2, vsync: this);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rotationController.dispose();
    _userSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // This is now just a fallback for manual refresh
    // Most updates will happen automatically through streams
    await _loadUserData();
    return Future.value();
  }

  void _setupRealTimeListeners() {
    if (_uid == null) return;

    // Listen for user profile changes
    _userSubscription = _firestore
        .collection('koleksi_users')
        .doc(_uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = userData['username'];
            _namaLengkap = userData['nama_lengkap'];

            _userPhotoUrl = userData['profile_image_url'];
          });
        }
      }
    }, onError: (e) {
      print("Error listening to user data: $e");
    });

    // Listen for followers count changes
    _followersSubscription = _firestore
        .collection('koleksi_follows')
        .doc(_uid)
        .collection('userFollowers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followersCount = snapshot.docs.length;
        });
      }
    }, onError: (e) {
      print("Error listening to followers: $e");
    });

    // Listen for following count changes
    _followingSubscription = _firestore
        .collection('koleksi_follows')
        .doc(_uid)
        .collection('userFollowing')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followingCount = snapshot.docs.length;
        });
      }
    }, onError: (e) {
      print("Error listening to following: $e");
    });
  }

  Future<void> _loadCounts() async {
    try {
      final followersSnapshot = await _firestore
          .collection('koleksi_follows')
          .doc(_uid)
          .collection('userFollowers')
          .count()
          .get();
      _followersCount = followersSnapshot.count!;

      final followingSnapshot = await _firestore
          .collection('koleksi_follows')
          .doc(_uid)
          .collection('userFollowing')
          .count()
          .get();
      _followingCount = followingSnapshot.count!;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error loading counts: $e");
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');

    if (_uid != null) {
      try {
        final userDoc =
            await _firestore.collection('koleksi_users').doc(_uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = userData['username'];
            _namaLengkap = userData['nama_lengkap'];
            _userPhotoUrl = userData['profile_image_url'];
          });
        }

        await _loadCounts();

        // Set up real-time listeners after initial load
        _setupRealTimeListeners();
      } catch (e) {
        print("ProfilePage - Error loading user data: $e");
      } finally {
        setState(() {
          _isLoading = false;
          _dataLoaded = true;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _dataLoaded = true;
      });
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (_userPhotoUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                          body: Container(
                            color: Colors.black,
                            child: PhotoView(
                              imageProvider: NetworkImage(_userPhotoUrl!),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 2,
                              backgroundDecoration: const BoxDecoration(
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationController.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(110, 110),
                            painter: FlowerPainter(
                              color: colorScheme.primaryContainer,
                            ),
                          ),
                        );
                      },
                    ),
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: _userPhotoUrl != null
                          ? NetworkImage(_userPhotoUrl!)
                          : null,
                      child: _userPhotoUrl == null
                          ? Icon(Icons.person,
                              size: 45, color: colorScheme.onPrimaryContainer)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // User info in a column layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'User Name',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _namaLengkap != null && _namaLengkap!.isNotEmpty
                                ? _namaLengkap!
                                : 'Nama belum diisi, Isi Sekarang!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Edit Profile button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final result = Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.sharedAxisVertical,
                              child: EditProfilePage(),
                            ),
                          );
                          if (result == true) {
                            _handleRefresh();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stats section with modern shadows and cards
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _buildStatsItem(context, _formatCount(_postsCount), 'Posts',
                    Icons.grid_4x4, colorScheme.primary),
                _buildVerticalDivider(colorScheme),
                _buildStatsItem(
                  context,
                  _formatCount(_followersCount),
                  'Followers',
                  Icons.people_alt_outlined,
                  colorScheme.secondary,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.sharedAxisVertical,
                        child: FollowListPage(userId: _uid!, initialIndex: 0),
                      ),
                    );
                  },
                ),
                _buildVerticalDivider(colorScheme),
                _buildStatsItem(
                  context,
                  _formatCount(_followingCount),
                  'Following',
                  Icons.person_add_alt_outlined,
                  colorScheme.tertiary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              FollowListPage(userId: _uid!, initialIndex: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsItem(BuildContext context, String count, String label,
      IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              count,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(ColorScheme colorScheme) {
    return Container(
      height: 40,
      width: 1,
      color: colorScheme.outlineVariant.withOpacity(0.5),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
    ColorScheme colorScheme, {
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}JT';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}RB';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Profil'),
              pinned: true,
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.group_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.sharedAxisVertical,
                      child: FollowPostPage(),
                    ),
                  ),
                ),
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
            SliverToBoxAdapter(
              child: _buildProfileHeader(context),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        context,
                        'Dibuat',
                        Icons.grid_on_rounded,
                        _tabController.index == 0,
                        colorScheme,
                        onTap: () {
                          setState(() {
                            _tabController.index = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabButton(
                        context,
                        'Favorit',
                        Icons.favorite_border_rounded,
                        _tabController.index == 1,
                        colorScheme,
                        onTap: () {
                          setState(() {
                            _tabController.index = 1;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_tabController.index == 0)
              PostsGrid(
                key: const PageStorageKey('dibuat'),
                type: 'dibuat',
                uid: _uid,
                onPostsLoaded: (count) {
                  setState(() {
                    _postsCount = count;
                  });
                },
              )
            else
              PostsGrid(
                key: const PageStorageKey('favorit'),
                type: 'favorit',
                uid: _uid,
              ),
          ],
        ),
      ),
    );
  }
}

class FlowerPainter extends CustomPainter {
  final Color color;

  FlowerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    const int petalCount = 8;
    const double petalDepth = 0.15;

    final Path path = Path();

    for (int i = 0; i < petalCount; i++) {
      double angle = (i * (360 / petalCount)) * (pi / 180);
      double nextAngle = ((i + 1) * (360 / petalCount)) * (pi / 180);

      double startX = centerX + radius * (1 - petalDepth) * cos(angle);
      double startY = centerY + radius * (1 - petalDepth) * sin(angle);
      double endX = centerX + radius * (1 - petalDepth) * cos(nextAngle);
      double endY = centerY + radius * (1 - petalDepth) * sin(nextAngle);

      double controlX1 =
          centerX + radius * cos(angle + (nextAngle - angle) / 3);
      double controlY1 =
          centerY + radius * sin(angle + (nextAngle - angle) / 3);
      double controlX2 =
          centerX + radius * cos(nextAngle - (nextAngle - angle) / 3);
      double controlY2 =
          centerY + radius * sin(nextAngle - (nextAngle - angle) / 3);

      if (i == 0) {
        path.moveTo(startX, startY);
      }

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class PostsGrid extends StatefulWidget {
  const PostsGrid({
    Key? key,
    required this.type,
    this.uid,
    this.onPostsLoaded,
  }) : super(key: key);

  final String type;
  final String? uid;
  final Function(int count)? onPostsLoaded;

  @override
  PostsGridState createState() => PostsGridState();
}

class PostsGridState extends State<PostsGrid>
    with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;
  // ignore: unused_field
  final PostService _postService = PostService();
  final _firestore = FirebaseFirestore.instance;

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _postsSubscription;
  StreamSubscription<QuerySnapshot>? _likesSubscription;

  // Map to track post IDs to prevent duplicates
  final Map<String, Post> _postsMap = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _likesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid || widget.type != oldWidget.type) {
      // Cancel existing subscriptions
      _postsSubscription?.cancel();
      _likesSubscription?.cancel();

      // Setup new subscriptions
      setupRealTimeUpdates();
    }
  }

  void setupRealTimeUpdates() {
    if (widget.uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      if (widget.type == 'dibuat') {
        // Listen for user's posts in real-time
        _postsSubscription = _firestore
            .collection('koleksi_posts')
            .where('userId', isEqualTo: widget.uid)
            .orderBy('tanggalUnggah', descending: true)
            .snapshots()
            .listen((snapshot) {
          _updatePostsFromSnapshot(snapshot);
        }, onError: (error) {
          _handleError('Error listening to posts: $error');
        });
      } else {
        // For liked posts, we need to listen to both likes and posts
        _setupLikedPostsRealTimeUpdates();
      }
    } catch (e) {
      print("Error setting up real-time updates: $e");
      print(StackTrace.current);
      _handleError('Gagal memuat data. Tarik ke bawah untuk mencoba lagi.');
    }
  }

  void _setupLikedPostsRealTimeUpdates() {
    // Listen for user's likes in real-time
    _likesSubscription = _firestore
        .collection('koleksi_likes')
        .where('userId', isEqualTo: widget.uid)
        .snapshots()
        .listen((likesSnapshot) async {
      try {
        final postIds = likesSnapshot.docs
            .map((doc) => doc.get('fotoId') as String)
            .toList();

        if (postIds.isEmpty) {
          if (mounted) {
            setState(() {
              _posts = [];
              _postsMap.clear();
              _isLoading = false;
            });

            if (widget.onPostsLoaded != null) {
              widget.onPostsLoaded!(0);
            }
          }
          return;
        }

        // We need to handle the case where there are many liked posts
        // Firestore has a limit of 10 items in a whereIn query
        final batches = <List<String>>[];
        for (var i = 0; i < postIds.length; i += 10) {
          final end = (i + 10 < postIds.length) ? i + 10 : postIds.length;
          batches.add(postIds.sublist(i, end));
        }

        final allPosts = <Post>[];

        for (final batch in batches) {
          final postsSnapshot = await _firestore
              .collection('koleksi_posts')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          final batchPosts =
              postsSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

          allPosts.addAll(batchPosts);
        }

        if (mounted) {
          _updatePostsList(allPosts);
        }
      } catch (e) {
        print("Error processing likes: $e");
        _handleError('Gagal memuat data yang disukai.');
      }
    }, onError: (error) {
      _handleError('Error listening to likes: $error');
    });
  }

  void _updatePostsFromSnapshot(QuerySnapshot snapshot) {
    final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    _updatePostsList(posts);
  }

  void _updatePostsList(List<Post> posts) {
    // Update the posts map to track unique posts
    _postsMap.clear();
    for (final post in posts) {
      _postsMap[post.fotoId] = post;
    }

    // Sort posts by date (newest first)
    final sortedPosts = _postsMap.values.toList()
      ..sort((a, b) => b.tanggalUnggah.compareTo(a.tanggalUnggah));

    if (mounted) {
      setState(() {
        _posts = sortedPosts;
        _isLoading = false;
      });

      if (widget.onPostsLoaded != null) {
        widget.onPostsLoaded!(_posts.length);
      }
    }
  }

  Future<void> loadPosts() async {
    // This method is kept for backward compatibility
    // It will be called when the user manually refreshes
    setupRealTimeUpdates();
  }

  void _handleError(String errorMessage) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = errorMessage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          action: SnackBarAction(
            label: 'Coba Lagi',
            onPressed: loadPosts,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()));
    }

    if (_posts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height / 2,
          child: Center(
            child: Text(
              widget.type == 'dibuat'
                  ? 'Belum ada postingan yang dibuat'
                  : 'Belum ada postingan yang disukai',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverMasonryGrid.count(
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
          // Add a SliverToBoxAdapter with padding at the bottom to account for the floating navbar
          SliverToBoxAdapter(
            child: SizedBox(
                height: 80), // Adjust this height based on your navbar height
          ),
        ],
      ),
    );
  }

  Widget _buildPostTile(Post post) {
    final List<Post> postsForReels = _posts;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.sharedAxisScale,
            child: ReelsViewPage(
              imageUrl: post.lokasiFile,
              posts: postsForReels,
              initialIndex:
                  postsForReels.indexWhere((p) => p.fotoId == post.fotoId),
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
          if (widget.type == 'dibuat')
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                shape: CircleBorder(),
                color: Theme.of(context).colorScheme.surface,
                child: IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 14,
                  ),
                  padding: EdgeInsets.all(1),
                  onPressed: () => _navigateToEditPost(post),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToEditPost(Post post) async {
    bool? shouldEdit = await showModalBottomSheet<bool>(
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
                'Edit Post',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah kamu ingin mengedit post ini?',
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
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Ya, Edit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (shouldEdit == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Mempersiapkan editor...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Simulate 3 second loading
      await Future.delayed(Duration(seconds: 3));

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to edit page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditPostPage(post: post),
        ),
      );
      if (result == true) {
        loadPosts();
      }
    }
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
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.95, // Adjust as needed
            child: AspectRatio(
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
