import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../pages/post_model.dart';
import '../../board/boards/notification_subpage.dart';

class LikeCounter extends StatefulWidget {
  const LikeCounter({
    Key? key,
    required this.post,
  }) : super(key: key);

  final Post post;

  @override
  State<LikeCounter> createState() => _LikeCounterState();
}

class _LikeCounterState extends State<LikeCounter> {
  bool isLiked = false;
  bool isLoading = false;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final NotificationHandler _notificationHandler = NotificationHandler();
  late Stream<DocumentSnapshot> _postStream;

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser != null) {
      _checkIfLiked();
    }
    _postStream = _firestore
        .collection('koleksi_posts')
        .doc(widget.post.fotoId)
        .snapshots();
  }

  Future<void> _checkIfLiked() async {
    try {
      final likeDoc = await _firestore
          .collection('koleksi_likes')
          .doc('${_auth.currentUser!.uid}_${widget.post.fotoId}')
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
    if (_auth.currentUser == null || isLoading) return;

    setState(() {
      isLoading = true;
    });

    final previousState = isLiked;
    setState(() => isLiked = !isLiked); // Optimistic update

    try {
      await _firestore.runTransaction((transaction) async {
        final likeRef = _firestore
            .collection('koleksi_likes')
            .doc('${_auth.currentUser!.uid}_${widget.post.fotoId}');
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
          // Unlike post
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': currentLikes - 1,
          });
        } else {
          // Like post
          transaction.set(likeRef, {
            'userId': _auth.currentUser!.uid,
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
          if (postOwnerId != null && postOwnerId != _auth.currentUser!.uid) {
            // Get current user's data for notification
            final currentUserDoc = await _firestore
                .collection('koleksi_users')
                .doc(_auth.currentUser!.uid)
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
                senderUserId: _auth.currentUser!.uid,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isLiked ? 'unlike' : 'like'} the post'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

  String _formatLikeCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _auth.currentUser;

    return InkWell(
      onTap: currentUser != null && !isLoading ? _toggleLike : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      size: 16,
                      color: isLiked
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: 4),
            StreamBuilder<DocumentSnapshot>(
              stream: _postStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    _formatLikeCount(widget.post.likes ?? 0),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  );
                }

                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final likes = data?['likes'] ?? widget.post.likes ?? 0;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _formatLikeCount(likes),
                    key: ValueKey(likes),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
