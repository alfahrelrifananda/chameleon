import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
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
  final _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final _postService = PostService();
  late Stream<DocumentSnapshot> _postStream;
  late Stream<QuerySnapshot> _bookmarkStream;

  // Add NotificationHandler instance
  final NotificationHandler _notificationHandler = NotificationHandler();

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _initializeStreams();
  }

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
  }

  Future<void> _checkIfLiked() async {
    try {
      final likeDoc = await _firestore
          .collection('koleksi_likes')
          .doc('${widget.currentUserId}_${widget.post.fotoId}')
          .get();

      if (mounted) {
        setState(() {
          isLiked = likeDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final previousState = isLiked;
    setState(() => isLiked = !isLiked); // Optimistic update

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

        final currentLikes = postDoc.data()?['likes'] ?? 0;
        final postOwnerId = postDoc.data()?['userId'] as String?;

        if (likeDoc.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': currentLikes - 1,
          });
        } else {
          transaction.set(likeRef, {
            'userId': widget.currentUserId,
            'fotoId': widget.post.fotoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likes': currentLikes + 1,
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
        setState(() => isLiked = previousState); // Rollback on error
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
                    builder: (context, snapshot) {
                      final likes = snapshot.data?.get('likes') as int? ??
                          widget.post.likes ??
                          0;
                      return Text(
                        '$likes',
                        style: Theme.of(context).textTheme.bodyMedium,
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
                    stream: _firestore
                        .collection('koleksi_comments')
                        .where('postId', isEqualTo: widget.post.fotoId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data?.docs.length ?? 0;
                      return Text(
                        '$commentCount',
                        style: Theme.of(context).textTheme.bodyMedium,
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
