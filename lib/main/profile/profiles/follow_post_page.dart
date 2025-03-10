import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

import '../../pages/post_model.dart';
import '../../pages/post_service.dart';
import '../../views/grid/post_info.dart';
import '../../views/grid/reels_view_page.dart';

class FollowPostPage extends StatefulWidget {
  final bool isGridStyle;
  final String selectedFilter;

  const FollowPostPage({
    Key? key,
    this.isGridStyle = true,
    this.selectedFilter = 'following',
  }) : super(key: key);

  @override
  State<FollowPostPage> createState() => FollowPostPageState();
}

class FollowPostPageState extends State<FollowPostPage>
    with AutomaticKeepAliveClientMixin {
  static const String _keyIsGridStyle = 'isGridStyle';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ignore: unused_field
  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

  // ignore: unused_field
  late bool _isGridStyle;
  bool _isLoading = true;
  // ignore: unused_field
  bool _isChangingFilter = false;
  String? _error;
  String? _currentUserId;
  String? _selectedUserId;

  List<DocumentSnapshot> _followingUsers = [];

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _followingSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isGridStyle = widget.isGridStyle;
    _loadPreferences();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _followingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridStyle = prefs.getBool(_keyIsGridStyle) ?? widget.isGridStyle;
    });
  }

  Future<void> _getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        _setupRealTimeFollowingUpdates();
      } else {
        setState(() {
          _error = 'User tidak terautentikasi.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data user: $e';
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeFollowingUpdates() {
    if (_currentUserId == null) return;

    // Cancel any existing subscription
    _followingSubscription?.cancel();

    // Set up real-time listener for following users
    _followingSubscription = _firestore
        .collection('koleksi_follows')
        .doc(_currentUserId)
        .collection('userFollowing')
        .snapshots()
        .listen((snapshot) {
      _loadFollowingUsersData(snapshot.docs);
    }, onError: (e) {
      print('Error in following stream: $e');
      setState(() {
        _error = 'Gagal memuat daftar following: $e';
        _isLoading = false;
      });
    });
  }

  Future<void> _loadFollowingUsersData(
      List<QueryDocumentSnapshot> followingDocs) async {
    try {
      if (followingDocs.isEmpty) {
        if (mounted) {
          setState(() {
            _followingUsers = [];
            _isLoading = false;
          });
        }
        return;
      }

      List<DocumentSnapshot> followingUsersData = [];
      List<Future<DocumentSnapshot>> futures = [];

      // Create a list of futures to fetch user data in parallel
      for (var doc in followingDocs) {
        futures.add(_firestore.collection('koleksi_users').doc(doc.id).get());
      }

      // Wait for all futures to complete
      final results = await Future.wait(futures);

      // Process results
      for (var userDoc in results) {
        if (userDoc.exists) {
          followingUsersData.add(userDoc);
        }
      }

      if (mounted) {
        setState(() {
          _followingUsers = followingUsersData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading following users data: $e');
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data pengguna: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Mengikuti',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Horizontal Filter List
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _followingUsers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedUserId == null,
                      label: const Text('Semua'),
                      onSelected: (selected) {
                        setState(() {
                          _selectedUserId = null;
                        });
                      },
                    ),
                  );
                }

                final userData =
                    _followingUsers[index - 1].data() as Map<String, dynamic>;
                final userId = _followingUsers[index - 1].id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedUserId == userId,
                    avatar: CircleAvatar(
                      backgroundImage: NetworkImage(
                        userData['profile_image_url'] ?? '',
                      ),
                      onBackgroundImageError: (_, __) {},
                    ),
                    label: Text(userData['username'] ?? 'Unknown'),
                    onSelected: (selected) {
                      setState(() {
                        _selectedUserId = selected ? userId : null;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Main Content
          Expanded(
            child: Stack(
              children: [
                if (_error != null && _followingUsers.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _getCurrentUser,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                else if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  RealtimePostsGrid(
                    key: PageStorageKey(
                        'follow_posts_${_selectedUserId ?? "all"}'),
                    selectedUserId: _selectedUserId,
                    followingUsers: _followingUsers,
                  ),
                if (_isChangingFilter)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RealtimePostsGrid extends StatefulWidget {
  const RealtimePostsGrid({
    required Key key,
    this.selectedUserId,
    required this.followingUsers,
  }) : super(key: key);

  final String? selectedUserId;
  final List<DocumentSnapshot> followingUsers;

  @override
  RealtimePostsGridState createState() => RealtimePostsGridState();
}

class RealtimePostsGridState extends State<RealtimePostsGrid>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Post> _postsMap = {};
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  final _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final _postService = PostService();

  // Stream subscriptions for real-time updates
  List<StreamSubscription<QuerySnapshot>> _postStreams = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupRealTimePostsUpdates();
  }

  @override
  void dispose() {
    _cancelAllStreams();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RealtimePostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedUserId != oldWidget.selectedUserId ||
        widget.followingUsers.length != oldWidget.followingUsers.length) {
      _setupRealTimePostsUpdates();
    }
  }

  void _cancelAllStreams() {
    for (var stream in _postStreams) {
      stream.cancel();
    }
    _postStreams.clear();
  }

  void _setupRealTimePostsUpdates() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    // Cancel existing streams
    _cancelAllStreams();

    // Clear existing posts
    _postsMap.clear();

    // Get the list of user IDs to monitor
    List<String> userIds = widget.selectedUserId != null
        ? [widget.selectedUserId!]
        : widget.followingUsers.map((doc) => doc.id).toList();

    if (userIds.isEmpty) {
      setState(() {
        _posts = [];
        _isLoading = false;
      });
      return;
    }

    // Set up a stream for each user's posts
    for (final userId in userIds) {
      final postStream = _firestore
          .collection('koleksi_posts')
          .where('userId', isEqualTo: userId)
          .orderBy('tanggalUnggah', descending: true)
          .snapshots()
          .listen((snapshot) {
        _processPostsSnapshot(snapshot);
      }, onError: (e) {
        print('Error in posts stream for user $userId: $e');
        _handleError('Gagal memuat postingan: $e');
      });

      _postStreams.add(postStream);
    }

    // If we have no streams (shouldn't happen), mark as not loading
    if (_postStreams.isEmpty) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processPostsSnapshot(QuerySnapshot snapshot) {
    try {
      // Process the posts from this snapshot
      for (var doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);
        _postsMap[post.fotoId] = post;
      }

      // Convert map to sorted list
      final sortedPosts = _postsMap.values.toList()
        ..sort((a, b) => b.tanggalUnggah.compareTo(a.tanggalUnggah));

      if (mounted) {
        setState(() {
          _posts = sortedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing posts snapshot: $e');
      _handleError('Gagal memproses data postingan: $e');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    _setupRealTimePostsUpdates();
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    const assetPath = 'assets/images/search.svg';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage ?? 'Terjadi kesalahan'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshPosts,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                        .replaceAll(
                            '#000000', theme.colorScheme.primary.toHex())
                        .replaceAll('#263238', '#263238')
                        .replaceAll('#FFB573', '#FFB573')
                        .replaceAll('#FFFFFF',
                            theme.colorScheme.surfaceContainer.toHex());

                    return SvgPicture.string(
                      svgContent,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada postingan.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _refreshPosts,
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
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
          ),
        ],
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
              imageUrl: post.lokasiFile,
              posts: _posts,
              initialIndex: _posts.indexWhere((p) => p.fotoId == post.fotoId),
            ),
          ),
        );
      },
      child: Column(
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
    );
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

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
