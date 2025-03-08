import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:page_transition/page_transition.dart';
// import '../grid/post_info.dart';
// import '../user-profile-page.dart';

// Models
class NotificationItem {
  final String id;
  final String username;
  final String content;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? relatedContent;
  final String? userImage;
  final String? postImage;
  final String senderUserId; // Add this field

  NotificationItem({
    required this.id,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.relatedContent,
    this.userImage,
    this.postImage,
    required this.senderUserId, // Add this parameter
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String content = data['content'] ?? '';

    // Set default content based on notification type
    if (content.isEmpty) {
      switch (data['type']) {
        case 'follow':
          content = 'Mengikuti anda';
          break;
        case 'new_post':
          content = 'Mengunggah postingan baru';
          break;
      }
    }

    return NotificationItem(
      id: doc.id,
      username: data['senderUsername'] ?? 'Unknown',
      content: content,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: _getNotificationTypeFromString(data['type'] ?? 'newPost'),
      isRead: data['read'] ?? false,
      relatedContent: data['postId'],
      userImage: data['senderImage'],
      postImage: data['postImage'],
      senderUserId: data['senderUserId'] ?? '', // Add this field
    );
  }

  static NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'new_comment':
        return NotificationType.newComment;
      case 'reply_comment':
        return NotificationType.replyComment;
      case 'comment_like':
        return NotificationType.commentLike;
      case 'post_like':
        return NotificationType.postLike;
      case 'new_post':
        return NotificationType.newPost;
      case 'message':
        return NotificationType.message;
      case 'follow':
        return NotificationType.follow;
      default:
        return NotificationType.newPost;
    }
  }
}

enum NotificationType {
  newComment,
  replyComment,
  commentLike,
  postLike,
  newPost,
  message,
  follow,
}

// Add enum for filter types
enum NotificationFilter { all, unread }

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add filter state
  NotificationFilter _currentFilter = NotificationFilter.all;

  // Get filtered stream
  Stream<QuerySnapshot> _getFilteredNotifications() {
    var query = _firestore
        .collection('koleksi_users')
        .doc(_auth.currentUser?.uid)
        .collection('koleksi_notifications')
        .orderBy('timestamp', descending: true);

    switch (_currentFilter) {
      case NotificationFilter.unread:
        query = query.where('read', isEqualTo: false);
        break;
      case NotificationFilter.all:
        // No additional filtering needed
        break;
    }

    return query.snapshots();
  }

  void _markAsRead(String id) async {
    try {
      await _firestore
          .collection('koleksi_users')
          .doc(_auth.currentUser?.uid)
          .collection('koleksi_notifications')
          .doc(id)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _deleteNotification(String id) async {
    try {
      await _firestore
          .collection('koleksi_users')
          .doc(_auth.currentUser?.uid)
          .collection('koleksi_notifications')
          .doc(id)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  String _getFilterTitle() {
    switch (_currentFilter) {
      case NotificationFilter.all:
        return 'Semua Aktivitas';
      case NotificationFilter.unread:
        return 'Belum Dibaca';
    }
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Notifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                leading: Icon(Icons.all_inbox,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Semua'),
                selected: _currentFilter == NotificationFilter.all,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.2),
                onTap: () {
                  setState(() {
                    _currentFilter = NotificationFilter.all;
                  });
                  Navigator.pop(context);
                },
                selectedColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                leading: Icon(Icons.mark_email_unread,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Belum Dibaca'),
                selected: _currentFilter == NotificationFilter.unread,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.2),
                onTap: () {
                  setState(() {
                    _currentFilter = NotificationFilter.unread;
                  });
                  Navigator.pop(context);
                },
                selectedColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationItem notification) async {
    // Mark as read first
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.follow:
        // Navigate to user profile
        // Navigator.push(
        //   context,
        //   PageTransition(
        //     type: PageTransitionType.rightToLeft,
        //     child: UserProfilePage(userId: notification.senderUserId),
        //   ),
        // );
        break;
      case NotificationType.newPost:
      case NotificationType.postLike:
        // Navigate to post if we have a postId
        if (notification.relatedContent != null) {
          // Navigator.push(
          //   context,
          //   PageTransition(
          //     type: PageTransitionType.rightToLeft,
          //     child: PostInfo(postId: notification.relatedContent!),
          //   ),
          // );
        }
        break;
      case NotificationType.newComment:
      case NotificationType.replyComment:
      case NotificationType.commentLike:
        // Navigate to post with comment section open if we have a postId
        if (notification.relatedContent != null) {
          // Navigator.push(
          //   context,
          //   PageTransition(
          //     type: PageTransitionType.rightToLeft,
          //     child: PostInfo(
          //       postId: notification.relatedContent!,
          //       openComments: true,
          //     ),
          //   ),
          // );
        }
        break;
      case NotificationType.message:
        // Handle message navigation if needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getFilterTitle()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterOptions(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error in StreamBuilder: ${snapshot.error}');
            print('Stack trace: ${snapshot.stackTrace}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  NotificationItem.fromFirestore(notifications[index]);
              return _SwipeableNotificationCard(
                key: ValueKey(notification.id),
                notification: notification,
                colorScheme: colorScheme,
                onRead: () => _handleRead(notification),
                onDelete: () => _handleDelete(notification),
                onTap: () => _handleNotificationTap(notification),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    String emptyStateMessage;
    IconData emptyStateIcon;

    switch (_currentFilter) {
      case NotificationFilter.unread:
        emptyStateMessage = 'Tidak ada notifikasi yang belum dibaca';
        emptyStateIcon = Icons.mark_email_read;
        break;
      case NotificationFilter.all:
        emptyStateMessage = 'Belum ada notifikasi';
        emptyStateIcon = Icons.notifications_none;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyStateIcon,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            emptyStateMessage,
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRead(NotificationItem notification) {
    _markAsRead(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifikasi ditandai telah dibaca'),
        action: SnackBarAction(
          label: 'Batalkan',
          onPressed: () {
            // Implement undo logic
          },
        ),
      ),
    );
  }

  void _handleDelete(NotificationItem notification) {
    // Store the notification data before deleting
    final deletedNotification = notification;

    // Delete the notification
    _deleteNotification(notification.id);

    // Show SnackBar with undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifikasi dihapus'),
        action: SnackBarAction(
          label: 'Batalkan',
          onPressed: () {
            // Restore the deleted notification
            _restoreNotification(deletedNotification);
          },
        ),
      ),
    );
  }

// Add this method to restore deleted notifications
  void _restoreNotification(NotificationItem notification) async {
    try {
      // Recreate the notification in Firestore with the same data
      await _firestore
          .collection('koleksi_users')
          .doc(_auth.currentUser?.uid)
          .collection('koleksi_notifications')
          .doc(notification.id)
          .set({
        'senderUsername': notification.username,
        'content': notification.content,
        'timestamp': Timestamp.fromDate(notification.timestamp),
        'type': _getNotificationTypeString(notification.type),
        'read': notification.isRead,
        'postId': notification.relatedContent,
        'senderImage': notification.userImage,
        'postImage': notification.postImage,
        'senderUserId': notification.senderUserId,
      });
    } catch (e) {
      print('Error restoring notification: $e');
    }
  }

// Helper method to convert NotificationType to string
  String _getNotificationTypeString(NotificationType type) {
    switch (type) {
      case NotificationType.newComment:
        return 'new_comment';
      case NotificationType.replyComment:
        return 'reply_comment';
      case NotificationType.commentLike:
        return 'comment_like';
      case NotificationType.postLike:
        return 'post_like';
      case NotificationType.newPost:
        return 'new_post';
      case NotificationType.message:
        return 'message';
      case NotificationType.follow:
        return 'follow';
      // ignore: unreachable_switch_default
      default:
        return 'new_post';
    }
  }
}

class _SwipeableNotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final ColorScheme colorScheme;
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SwipeableNotificationCard({
    super.key,
    required this.notification,
    required this.colorScheme,
    required this.onRead,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Dismissible(
        key: Key(notification.id),
        background: _buildSwipeBackground(
          color: colorScheme.errorContainer,
          icon: Icons.delete,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _buildSwipeBackground(
          color: colorScheme.errorContainer,
          icon: Icons.delete,
          alignment: Alignment.centerRight,
        ),
        onDismissed: (direction) {
          onDelete();
        },
        child: Card(
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.zero,
          color: notification.isRead
              ? colorScheme.surface
              : colorScheme.primaryContainer.withOpacity(0.1),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              notification.username,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NotificationIcon(type: notification.type),
                            if (!notification.isRead) ...[
                              const Spacer(),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(notification.content),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        if (notification.postImage != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: notification.postImage!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: notification.userImage != null
          ? CachedNetworkImageProvider(notification.userImage!)
          : null,
      child: notification.userImage == null
          ? Text(
              notification.username[0].toUpperCase(),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(
            icon,
            color: alignment == Alignment.centerLeft
                ? colorScheme.primary
                : colorScheme.error,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${difference.inDays} hari yang lalu';
    }
  }
}

class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.newComment:
        icon = Icons.comment;
        color = colorScheme.primary;
        break;
      case NotificationType.replyComment:
        icon = Icons.reply;
        color = colorScheme.secondary;
        break;
      case NotificationType.commentLike:
        icon = Icons.favorite;
        color = colorScheme.error;
        break;
      case NotificationType.postLike:
        icon = Icons.thumb_up;
        color = colorScheme.error;
        break;
      case NotificationType.newPost:
        icon = Icons.post_add;
        color = colorScheme.tertiary;
        break;
      case NotificationType.message:
        icon = Icons.message;
        color = colorScheme.primary;
        break;
      case NotificationType.follow:
        icon = Icons.person_add;
        color = colorScheme.secondary;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }
}

class NotificationHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createCommentNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderUsername,
    String? senderImage, // Make this optional
    required String postId,
    required String commentId,
    required String content,
    required NotificationType type,
  }) async {
    try {
      // Fetch the sender's profile image if not provided
      String? userImage = senderImage;
      if (userImage == null) {
        final userDoc = await _firestore
            .collection('koleksi_users')
            .doc(senderUserId)
            .get();

        if (userDoc.exists) {
          userImage = userDoc.data()?['profile_image_url'];
        }
      }

      if (recipientUserId == senderUserId) return;

      // Create the notification document
      await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(recipientUserId) // Use the recipient's user ID
          .collection('koleksi_notifications')
          .add({
        'recipientUserId': recipientUserId,
        'senderId': senderUserId,
        'senderImage': userImage, // Use the fetched image
        'senderUsername': senderUsername,
        'postId': postId, // Can be empty for message notifications
        'commentId':
            commentId, // For messages, this would contain the message ID
        'content': type == NotificationType.message
            ? 'Mengirim pesan: ${_truncateContent(content)}'
            : content,
        'type': _getNotificationTypeString(type),
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  String _truncateContent(String content) {
    const maxLength = 50;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  String _getNotificationTypeString(NotificationType type) {
    switch (type) {
      case NotificationType.newComment:
        return 'new_comment';
      case NotificationType.replyComment:
        return 'reply_comment';
      case NotificationType.commentLike:
        return 'comment_like';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.newPost:
        return 'new_post';
      default:
        return 'new_comment';
    }
  }
}
