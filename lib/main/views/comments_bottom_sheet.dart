import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/post_model.dart';
import '../board/boards/notification_subpage.dart';
import '../profile/profile_user.dart';

class CommentPage extends StatefulWidget {
  final Post post;
  final String currentUserId;

  const CommentPage({
    Key? key,
    required this.post,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage>
    with TickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final FocusNode _focusNode = FocusNode();

  // Caches
  final Map<String, Map<String, String>> _userDataCache = {};
  final Map<String, Map<String, dynamic>> _commentsCache = {};
  final Map<String, List<Map<String, dynamic>>> _repliesCache = {};
  final Map<String, StreamSubscription> _replyStreams = {};
  final NotificationHandler _notificationHandler = NotificationHandler();

  // State variables
  String? _replyingToUserId;
  String? _replyingToCommentId;
  String? _highlightedCommentId;
  String _sortBy = 'timestamp';
  bool _sortAscending = false;
  bool _showCommentInfoCard = true;
  final Map<String, bool> _replyExpandedState = {};
  bool _isPostingComment = false;

  // Controllers
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _animation;

  // Suggested emojis
  final List<String> _suggestedEmojis = [
    '🔥',
    '👍',
    '❤️',
    '😂',
    '🤯',
    '😢',
    '😡',
  ];

  String? _temporaryHighlightedCommentId;
  // late AnimationController _sheetAnimationController;
  late AnimationController _highlightAnimationController;
  // ignore: unused_field
  late Animation<double> _sheetAnimation;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCommentInfoCardState();

    // Initialize highlight animation controller
    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _highlightAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _highlightAnimationController,
      curve: Curves.easeOut,
    ));

    // Listen to highlight animation status
    _highlightAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _temporaryHighlightedCommentId = null;
        });
      }
    });
  }

  void _highlightReferencedComment(String commentId) {
    setState(() {
      _temporaryHighlightedCommentId = commentId;
    });

    _highlightAnimationController.reset();
    _highlightAnimationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Initialize highlight animation controller
    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _highlightAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _highlightAnimationController,
      curve: Curves.easeOut,
    ));

    // Listen to highlight animation status
    _highlightAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _temporaryHighlightedCommentId = null;
        });
      }
    });
  }

  Future<Map<String, String>> _getUserData(String userId) async {
    if (_userDataCache.containsKey(userId)) {
      return _userDataCache[userId]!;
    }

    try {
      final userDoc =
          await _firestore.collection('koleksi_users').doc(userId).get();
      final userData = {
        'username': userDoc.data()?['username']?.toString() ?? 'Unknown User',
        'profile_image_url':
            userDoc.data()?['profile_image_url']?.toString() ?? '',
        'userId': userId,
      };
      _userDataCache[userId] = userData;
      return userData;
    } catch (e) {
      print('Error fetching user data: $e');
      return {
        'username': 'Unknown User',
        'profile_image_url': '',
        'userId': userId,
      };
    }
  }

  Future<void> _loadCommentInfoCardState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCommentInfoCard = prefs.getBool('showCommentInfoCard') ?? true;
    });
  }

  void _postComment() async {
    if (_commentController.text.trim().isEmpty || _isPostingComment) return;

    setState(() => _isPostingComment = true);

    try {
      final commentRef = _firestore.collection('koleksi_comments').doc();
      final userData = await _getUserData(widget.currentUserId);
      final commentData = {
        'postId': widget.post.fotoId,
        'userId': widget.currentUserId,
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'replyToUserId': _replyingToUserId,
        'replyToCommentId': _replyingToCommentId,
        'likes': [],
        'isDeleted': false,
      };

      // Optimistic update
      _addCommentOptimistically({
        'id': commentRef.id,
        ...commentData,
        'timestamp': Timestamp.now(),
      });

      await commentRef.set(commentData);

      // Get post owner data
      final postDoc = await _firestore
          .collection('koleksi_posts')
          .doc(widget.post.fotoId)
          .get();

      final postOwnerId = postDoc.data()?['userId'] as String?;

      // Create notification based on comment type
      if (_replyingToUserId != null) {
        // Notification for reply to comment
        await _notificationHandler.createCommentNotification(
          recipientUserId: _replyingToUserId!,
          senderUserId: widget.currentUserId,
          senderUsername: userData['username'] ?? 'Unknown User',
          postId: widget.post.fotoId,
          commentId: commentRef.id,
          content: _commentController.text.trim(),
          type: NotificationType.replyComment,
        );
      } else if (postOwnerId != null && postOwnerId != widget.currentUserId) {
        // Notification for direct comment to post owner
        await _notificationHandler.createCommentNotification(
          recipientUserId: postOwnerId,
          senderUserId: widget.currentUserId,
          senderUsername: userData['username'] ?? 'Unknown User',
          postId: widget.post.fotoId,
          commentId: commentRef.id,
          content: _commentController.text.trim(),
          type: NotificationType.newComment,
        );
      }

      _commentController.clear();
      setState(() {
        _replyingToUserId = null;
        _replyingToCommentId = null;
        _highlightedCommentId = null;
        _isPostingComment = false;
      });
    } catch (e) {
      print('Error posting comment: $e');
      _showSnackBar('Failed to add comment.', isError: true);
      setState(() => _isPostingComment = false);
    }
  }

  Future<void> _saveCommentInfoCardState(bool showCard) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showCommentInfoCard', showCard);
  }

  void _addCommentOptimistically(Map<String, dynamic> comment) {
    if (comment['replyToCommentId'] != null) {
      final replies = _repliesCache[comment['replyToCommentId']] ?? [];
      replies.add(comment);
      _repliesCache[comment['replyToCommentId']] = replies;
    } else {
      _commentsCache[comment['id']] = comment;
    }
    setState(() {});
  }

  void _toggleLikeComment(String commentId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final commentDoc =
          await _firestore.collection('koleksi_comments').doc(commentId).get();
      final commentData = commentDoc.data();

      if (commentData == null) return;

      final currentLikes = List<String>.from(commentData['likes'] ?? []);
      final isLiked = currentLikes.contains(userId);
      final commentAuthorId = commentData['userId'] as String;

      // Don't create notification if user is liking their own comment
      if (commentAuthorId != userId && !isLiked) {
        final userData = await _getUserData(userId);
        await _notificationHandler.createCommentNotification(
          recipientUserId: commentAuthorId,
          senderUserId: userId,
          senderUsername: userData['username'] ?? 'Unknown User',
          postId: widget.post.fotoId,
          commentId: commentId,
          content: commentData['comment'] ?? '',
          type: NotificationType.commentLike,
        );
      }

      // Update likes
      if (isLiked) {
        currentLikes.remove(userId);
      } else {
        currentLikes.add(userId);
      }

      await _firestore.collection('koleksi_comments').doc(commentId).update({
        'likes': currentLikes,
      });

      // Update local state
      setState(() {
        if (_commentsCache.containsKey(commentId)) {
          _commentsCache[commentId]?['likes'] = currentLikes;
        }
      });
    } catch (e) {
      print('Error toggling like: $e');
      _showSnackBar('Failed to update like', isError: true);
    }
  }

  void _deleteComment(String commentId) async {
    try {
      // Optimistic update
      setState(() {
        if (_commentsCache.containsKey(commentId)) {
          _commentsCache[commentId]?['isDeleted'] = true;
        }
      });

      await _firestore.collection('koleksi_comments').doc(commentId).update({
        'isDeleted': true,
      });

      _showSnackBar('Komentar berhasil dihapus.', isError: false);
    } catch (e) {
      print('Error deleting comment: $e');
      // Rollback optimistic update
      setState(() {
        if (_commentsCache.containsKey(commentId)) {
          _commentsCache[commentId]?['isDeleted'] = false;
        }
      });
      _showSnackBar('Failed to delete comment.', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Baru saja';

    final DateTime date =
        timestamp is Timestamp ? timestamp.toDate() : DateTime.now();

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'hari' : 'hari'} yang lalu';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'jam' : 'jam'} yang lalu';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'menit' : 'menit'} yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData, bool isReply) {
    // Extract core comment data
    final commentId = commentData['id'] ?? commentData['commentId'];
    final userId = commentData['userId'];
    final isDeleted = commentData['isDeleted'] ?? false;

    return FutureBuilder<Map<String, String>>(
      future: _getUserData(userId), // Fetch user data for the comment author
      builder: (context, snapshot) {
        // Provide default values while loading or if data fetch fails
        final userData = snapshot.data ??
            {
              'username': 'Loading...',
              'profile_image_url': '',
              'userId': '',
            };

        // Check if the user is the current user or post author
        final isCurrentUser = userId == widget.currentUserId;
        final isPostAuthor = userId == widget.post.userId;

        return AnimatedBuilder(
          animation: _highlightAnimation,
          builder: (context, child) {
            // Handle comment highlighting animation
            final isHighlighted = _temporaryHighlightedCommentId == commentId;
            final highlightColor = isHighlighted
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(_highlightAnimation.value)
                : Colors.transparent;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              // Adjust margin based on whether this is a reply
              margin: EdgeInsets.only(
                left: isReply ? 40.0 : 8.0,
                right: 8.0,
                bottom: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show "Replying to" text if this is a reply
                  if (commentData['replyToUserId'] != null)
                    _buildReplyingToWidget(
                      commentData['replyToUserId'],
                      replyToCommentId: commentData['replyToCommentId'],
                    ),

                  // Main comment content with gesture detection
                  GestureDetector(
                    onTap: () {
                      // Toggle replies for main comments and handle reply action
                      if (!isReply) {
                        setState(() {
                          _replyExpandedState[commentId] =
                              !(_replyExpandedState[commentId] ?? false);
                        });
                      }
                      _replyToComment(userId, commentId);
                    },
                    onLongPress: () =>
                        _handleLongPress(userId, commentId, isDeleted),
                    child: Card(
                      elevation: 0,
                      color: _highlightedCommentId == commentId
                          ? Theme.of(context).colorScheme.primaryContainer
                          : highlightColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User avatar with badges
                            Stack(
                              children: [
                                _buildUserAvatar(userData),
                                if (isCurrentUser || isPostAuthor)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isCurrentUser
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        isCurrentUser
                                            ? Icons.person
                                            : Icons.star,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8.0),

                            // Comment content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Username and timestamp
                                  Row(
                                    children: [
                                      Flexible(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    userData['username'] ?? '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              if (isCurrentUser)
                                                TextSpan(
                                                  text: ' (Anda)',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                              if (isPostAuthor)
                                                TextSpan(
                                                  text: ' (Pemilik Postingan)',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(
                                            commentData['timestamp']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Comment text
                                  if (isDeleted)
                                    const Text(
                                      'Komentar ini sudah dihapus',
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic),
                                    )
                                  else
                                    Text(
                                      commentData['comment'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8.0),

                            // Like button
                            _buildLikeButton(
                                commentId, commentData['likes'] ?? []),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Show replies section for main comments only
                  if (!isReply) _buildRepliesSection(commentId),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserAvatar(Map<String, String> userData) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UserProfilePage(userId: userData['userId'] ?? ''),
          ),
        );
      },
      child: CircleAvatar(
        backgroundImage: userData['profile_image_url']?.isNotEmpty ?? false
            ? NetworkImage(userData['profile_image_url']!)
            : null,
        child: userData['profile_image_url']?.isEmpty ?? true
            ? Text(userData['username']?[0].toUpperCase() ?? '?')
            : null,
      ),
    );
  }

  Widget _buildLikeButton(String commentId, List<dynamic> likes) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => _toggleLikeComment(commentId),
          icon: Icon(
            likes.contains(widget.currentUserId)
                ? Icons.favorite
                : Icons.favorite_border,
            color: likes.contains(widget.currentUserId)
                ? Theme.of(context).colorScheme.primary
                : null,
            size: 20,
          ),
        ),
        Text(
          '${likes.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReplyingToWidget(String replyingToUserId,
      {required String replyToCommentId}) {
    return FutureBuilder<Map<String, String>>(
      future: _getUserData(replyingToUserId),
      builder: (context, snapshot) {
        final username = snapshot.data?['username'] ?? 'Unknown User';
        return Padding(
          padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
          child: GestureDetector(
            onTap: () {
              _highlightReferencedComment(replyToCommentId);
            },
            child: Text(
              'Membalas $username',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<int> _getTotalRepliesCount(String commentId) async {
    int totalCount = 0;

    // Get direct replies
    final directReplies = await _firestore
        .collection('koleksi_comments')
        .where('postId', isEqualTo: widget.post.fotoId)
        .where('replyToCommentId', isEqualTo: commentId)
        .get();

    totalCount += directReplies.docs.length;

    // Recursively count nested replies
    for (var reply in directReplies.docs) {
      totalCount += await _getTotalRepliesCount(reply.id);
    }

    return totalCount;
  }

  Widget _buildReplyCount(String commentId) {
    return FutureBuilder<int>(
      future: _getTotalRepliesCount(commentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Tampilkan balasan');
        }

        final totalReplies = snapshot.data!;

        return Text(
          _replyExpandedState[commentId] ?? false
              ? 'Sembunyikan balasan'
              : 'Tampilkan $totalReplies balasan',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildRepliesSection(String commentId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('koleksi_comments')
          .where('postId', isEqualTo: widget.post.fotoId)
          .where('replyToCommentId', isEqualTo: commentId)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, repliesSnapshot) {
        if (repliesSnapshot.connectionState == ConnectionState.waiting &&
            !repliesSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final replies = repliesSnapshot.data?.docs ?? [];
        if (replies.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply count button
            Container(
              margin: const EdgeInsets.only(left: 60, top: 4, bottom: 4),
              child: InkWell(
                onTap: () => setState(() {
                  _replyExpandedState[commentId] =
                      !(_replyExpandedState[commentId] ?? false);
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReplyCount(commentId),
                    Icon(
                      _replyExpandedState[commentId] ?? false
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Replies container with ClipRect for proper animation
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment:
                    Alignment.topCenter, // Ensure animation starts from top
                child: Container(
                  child: _replyExpandedState[commentId] ?? false
                      ? Column(
                          children: replies.map((replyDoc) {
                            final replyData = {
                              'id': replyDoc.id,
                              ...replyDoc.data(),
                            };
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommentItem(replyData, true),
                                _buildNestedReplies(replyDoc.id),
                              ],
                            );
                          }).toList(),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNestedReplies(String replyId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('koleksi_comments')
          .where('postId', isEqualTo: widget.post.fotoId)
          .where('replyToCommentId', isEqualTo: replyId)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, nestedRepliesSnapshot) {
        if (!nestedRepliesSnapshot.hasData ||
            nestedRepliesSnapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final nestedReplies = nestedRepliesSnapshot.data!.docs;
        return ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              children: nestedReplies.map((nestedReplyDoc) {
                final nestedReplyData = {
                  'id': nestedReplyDoc.id,
                  ...nestedReplyDoc.data(),
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommentItem(nestedReplyData, true),
                    _buildNestedReplies(nestedReplyDoc.id),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _handleLongPress(String userId, String commentId, bool isDeleted) {
    if (userId == widget.currentUserId && !isDeleted) {
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
                  'Hapus Komentar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Apakah Anda yakin ingin menghapus komentar ini?',
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
                      onPressed: () => Navigator.of(context).pop(),
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
                        _deleteComment(commentId);
                        Navigator.of(context).pop();
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

  void _replyToComment(String userId, String commentId) {
    setState(() {
      _replyingToUserId = userId;
      _replyingToCommentId = commentId;
      _highlightedCommentId = commentId;
    });
    _focusNode.requestFocus();
  }

  Widget _buildCommentsList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('koleksi_comments')
            .where('postId', isEqualTo: widget.post.fotoId)
            .where('replyToCommentId', isNull: true)
            .orderBy(_sortBy, descending: !_sortAscending)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final comments = snapshot.data?.docs ?? [];

          if (comments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada komentar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jadilah yang pertama memberikan komentar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final commentDoc = comments[index];
              final commentData = {
                'id': commentDoc.id,
                ...commentDoc.data(),
              };
              return _buildCommentItem(commentData, false);
            },
          );
        },
      ),
    );
  }

  // Widget _buildSortOptions() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         StreamBuilder<QuerySnapshot>(
  //           stream: _firestore
  //               .collection('koleksi_comments')
  //               .where('postId', isEqualTo: widget.post.fotoId)
  //               .snapshots(),
  //           builder: (context, snapshot) {
  //             final commentCount = snapshot.data?.docs.length ?? 0;
  //             return Text(
  //               'Komentar ($commentCount)',
  //               style: Theme.of(context).textTheme.bodyMedium,
  //             );
  //           },
  //         ),
  //         PopupMenuButton<String>(
  //           onSelected: (String value) {
  //             setState(() {
  //               if (value == 'likes') {
  //                 _sortBy = 'likes';
  //                 _sortAscending = false;
  //               } else if (value == 'newest') {
  //                 _sortBy = 'timestamp';
  //                 _sortAscending = false;
  //               } else {
  //                 _sortBy = 'timestamp';
  //                 _sortAscending = true;
  //               }
  //             });
  //           },
  //           itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
  //             const PopupMenuItem<String>(
  //               value: 'newest',
  //               child: Text('Terbaru'),
  //             ),
  //             const PopupMenuItem<String>(
  //               value: 'oldest',
  //               child: Text('Terlama'),
  //             ),
  //             const PopupMenuItem<String>(
  //               value: 'likes',
  //               child: Text('Populer'),
  //             ),
  //           ],
  //           child: Row(
  //             children: [
  //               Text(_sortBy == 'likes'
  //                   ? 'Populer'
  //                   : (_sortAscending ? 'Terlama' : 'Terbaru')),
  //               const Icon(Icons.arrow_drop_down),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCommentInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding:
          const EdgeInsets.only(left: 8.0, right: 8.0, top: 12.0, bottom: 16.0),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingToUserId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 8),
                  child: Row(
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: _getUserData(_replyingToUserId!),
                        builder: (context, snapshot) {
                          final username =
                              snapshot.data?['username'] ?? 'Unknown User';
                          return Text(
                            'Membalas $username',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _replyingToUserId = null;
                            _replyingToCommentId = null;
                            _highlightedCommentId = null;
                            _commentController.clear();
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: _suggestedEmojis.map((emoji) {
                    return InkWell(
                      onTap: () {
                        final currentText = _commentController.text;
                        final selection = _commentController.selection;
                        final start = selection.start >= 0
                            ? selection.start
                            : currentText.length;
                        final end = selection.end >= 0
                            ? selection.end
                            : currentText.length;

                        final newText =
                            currentText.replaceRange(start, end, emoji);
                        _commentController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                              offset: start + emoji.length),
                        );
                        _postComment();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      decoration: InputDecoration(
                        hintText: _replyingToUserId != null
                            ? 'Balas Komentar ...'
                            : 'Tambah Komentar ...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedBuilder(
                      animation: _commentController,
                      builder: (context, child) {
                        final bool hasText = _commentController.text.isNotEmpty;
                        return IconButton(
                          onPressed: hasText && !_isPostingComment
                              ? _postComment
                              : null,
                          style: IconButton.styleFrom(
                            backgroundColor: hasText
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceVariant,
                            padding: const EdgeInsets.all(8),
                          ),
                          icon: _isPostingComment
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: hasText
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.5),
                                  size: 24,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentInfoCard() {
    if (!_showCommentInfoCard) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tips',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _showCommentInfoCard = false;
                      _saveCommentInfoCardState(false);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              Icons.person_rounded,
              'Klik foto profil untuk membuka profil pengguna.',
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.reply_rounded,
              'Klik komentar untuk membalas.',
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.delete_rounded,
              'Tekan lama komentar Anda untuk menghapus.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  // Widget _buildSheetHandle() {
  //   return Padding(
  //     padding: const EdgeInsets.all(8.0),
  //     child: Container(
  //       width: 40,
  //       height: 5,
  //       decoration: BoxDecoration(
  //         color: Theme.of(context).colorScheme.onSurfaceVariant,
  //         borderRadius: BorderRadius.circular(10),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('koleksi_comments')
              .where('postId', isEqualTo: widget.post.fotoId)
              .snapshots(),
          builder: (context, snapshot) {
            final commentCount = snapshot.data?.docs.length ?? 0;
            return Text(
              'Komentar ($commentCount)',
              style: Theme.of(context).textTheme.titleLarge,
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                if (value == 'likes') {
                  _sortBy = 'likes';
                  _sortAscending = false;
                } else if (value == 'newest') {
                  _sortBy = 'timestamp';
                  _sortAscending = false;
                } else {
                  _sortBy = 'timestamp';
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'newest',
                child: Text('Terbaru'),
              ),
              const PopupMenuItem<String>(
                value: 'oldest',
                child: Text('Terlama'),
              ),
              const PopupMenuItem<String>(
                value: 'likes',
                child: Text('Populer'),
              ),
            ],
            icon: Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCommentInfoCard(),
          _buildCommentsList(),
          _buildCommentInput(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _highlightAnimationController.dispose();
    _replyStreams.values.forEach((subscription) => subscription.cancel());
    super.dispose();
  }
}
