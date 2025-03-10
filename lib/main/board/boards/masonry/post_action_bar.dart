import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'dart:async';
import '../../../pages/post_model.dart';
import '../../../pages/post_service.dart';
import '../notification_subpage.dart';
import '../../../views/bookmark_view.dart';
import '../../../views/comments_bottom_sheet.dart';

class PostActionBar extends StatefulWidget {
  final Post post;
  final String currentUserId;

  const PostActionBar({
    Key? key,
    required this.post,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  bool isLiked = false;
  bool isSaved = false;
  bool isLoading = false;
  bool isBookmarkLoading = false;
  int currentLikeCount = 0;
  int currentCommentCount = 0;
  final _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final _postService = PostService();
  late Stream<DocumentSnapshot> _postStream;
  late Stream<QuerySnapshot> _bookmarkStream;
  late Stream<QuerySnapshot> _commentStream;
  // Add a stream subscription field at the top of the class
  StreamSubscription<DocumentSnapshot>? _likeStatusStream;

  // Add NotificationHandler instance
  final NotificationHandler _notificationHandler = NotificationHandler();

  // Update initState to not call _checkIfLiked
  @override
  void initState() {
    super.initState();
    // Initialize like count from the post object
    currentLikeCount = widget.post.likes ?? 0;
    _initializeStreams();
  }

  // Update didUpdateWidget to handle changes properly
  @override
  void didUpdateWidget(PostActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the post object changes (e.g., during refresh), update the streams
    if (oldWidget.post.fotoId != widget.post.fotoId) {
      // Cancel existing subscription
      _likeStatusStream?.cancel();

      _initializeStreams();
    }

    // Update the like count if it changed in the post object
    if (oldWidget.post.likes != widget.post.likes) {
      setState(() {
        currentLikeCount = widget.post.likes ?? 0;
      });
    }
  }

  // Replace the _checkIfLiked method with a real-time listener
  void _initializeStreams() {
    _postStream = _firestore
        .collection('koleksi_posts')
        .doc(widget.post.fotoId)
        .snapshots();

    // Stream untuk memantau status bookmark di semua album
    _bookmarkStream = _firestore
        .collection('koleksi_albums')
        .where('userId', isEqualTo: widget.currentUserId)
        .snapshots();

    // Stream untuk memantau komentar
    _commentStream = _firestore
        .collection('koleksi_comments')
        .where('postId', isEqualTo: widget.post.fotoId)
        .snapshots();

    // Add a stream to listen for the user's like status
    _likeStatusStream = _firestore
        .collection('koleksi_likes')
        .doc('${widget.currentUserId}_${widget.post.fotoId}')
        .snapshots()
        .listen((likeDoc) {
      if (mounted) {
        setState(() {
          isLiked = likeDoc.exists;
        });
      }
    }, onError: (e) {
      print('Error checking like status: $e');
    });
  }

  Future<void> _toggleLike() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final previousState = isLiked;
    final previousCount = currentLikeCount;

    // Optimistic update
    setState(() {
      isLiked = !isLiked;
      currentLikeCount = isLiked ? currentLikeCount + 1 : currentLikeCount - 1;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        final likeRef = _firestore
            .collection('koleksi_likes')
            .doc('${widget.currentUserId}_${widget.post.fotoId}');
        final postRef =
            _firestore.collection('koleksi_posts').doc(widget.post.fotoId);

        final postDoc = await transaction.get(postRef);
        final likeDoc = await transaction.get(likeRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final serverLikes = postDoc.data()?['likes'] ?? 0;
        final postOwnerId = postDoc.data()?['userId'] as String?;

        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': serverLikes - 1,
          });
        } else {
          transaction.set(likeRef, {
            'userId': widget.currentUserId,
            'fotoId': widget.post.fotoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likes': serverLikes + 1,
          });

          // Send notification only if:
          // 1. We have the post owner's ID
          // 2. The liker is not the post owner
          // 3. This is a new like (not an unlike)
          if (postOwnerId != null && postOwnerId != widget.currentUserId) {
            // Get current user's data for notification
            final currentUserDoc = await _firestore
                .collection('koleksi_users')
                .doc(widget.currentUserId)
                .get();

            if (currentUserDoc.exists) {
              final userData = currentUserDoc.data()!;
              final username = userData['username'] ?? 'Unknown User';

              // Get post data for notification
              final postData = postDoc.data()!;
              // ignore: unused_local_variable
              final postImage = postData['lokasiFile'] as String?;

              // Create notification
              await _notificationHandler.createCommentNotification(
                recipientUserId: postOwnerId,
                senderUserId: widget.currentUserId,
                senderUsername: username,
                postId: widget.post.fotoId,
                commentId: '', // Empty for likes
                content: 'Menyukai postingan anda',
                type: NotificationType.postLike,
              );
            }
          }
        }
      });
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        // Rollback on error
        setState(() {
          isLiked = previousState;
          currentLikeCount = previousCount;
        });

        _showSnackBar(
          'Gagal ${isLiked ? 'unlike' : 'like'} post',
          type: SnackBarType.error,
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

  Future<bool> _checkIfPostSavedInAlbums(List<DocumentSnapshot> albums) async {
    for (final albumDoc in albums) {
      final savedPostDoc = await _firestore
          .collection('koleksi_albums')
          .doc(albumDoc.id)
          .collection('saved_posts')
          .doc(widget.post.fotoId)
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
        postId: widget.post.fotoId,
        userId: widget.currentUserId,
      ),
    ).then((_) {
      // Refresh bookmark status after bottom sheet is closed
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
          .where('userId', isEqualTo: widget.currentUserId)
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

    // Always show the album bottom sheet, regardless of saved status
    _showSaveToAlbumBottomSheet(context);

    // Remove the conditional logic that was checking isSaved
    // The old code with the confirmation dialog is removed
  }

  void _showSnackBar(String message, {required SnackBarType type}) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    IconData iconData;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        iconData = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        iconData = Icons.error_outline;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: textColor),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Update the dispose method to cancel the subscription
  @override
  void dispose() {
    _likeStatusStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: _bookmarkStream,
      builder: (context, albumsSnapshot) {
        if (albumsSnapshot.hasData) {
          // Update bookmark status when albums change
          _checkIfPostSavedInAlbums(albumsSnapshot.data!.docs).then((saved) {
            if (mounted && saved != isSaved) {
              setState(() {
                isSaved = saved;
              });
            }
          });
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              // Like button section
              Row(
                children: [
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isLoading
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
                              key: ValueKey(isLiked),
                              color: isLiked ? colorScheme.primary : null,
                            ),
                    ),
                    onPressed: isLoading ? null : _toggleLike,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _postStream,
                    initialData: null,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.active &&
                          snapshot.hasData &&
                          snapshot.data != null) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        if (data != null && data.containsKey('likes')) {
                          // Only update if the server data is different from our current state
                          final serverLikes = data['likes'] as int;
                          if (serverLikes != currentLikeCount) {
                            // Use Future.microtask to avoid setState during build
                            Future.microtask(() {
                              if (mounted) {
                                setState(() {
                                  currentLikeCount = serverLikes;
                                });
                              }
                            });
                          }
                        }
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$currentLikeCount',
                          key: ValueKey(currentLikeCount),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(width: 4),
              // Comment button section
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.sharedAxisVertical,
                        child: CommentPage(
                          post: widget.post,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _commentStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.active &&
                          snapshot.hasData) {
                        final commentCount = snapshot.data!.docs.length;
                        if (commentCount != currentCommentCount) {
                          // Use Future.microtask to avoid setState during build
                          Future.microtask(() {
                            if (mounted) {
                              setState(() {
                                currentCommentCount = commentCount;
                              });
                            }
                          });
                        }
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$currentCommentCount',
                          key: ValueKey(currentCommentCount),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(),
              // Bookmark button
              IconButton(
                onPressed: _handleBookmarkTap,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isBookmarkLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          key: ValueKey(isSaved),
                          color: isSaved ? colorScheme.primary : null,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum SnackBarType {
  success,
  error,
}
