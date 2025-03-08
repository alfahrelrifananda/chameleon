import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../board/boards/notification_subpage.dart';
import '../../profile/profile_user.dart';

class ChatPage extends StatefulWidget {
  final String recipientUserId;

  const ChatPage({Key? key, required this.recipientUserId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  bool _isLoading = true;
  Map<String, dynamic>? _recipientData;
  bool _isKeyboardVisible = false;
  bool _initialLoadDone = false;

  late AnimationController _fadeAnimationController;
  // ignore: unused_field
  late Animation<double> _fadeAnimation;

  late Stream<QuerySnapshot> _messageStream;
  List<QueryDocumentSnapshot> _messages = [];

  // Tambahkan variabel untuk menyimpan pesan yang sedang dibalas
  Map<String, dynamic>? _replyingTo;
  final NotificationHandler _notificationHandler = NotificationHandler();

  final List<String> _suggestions = [
    'Hai, apa kabar?',
    'Boleh kenalan?',
    'Punya hobi apa?',
    'Lagi sibuk apa?',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _getCurrentUserId();
    _getRecipientData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
    WidgetsBinding.instance.addObserver(this);
    _initMessageStream();
  }

  void _initMessageStream() {
    _messageStream = _getMessageStream();
    _messageStream.listen((QuerySnapshot snapshot) {
      if (mounted) {
        setState(() {
          _messages = snapshot.docs;
          _initialLoadDone = true;
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final keyboardVisible =
        WidgetsBinding.instance.window.viewInsets.bottom > 0;
    if (mounted && _isKeyboardVisible != keyboardVisible) {
      setState(() {
        _isKeyboardVisible = keyboardVisible;
      });
    }
  }

  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    _fadeAnimationController.forward();
  }

  Future<void> _getCurrentUserId() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _isLoading = false;
      });
    } else {
      print('No authenticated user found');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getRecipientData() async {
    try {
      DocumentSnapshot recipientDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(widget.recipientUserId)
          .get();

      if (recipientDoc.exists) {
        setState(() {
          _recipientData = recipientDoc.data() as Map<String, dynamic>;
        });
      } else {
        print('Recipient user document does not exist');
      }
    } catch (e) {
      print('Error fetching recipient data: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final messages = await FirebaseFirestore.instance
          .collection('koleksi_messages')
          .where('senderId', isEqualTo: widget.recipientUserId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty && _currentUserId != null) {
      try {
        final List<String> participantIds = [
          _currentUserId!,
          widget.recipientUserId
        ]..sort();
        final String chatId = participantIds.join('_');

        final messageData = {
          'senderId': _currentUserId,
          'receiverId': widget.recipientUserId,
          'message': _messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'chatId': chatId,
          'participants': participantIds,
          'read': false,
        };

        // Add reply information if needed
        if (_replyingTo != null) {
          messageData['replyTo'] = {
            'id': _replyingTo!['id'],
            'message': _replyingTo!['message'],
            'senderId': _replyingTo!['senderId'],
          };
        }

        // Send the message
        final messageRef = await FirebaseFirestore.instance
            .collection('koleksi_messages')
            .add(messageData);

        // Send push notification

        // Also create in-app notification
        await _createInAppNotification(messageRef.id);

        _messageController.clear();
        setState(() {
          _replyingTo = null;
        });
        _scrollToBottom();
      } catch (e) {
        print('Error sending message: $e');
        _showErrorSnackBar('Failed to send message. Please try again.');
      }
    }
  }

  Widget _buildSuggestionCards(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((suggestion) {
          return Card(
            color: colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                _messageController.text = suggestion;
                _sendMessage();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  suggestion,
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWelcomeMessage(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Mulai percakapan dengan ${_recipientData?['username'] ?? 'pengguna ini'}',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildSuggestionCards(colorScheme),
        ],
      ),
    );
  }

  // // Method to navigate to the user profile to follow
  // void _navigateToUserProfile() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => UserProfilePage(
  //         userId: widget.recipientUserId,
  //       ),
  //     ),
  //   ).then((_) {
  //     // Refresh follow status when returning from profile page
  //     _checkIfFollowing();
  //   });
  // }

  Future<void> _createInAppNotification(String messageId) async {
    try {
      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(_currentUserId)
          .get();

      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data()!;
        final username = userData['username'] ?? 'Unknown User';

        // Use NotificationHandler to create notification
        await _notificationHandler.createCommentNotification(
          recipientUserId: widget.recipientUserId,
          senderUserId: _currentUserId!,
          senderUsername: username,
          postId: '', // Empty for message notifications
          commentId: messageId, // Using messageId as commentId
          content: _messageController.text.trim(),
          type: NotificationType.message,
        );
      }
    } catch (e) {
      print('Error creating message notification: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Stream<QuerySnapshot> _getMessageStream() {
    final List<String> participantIds = [
      _currentUserId!,
      widget.recipientUserId
    ]..sort();
    final String chatId = participantIds.join('_');

    return FirebaseFirestore.instance
        .collection('koleksi_messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // Tambahkan fungsi untuk memilih pesan yang akan dibalas
  void _replyToMessage(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = {
        'id': message['id'],
        'message': message['message'],
        'senderId': message['senderId'],
      };
    });
  }

  // Tambahkan fungsi untuk membatalkan balasan
  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
            child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: _buildAppBarTitle(Theme.of(context).colorScheme,
            Theme.of(context).textTheme, context, widget.recipientUserId),
        scrolledUnderElevation: 0, // Remove elevation when scrolled under
        elevation: 0, // No default elevation
        centerTitle: true,
        backgroundColor:
            Theme.of(context).colorScheme.surface, // Clean surface color
        foregroundColor:
            Theme.of(context).colorScheme.onSurface, // Proper contrast
        surfaceTintColor: Colors.transparent, // Remove surface tint
        // Remove gradient and box shadow by not including flexibleSpace and shadowColor
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Let foregroundColor handle the icon color automatically
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildMessagesList(colorScheme, textTheme),
            ),
            // _isFollowing
            ChatInputWidget(
              messageController: _messageController,
              replyingTo: _replyingTo,
              onCancelReply: _cancelReply,
              onSendMessage: _sendMessage,
              isKeyboardVisible: _isKeyboardVisible,
            )
            // : _buildFollowRequiredWidget(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  // Widget to show when user is not following the recipient
  // Widget _buildFollowRequiredWidget(
  //     ColorScheme colorScheme, TextTheme textTheme) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  //     decoration: BoxDecoration(
  //       color: colorScheme.surfaceVariant.withOpacity(0.5),
  //       border: Border(
  //         top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
  //       ),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Text(
  //           'Anda harus mengikuti pengguna ini untuk dapat berinteraksi',
  //           textAlign: TextAlign.center,
  //           style: textTheme.bodyMedium?.copyWith(
  //             color: colorScheme.onSurfaceVariant,
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         FilledButton(
  //           onPressed: _navigateToUserProfile,
  //           style: FilledButton.styleFrom(
  //             backgroundColor: colorScheme.primary,
  //             foregroundColor: colorScheme.onPrimary,
  //             minimumSize: const Size(double.infinity, 48),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //           child: const Text('Kunjungi Profil untuk Mengikuti'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildAppBarTitle(ColorScheme colorScheme, TextTheme textTheme,
      BuildContext context, String recipientUserId) {
    return InkWell(
      // Wrap the entire Row with InkWell
      onTap: () {
        // ignore: unnecessary_null_comparison
        if (recipientUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                userId: recipientUserId,
              ),
            ),
          );
        } else {
          // Debug print
        }
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: _recipientData?['profile_image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: _recipientData!['profile_image_url'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.person,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: colorScheme.onPrimaryContainer,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recipientData?['username'] ?? 'Chat',
                  style: textTheme.titleMedium
                      ?.copyWith(color: colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_recipientData?['Status'] != null)
                  Text(
                    _recipientData!['Status'],
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ColorScheme colorScheme, TextTheme textTheme) {
    if (!_initialLoadDone) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
    }

    if (_messages.isEmpty) {
      return _buildWelcomeMessage(colorScheme, textTheme);
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      itemBuilder: (context, index) {
        final message = _messages[index].data() as Map<String, dynamic>;
        final isCurrentUser = message['senderId'] == _currentUserId;
        final timestamp = message['timestamp'] as Timestamp?;

        return _buildMessageBubble(
          message: message['message'],
          isCurrentUser: isCurrentUser,
          timestamp: timestamp,
          colorScheme: colorScheme,
          textTheme: textTheme,
          replyTo: message['replyTo'],
          fullMessage: message,
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isCurrentUser,
    required Timestamp? timestamp,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    Map<String, dynamic>? replyTo,
    required Map<String, dynamic> fullMessage,
  }) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: ValueKey(
            fullMessage['timestamp']), // Gunakan timestamp sebagai unique key
        direction: isCurrentUser
            ? DismissDirection.endToStart
            : DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.2,
          DismissDirection.endToStart: 0.2,
        },
        confirmDismiss: (direction) async {
          _replyToMessage(fullMessage);
          return false; // Kembalikan false agar widget tidak benar-benar di-dismiss
        },
        background: Container(
          padding: EdgeInsets.only(
            left: isCurrentUser ? 0 : 16,
            right: isCurrentUser ? 16 : 0,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment:
              isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Icon(
            Icons.reply_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyTo != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Membalas: ${replyTo['message']}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isCurrentUser
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: textTheme.bodySmall?.copyWith(
                        color: isCurrentUser
                            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : colorScheme.onSecondaryContainer.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays == 0) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }
}

class ChatInputWidget extends StatefulWidget {
  final TextEditingController messageController;
  final Map<String, dynamic>? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSendMessage;
  final bool isKeyboardVisible;

  const ChatInputWidget({
    Key? key,
    required this.messageController,
    required this.replyingTo,
    required this.onCancelReply,
    required this.onSendMessage,
    required this.isKeyboardVisible,
  }) : super(key: key);

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _replyAnimationController;
  late Animation<double> _replyHeightAnimation;

  @override
  void initState() {
    super.initState();
    _replyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _replyHeightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _replyAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Animate in if there's a reply at startup
    if (widget.replyingTo != null) {
      _replyAnimationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when reply status changes
    if (oldWidget.replyingTo == null && widget.replyingTo != null) {
      _replyAnimationController.forward();
    } else if (oldWidget.replyingTo != null && widget.replyingTo == null) {
      _replyAnimationController.reverse();
    }
  }

  @override
  void dispose() {
    _replyAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 12.0,
        bottom: widget.isKeyboardVisible ? 0 : 16.0,
      ),
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            AnimatedBuilder(
              animation: _replyAnimationController,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    heightFactor: _replyHeightAnimation.value,
                    child: child,
                  ),
                );
              },
              child: widget.replyingTo != null
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Membalas Pesan',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.replyingTo!['message'],
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onCancelReply,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Input field
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji button (could be replaced with attachment button)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                  ),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: widget.messageController,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tulis Pesan...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          8,
                          14,
                          8,
                          14,
                        ),
                      ),
                    ),
                  ),

                  // Send button
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: AnimatedBuilder(
                      animation: widget.messageController,
                      builder: (context, child) {
                        final bool hasText =
                            widget.messageController.text.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Material(
                            color: Colors.transparent,
                            child: IconButton(
                              onPressed: hasText ? widget.onSendMessage : null,
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  hasText
                                      ? Icons.send_rounded
                                      : Icons.send_rounded,
                                  key: ValueKey<bool>(hasText),
                                  color: hasText
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  size: 22,
                                ),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: hasText
                                    ? colorScheme.primaryContainer
                                    : Colors.transparent,
                                foregroundColor: hasText
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
