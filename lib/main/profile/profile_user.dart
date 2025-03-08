import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:photo_view/photo_view.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../album/albums/album_detail_search.dart';
import '../album/albums/album_model.dart';
import '../board/boards/notification_subpage.dart';
import '../chat/chats/chat_page.dart';
import '../pages/post_model.dart';
import '../pages/post_service.dart';
import '../views/grid/post_info.dart';
import '../views/grid/reels_view_page.dart';
import 'profiles/edit_profile_subpages.dart';
import 'profiles/follow_list_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with TickerProviderStateMixin {
  late String _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhotoUrl;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  // ignore: unused_field
  bool _isLoading = true;
  bool _isFollowing = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;
  late AnimationController _rotationController;
  final NotificationHandler _notificationHandler = NotificationHandler();

  @override
  void initState() {
    super.initState();
    _userId = widget.userId;
    // Change the TabController length to 3 for Dibuat, Favorit, and Album
    _tabController = TabController(length: 3, vsync: this);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _loadUserData();
    _checkIfFollowing();
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userName = userData['username'];
          _userEmail = userData['email'];
          _userPhotoUrl = userData['profile_image_url'];
        });
      }
    } catch (e) {
      print("UserProfilePage - Error loading user data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    try {
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_follows')
          .doc(_userId)
          .collection('userFollowers')
          .count()
          .get();
      _followersCount = followersSnapshot.count!;

      final followingSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_follows')
          .doc(_userId)
          .collection('userFollowing')
          .count()
          .get();
      _followingCount = followingSnapshot.count!;

      final postsSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_posts')
          .where('userId', isEqualTo: _userId)
          .count()
          .get();
      _postsCount = postsSnapshot.count!;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error loading counts: $e");
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}JT';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}RB';
    }
    return count.toString();
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUserId == null || _currentUserId == _userId) return;

    try {
      final followDoc = await FirebaseFirestore.instance
          .collection('koleksi_follows')
          .doc(_currentUserId)
          .collection('userFollowing')
          .doc(_userId)
          .get();

      setState(() {
        _isFollowing = followDoc.exists;
      });
    } catch (e) {
      print("Error checking follow status: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _currentUserId == _userId) return;

    try {
      final followsRef =
          FirebaseFirestore.instance.collection('koleksi_follows');
      final followingRef = followsRef
          .doc(_currentUserId)
          .collection('userFollowing')
          .doc(_userId);
      final followersRef = followsRef
          .doc(_userId)
          .collection('userFollowers')
          .doc(_currentUserId);

      // Simpan status sebelumnya untuk menentukan apakah ini follow baru
      final bool isNewFollow = !_isFollowing;

      setState(() {
        _isFollowing = !_isFollowing;
      });

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        if (_isFollowing) {
          transaction
              .set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
          transaction
              .set(followersRef, {'timestamp': FieldValue.serverTimestamp()});
        } else {
          transaction.delete(followingRef);
          transaction.delete(followersRef);
        }
      });

      // Kirim notifikasi hanya jika ini adalah follow baru (bukan unfollow)
      if (isNewFollow) {
        // Dapatkan data user yang sedang login
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('koleksi_users')
            .doc(_currentUserId)
            .get();

        if (currentUserDoc.exists) {
          final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
          final currentUsername = currentUserData['username'] ?? 'Unknown User';

          // Buat notifikasi follow
          await _notificationHandler.createCommentNotification(
            recipientUserId: _userId,
            senderUserId: _currentUserId,
            senderUsername: currentUsername,
            postId: '', // Kosong karena tidak terkait dengan post tertentu
            commentId: '', // Kosong karena tidak terkait dengan komentar
            content: 'Mengikuti anda',
            type: NotificationType
                .follow, // Pastikan ada tipe notifikasi follow di enum NotificationType
          );
        }
      }
    } catch (e) {
      print("Error toggling follow: $e");
      setState(() {
        _isFollowing = !_isFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${_isFollowing ? 'follow' : 'unfollow'}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      _loadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _loadCounts();
          switch (_tabController.index) {
            case 0:
              await (_PostsGrid(
                key: PageStorageKey('dibuat_user_$_userId'),
                type: 'dibuat',
                uid: _userId,
              ).key as GlobalKey<_PostsGridState>)
                  .currentState
                  ?._loadPosts();
              break;
            case 1:
              await (_PostsGrid(
                key: PageStorageKey('favorit_user_$_userId'),
                type: 'favorit',
                uid: _userId,
              ).key as GlobalKey<_PostsGridState>)
                  .currentState
                  ?._loadPosts();
              break;
            case 2:
              await (_AlbumsGrid(
                key: PageStorageKey('album_user_$_userId'),
                uid: _userId,
              ).key as GlobalKey<_AlbumsGridState>)
                  .currentState
                  ?._loadAlbums();
              break;
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(_userName ?? 'User Profile'),
              pinned: true,
              floating: true,
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
                        _tabController.index == 0,
                        Theme.of(context).colorScheme,
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
                        _tabController.index == 1,
                        Theme.of(context).colorScheme,
                        onTap: () {
                          setState(() {
                            _tabController.index = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabButton(
                        context,
                        'Album',
                        _tabController.index == 2,
                        Theme.of(context).colorScheme,
                        onTap: () {
                          setState(() {
                            _tabController.index = 2;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_tabController.index == 0)
              _PostsGrid(
                key: PageStorageKey('dibuat_user_$_userId'),
                type: 'dibuat',
                uid: _userId,
              )
            else if (_tabController.index == 1)
              _PostsGrid(
                key: PageStorageKey('favorit_user_$_userId'),
                type: 'favorit',
                uid: _userId,
              )
            else
              _AlbumsGrid(
                key: PageStorageKey('album_user_$_userId'),
                uid: _userId,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          // Top section with avatar and user info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add GestureDetector to make profile picture clickable
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
                        // Icon(
                        //   Icons.email_outlined,
                        //   size: 16,
                        //   color: colorScheme.onSurfaceVariant,
                        // ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _userEmail ?? 'user@gmail.com',
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

                    // Add action buttons (follow/DM) from original code
                    if (_currentUserId != null &&
                        _currentUserId != _userId) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _isFollowing
                                ? OutlinedButton(
                                    onPressed: _toggleFollow,
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: const Text('Unfollow'),
                                  )
                                : FilledButton(
                                    onPressed: _toggleFollow,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: const Text('Ikuti'),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      recipientUserId: _userId,
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('DM'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_currentUserId == _userId) ...[
                      // Edit Profile button (only for current user)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.sharedAxisVertical,
                                child: EditProfilePage(),
                              ),
                            );
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
                        child: FollowListPage(userId: _userId, initialIndex: 0),
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
                      PageTransition(
                        type: PageTransitionType.sharedAxisVertical,
                        child: FollowListPage(userId: _userId, initialIndex: 1),
                      ),
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
}

class _PostsGrid extends StatefulWidget {
  const _PostsGrid({required Key key, required this.type, this.uid})
      : super(key: key);

  final String type;
  final String? uid;

  @override
  _PostsGridState createState() => _PostsGridState();
}

class _PostsGridState extends State<_PostsGrid>
    with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;
  final PostService _postService = PostService();
  final _firestore = FirebaseFirestore.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant _PostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uid != oldWidget.uid || widget.type != oldWidget.type) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
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

      final posts = widget.type == 'dibuat'
          ? await _postService.getPostsByUser(widget.uid!)
          : await _loadLikedPosts(widget.uid!);

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading posts: $e");
      print(StackTrace.current);
      _handleError('Gagal memuat data. Tarik ke bawah untuk mencoba lagi.');
    }
  }

  Future<List<Post>> _loadLikedPosts(String uid) async {
    final likesSnapshot = await _firestore
        .collection('koleksi_likes')
        .where('userId', isEqualTo: uid)
        .get();

    final postIds =
        likesSnapshot.docs.map((doc) => doc.get('fotoId') as String).toList();

    if (postIds.isEmpty) return [];

    final postsSnapshot = await _firestore
        .collection('koleksi_posts')
        .where(FieldPath.documentId, whereIn: postIds)
        .get();

    return postsSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
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
            onPressed: _loadPosts,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Penting untuk AutomaticKeepAliveClientMixin

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
        ],
      ),
    );
  }
}

// Add the AlbumsGrid widget from the new file
class _AlbumsGrid extends StatefulWidget {
  const _AlbumsGrid({required Key key, required this.uid}) : super(key: key);

  final String uid;

  @override
  _AlbumsGridState createState() => _AlbumsGridState();
}

class _AlbumsGridState extends State<_AlbumsGrid>
    with AutomaticKeepAliveClientMixin {
  List<Album> _albums = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final albumsSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_albums')
          .where('userId', isEqualTo: widget.uid)
          .get();

      final albums = albumsSnapshot.docs
          .map((doc) => Album.fromMap({...doc.data(), 'albumId': doc.id}))
          .toList();

      if (mounted) {
        setState(() {
          _albums = albums;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading albums: $e");
      _handleError('Gagal memuat album. Tarik ke bawah untuk mencoba lagi.');
    }
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
            onPressed: _loadAlbums,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_albums.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height / 2,
          child: Center(
            child: Text(
              'Belum ada album yang dibuat',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverAnimatedGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        initialItemCount: _albums.length,
        itemBuilder:
            (BuildContext context, int index, Animation<double> animation) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildAlbumCard(context, _albums[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album) {
    final colorScheme = Theme.of(context).colorScheme;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageTransition(
              type: PageTransitionType.sharedAxisScale,
              child: AlbumDetailPageUser(album: album),
            ),
          );
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
                    return _buildLoadingAlbumCard(colorScheme);
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return _buildPlaceholderAlbumCard(colorScheme, album);
                  }

                  final savedPosts = snapshot.data!.docs;

                  return Material(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.sharedAxisScale,
                            child: AlbumDetailPageUser(album: album),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            if (index < savedPosts.length) {
                              final fotoId = savedPosts[index]['fotoId'];
                              return _buildAlbumImage(
                                  context, fotoId, colorScheme);
                            } else {
                              return _buildPlaceholderImage(colorScheme);
                            }
                          },
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
      ),
    );
  }

  Widget _buildAlbumImage(
      BuildContext context, String fotoId, ColorScheme colorScheme) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('koleksi_posts')
          .doc(fotoId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingImage(colorScheme);
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildPlaceholderImage(colorScheme);
        }

        final post = snapshot.data!;
        final imageUrl = post['lokasiFile'];

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 300,
            memCacheHeight: 300,
            placeholder: (context, url) => _buildLoadingImage(colorScheme),
            errorWidget: (context, url, error) => _buildErrorImage(colorScheme),
          ),
        );
      },
    );
  }

  Widget _buildLoadingAlbumCard(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children:
              List.generate(4, (index) => _buildLoadingImage(colorScheme)),
        ),
      ),
    );
  }

  Widget _buildLoadingImage(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceVariant,
        highlightColor: colorScheme.onSurfaceVariant.withOpacity(0.2),
        child: Container(color: colorScheme.surfaceVariant),
      ),
    );
  }

  Widget _buildErrorImage(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: colorScheme.error,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPlaceholderAlbumCard(ColorScheme colorScheme, Album album) {
    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children:
              List.generate(4, (index) => _buildPlaceholderImage(colorScheme)),
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
      // child: const Center(
      //   child: Icon(Icons.image, size: 48),
      // ),
    );
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
