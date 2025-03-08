import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Make sure this import is included
import 'package:gnoo/main/pages/post_model.dart';
import 'package:page_transition/page_transition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';
import '../../pages/post_service.dart';
import '../../board/boards/notification_subpage.dart';
import '../comments_bottom_sheet.dart';
import '../bookmark_view.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

import '../../board/boards/masonry/author_info.dart';
import '../../board/boards/masonry/post_detail_bottom_sheet.dart';

class ReelsViewPage extends StatefulWidget {
  final String imageUrl;
  final List<Post> posts;
  final int initialIndex;

  const ReelsViewPage({
    Key? key,
    required this.posts,
    required this.imageUrl,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ReelsViewPage> createState() => _ReelsViewPageState();
}

class _ReelsViewPageState extends State<ReelsViewPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _postService = PostService();
  bool isLoading = false;
  bool isBookmarkLoading = false;
  bool isSaved = false;
  late Stream<QuerySnapshot> _bookmarkStream;
  double _downloadProgress = 0.0;
  // ignore: unused_field
  bool _showLikeAnimation = false;

  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _likeOpacityAnimation;

  final NotificationHandler _notificationHandler = NotificationHandler();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeBookmarkStream();

    // Disable edge-to-edge mode for this page
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize animation controller
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Scale animation: starts small, gets bigger, then slightly smaller again
    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_likeAnimationController);

    // Opacity animation for fade in/out
    _likeOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_likeAnimationController);
  }

  void _initializeBookmarkStream() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _bookmarkStream = _firestore
          .collection('koleksi_albums')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _likeAnimationController.dispose();

    // Restore edge-to-edge mode when leaving this page
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<void> _toggleLike(
      Post post, bool isLiked, String currentUserId) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final previousState = isLiked;
    setState(() => isLiked = !isLiked); // Optimistic update

    try {
      // Prepare references
      final likeRef = _firestore
          .collection('koleksi_likes')
          .doc('${currentUserId}_${post.fotoId}');
      final postRef = _firestore.collection('koleksi_posts').doc(post.fotoId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final likeDoc = await transaction.get(likeRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final currentLikes = postDoc.data()?['likes'] ?? 0;
        final postOwnerId = postDoc.data()?['userId'] as String?;

        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': currentLikes - 1,
          });
        } else {
          transaction.set(likeRef, {
            'userId': currentUserId,
            'fotoId': post.fotoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likes': currentLikes + 1,
          });

          // Send notification only if:
          // 1. We have the post owner's ID
          // 2. The liker is not the post owner
          // 3. This is a new like (not an unlike)
          if (postOwnerId != null && postOwnerId != currentUserId) {
            // Get current user's data for notification
            final currentUserDoc = await _firestore
                .collection('koleksi_users')
                .doc(currentUserId)
                .get();

            if (currentUserDoc.exists) {
              final userData = currentUserDoc.data()!;
              final username = userData['username'] ?? 'Unknown User';

              // Create notification
              await _notificationHandler.createCommentNotification(
                recipientUserId: postOwnerId,
                senderUserId: currentUserId,
                senderUsername: username,
                postId: post.fotoId,
                commentId: '', // Empty for likes
                content: 'Menyukai postingan anda',
                type: NotificationType.postLike,
              );
            }
          }
        }
      });

      // Update the like count cache
      final newLikeCount = await _postService.getLikeCount(post.fotoId);
      await _postService.updateLikeCache(post.fotoId, newLikeCount);
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        setState(() => isLiked = previousState); // Rollback on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isLiked ? 'unlike' : 'like'} the post'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<int> _getCommentCount(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('koleksi_comments')
          .where('postId', isEqualTo: postId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting comment count: $e');
      return 0;
    }
  }

  Future<bool> _checkIfPostSavedInAlbums(List<DocumentSnapshot> albums) async {
    for (final albumDoc in albums) {
      final savedPostDoc = await _firestore
          .collection('koleksi_albums')
          .doc(albumDoc.id)
          .collection('saved_posts')
          .doc(widget.posts[_currentIndex].fotoId)
          .get();

      if (savedPostDoc.exists) {
        return true;
      }
    }
    return false;
  }

  void _showSaveToAlbumBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaveToAlbumBottomSheet(
        postId: widget.posts[_currentIndex].fotoId,
        userId: _auth.currentUser!.uid,
      ),
    ).then((_) {
      setState(() {
        isBookmarkLoading = true;
      });
      _updateBookmarkStatus();
    });
  }

  Future<void> _updateBookmarkStatus() async {
    try {
      final userAlbums = await _firestore
          .collection('koleksi_albums')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .get();

      final isPostSaved = await _checkIfPostSavedInAlbums(userAlbums.docs);

      if (mounted) {
        setState(() {
          isSaved = isPostSaved;
          isBookmarkLoading = false;
        });
      }
    } catch (e) {
      print('Error updating bookmark status: $e');
      if (mounted) {
        setState(() {
          isBookmarkLoading = false;
        });
      }
    }
  }

  Future<void> _handleBookmarkTap() async {
    if (isBookmarkLoading) return;
    _showSaveToAlbumBottomSheet(context);
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

  Future<void> _downloadImage(String lokasiFile) async {
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

  void _showOptionsBottomSheet(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _bookmarkStream,
              builder: (context, albumsSnapshot) {
                if (albumsSnapshot.hasData) {
                  _checkIfPostSavedInAlbums(albumsSnapshot.data!.docs)
                      .then((saved) {
                    if (mounted && saved != isSaved) {
                      setState(() {
                        isSaved = saved;
                      });
                    }
                  });
                }

                return ListTile(
                  leading: isBookmarkLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  title: Text('Simpan ke Album'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleBookmarkTap();
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Gambar'),
              onTap: () {
                Navigator.pop(context);
                _downloadImage(post.lokasiFile);
              },
            ),
            // Add the new full screen view option
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Lihat Layar Penuh'),
              onTap: () {
                Navigator.pop(context);
                _openFullScreenView(context, post.lokasiFile);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenView(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              return _buildReelItem(context, post);
            },
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white,
                      ),
                      onPressed: () => _showOptionsBottomSheet(
                        context,
                        widget.posts[_currentIndex],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(BuildContext context, Post post) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _auth.currentUser;
    final ValueNotifier<bool> isLiked = ValueNotifier<bool>(false);

    // Check like status when widget builds
    if (currentUser != null) {
      _firestore
          .collection('koleksi_likes')
          .doc('${currentUser.uid}_${post.fotoId}')
          .get()
          .then((doc) {
        isLiked.value = doc.exists;
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTap: currentUser == null
              ? null
              : () async {
                  // Get tap position for centered animation
                  // Reset animation controller
                  _likeAnimationController.reset();
                  _likeAnimationController.forward();

                  // Check current like status
                  final likeDoc = await _firestore
                      .collection('koleksi_likes')
                      .doc('${currentUser.uid}_${post.fotoId}')
                      .get();

                  final bool isCurrentlyLiked = likeDoc.exists;
                  isLiked.value = !isCurrentlyLiked;

                  // Toggle like status
                  await _toggleLike(post, isCurrentlyLiked, currentUser.uid);
                },
          child: CachedNetworkImage(
            imageUrl: post.lokasiFile,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: colorScheme.surfaceVariant,
              highlightColor: colorScheme.onSurfaceVariant.withOpacity(0.2),
              child: Container(color: colorScheme.surfaceVariant),
            ),
            errorWidget: (context, url, error) {
              print("Error loading image: $error");
              return Container(
                color: colorScheme.surfaceVariant,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Like animation overlay with Material 3 dynamic colors
        Center(
          child: AnimatedBuilder(
            animation: _likeAnimationController,
            builder: (context, child) {
              return Opacity(
                opacity: _likeOpacityAnimation.value,
                child: Transform.scale(
                  scale: _likeScaleAnimation.value,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isLiked,
                    builder: (context, liked, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow effect
                          Icon(
                            Icons.favorite,
                            color: liked
                                ? colorScheme.primary.withOpacity(0.3)
                                : Colors.white.withOpacity(0.3),
                            size: 120,
                          ),
                          // Inner heart
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              // Create a gradient based on the dynamic colorScheme
                              return LinearGradient(
                                colors: liked
                                    ? [
                                        colorScheme.primary,
                                        colorScheme.tertiary,
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.7),
                                      ],
                                transform: GradientRotation(math.pi / 4),
                              ).createShader(bounds);
                            },
                            child: Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 96,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        _buildPostDetails(context, widget.posts[_currentIndex]),
      ],
    );
  }

  Widget _buildPostDetails(BuildContext context, Post post) {
    final currentUser = _auth.currentUser;
    // ignore: unused_local_variable
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.9), // Increased opacity
                Colors.black.withOpacity(0.6), // Added middle stop
                Colors.transparent,
              ],
              stops: const [
                0.0,
                0.5,
                1.0
              ], // Adjusted stops for smoother transition
            ),
          ),
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
            top: 32, // Added top padding for content
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.judulFoto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showPostDetails(context, post),
                child: Text(
                  post.deskripsiFoto,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Author info widget
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.copyWith(
                              titleMedium: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                      ),
                      child: AuthorInfo(userId: post.userId),
                    ),
                  ),
                  // Action buttons
                  if (currentUser != null)
                    _buildActionButtons(context, post, currentUser.uid),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildActionButtons(
      BuildContext context, Post post, String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;
    final postStream =
        _firestore.collection('koleksi_posts').doc(post.fotoId).snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('koleksi_likes')
          .doc('${currentUserId}_${post.fotoId}')
          .snapshots(),
      builder: (context, likeSnapshot) {
        final isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;

        return Row(
          children: [
            _buildIconButton(
              icon: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? colorScheme.primary : Colors.white,
                    ),
              label: StreamBuilder<DocumentSnapshot>(
                stream: postStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      '${post.likes ?? 0}',
                      style: const TextStyle(color: Colors.white),
                    );
                  }
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final likes = data?['likes'] ?? post.likes ?? 0;
                  return Text(
                    '$likes',
                    style: const TextStyle(color: Colors.white),
                  );
                },
              ),
              onPressed: isLoading
                  ? null
                  : () => _toggleLike(post, isLiked, currentUserId),
            ),
            const SizedBox(width: 16),
            _buildIconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: FutureBuilder<int>(
                future: _getCommentCount(post.fotoId),
                builder: (context, snapshot) {
                  return Text(
                    '${snapshot.data ?? 0}',
                    style: const TextStyle(color: Colors.white),
                  );
                },
              ),
              onPressed: () => Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: CommentPage(
                    post: post,
                    currentUserId: currentUserId,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconButton({
    required Widget icon,
    required Widget label,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            label,
          ],
        ),
      ),
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              color: colorScheme.primary,
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded /
                      (event.expectedTotalBytes ?? 1),
            ),
          ),
        ),
        errorBuilder: (context, obj, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat gambar',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        heroAttributes: const PhotoViewHeroAttributes(tag: "fullScreenImage"),
      ),
    );
  }
}

enum SnackBarType {
  success,
  error,
}
