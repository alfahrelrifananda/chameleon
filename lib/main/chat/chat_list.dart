import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gnoo/main/chat/chats/ai_image_page.dart';
import 'package:gnoo/main/chat/chats/ai_page.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../pages/settings_bottom_sheet.dart';
import 'chats/chat_page.dart';

// Add enum for chat filters
enum ChatFilter { all, unread, recent }

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  // ignore: unused_field
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isInitialLoad = true; // Added flag for initial load
  Map<String, Map<String, dynamic>> _userDataCache = {};
  Map<String, bool> _unreadStatusCache = {};
  Stream<QuerySnapshot>? _chatStream;
  List<DocumentSnapshot> _cachedMessages = [];
  StreamSubscription? _chatSubscription;

  // Add current filter state
  ChatFilter _currentFilter = ChatFilter.all;

  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _refreshAnimationController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
  }

  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _fadeAnimationController.forward();

    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  Future<void> _initializeData() async {
    try {
      // Set a timeout for initialization
      await Future.wait([
        _getCurrentUserId().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('User ID retrieval timed out');
            return null;
          },
        ),
      ], eagerError: true);

      // Only setup stream if user ID is available
      if (_currentUserId != null) {
        _setupChatStream();
      } else {
        print('Failed to retrieve current user ID');
      }

      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Comprehensive initialization error: $e');
      setState(() {
        _isInitialLoad = false;
        _isLoading = false;
      });
    }
  }

  void _setupChatStream() {
    if (_currentUserId != null) {
      _chatStream = _getFilteredChatStream();

      _chatSubscription = _chatStream?.listen((snapshot) {
        if (mounted) {
          setState(() {
            _cachedMessages = snapshot.docs;
          });
        }
      });

      // Listen for unread messages to update the unread status cache
      FirebaseFirestore.instance
          .collection('koleksi_messages')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadStatusCache.clear();
          });
        }
      });
    }
  }

  // Add method to get filtered stream based on current filter
  Stream<QuerySnapshot> _getFilteredChatStream() {
    var query = FirebaseFirestore.instance
        .collection('koleksi_messages')
        .where('participants', arrayContains: _currentUserId);

    switch (_currentFilter) {
      case ChatFilter.unread:
        // Add unread filter
        query = query
            .where('receiverId', isEqualTo: _currentUserId)
            .where('read', isEqualTo: false);
        break;
      case ChatFilter.recent:
        // Recent messages (last 24 hours)
        final yesterday = DateTime.now().subtract(const Duration(hours: 24));
        final timestamp = Timestamp.fromDate(yesterday);
        query = query.where('timestamp', isGreaterThanOrEqualTo: timestamp);
        break;
      case ChatFilter.all:
      // ignore: unreachable_switch_default
      default:
        // No additional filtering needed
        break;
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  // Add method to get filter title
  String _getFilterTitle() {
    switch (_currentFilter) {
      case ChatFilter.all:
        return 'Semua Percakapan';
      case ChatFilter.unread:
        return 'Belum Dibaca';
      case ChatFilter.recent:
        return '24 Jam Terakhir';
    }
  }

  Widget _buildQuickAccessCards() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // First card - AI Chat
          Expanded(
            child: Card(
              color: colorScheme.secondaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  // Navigation to AI Chat feature
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.sharedAxisVertical,
                      child: const AIPage(), // Make sure to import this page
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI Chat',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngobrolin banyak hal',
                        style: textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onSecondaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Second card - AI Assistant
          Expanded(
            child: Card(
              color: colorScheme.tertiaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  // Navigation to AI Assistant feature
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.sharedAxisVertical,
                      child:
                          const ImageGenerationPage(), // Make sure to import this page
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kreasi Gambar',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hasilkan gambar unik',
                        style: textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onTertiaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add method to show filter options
  void _showFilterOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Percakapan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                leading: Icon(Icons.all_inbox, color: colorScheme.primary),
                title: const Text('Semua'),
                selected: _currentFilter == ChatFilter.all,
                selectedTileColor:
                    colorScheme.primaryContainer.withOpacity(0.2),
                onTap: () {
                  setState(() {
                    _currentFilter = ChatFilter.all;
                  });
                  _updateChatStream();
                  Navigator.pop(context);
                },
                selectedColor: colorScheme.onSurface,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                leading:
                    Icon(Icons.mark_email_unread, color: colorScheme.primary),
                title: const Text('Belum Dibaca'),
                selected: _currentFilter == ChatFilter.unread,
                selectedTileColor:
                    colorScheme.primaryContainer.withOpacity(0.2),
                onTap: () {
                  setState(() {
                    _currentFilter = ChatFilter.unread;
                  });
                  _updateChatStream();
                  Navigator.pop(context);
                },
                selectedColor: colorScheme.onSurface,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                leading: Icon(Icons.access_time, color: colorScheme.primary),
                title: const Text('24 Jam Terakhir'),
                selected: _currentFilter == ChatFilter.recent,
                selectedTileColor:
                    colorScheme.primaryContainer.withOpacity(0.2),
                onTap: () {
                  setState(() {
                    _currentFilter = ChatFilter.recent;
                  });
                  _updateChatStream();
                  Navigator.pop(context);
                },
                selectedColor: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add method to update chat stream when filter changes
  void _updateChatStream() {
    // Cancel existing subscription
    _chatSubscription?.cancel();

    // Setup new filtered stream
    _chatStream = _getFilteredChatStream();

    // Reset cache
    _cachedMessages = [];

    // Listen to new stream
    _chatSubscription = _chatStream?.listen((snapshot) {
      if (mounted) {
        setState(() {
          _cachedMessages = snapshot.docs;
        });
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _currentUserId = user.uid;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _getCurrentUserId: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userDataCache.containsKey(userId)) {
      return _userDataCache[userId];
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _userDataCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print('Error fetching user data for UserID $userId: $e');
    }
    return null;
  }

  Future<bool> _hasUnreadMessages(String otherUserId) async {
    try {
      if (_unreadStatusCache.containsKey(otherUserId)) {
        return _unreadStatusCache[otherUserId]!;
      }

      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('koleksi_messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      final hasUnread = unreadMessages.docs.isNotEmpty;
      _unreadStatusCache[otherUserId] = hasUnread;
      return hasUnread;
    } catch (e) {
      print('Error checking unread messages: $e');
      return false;
    }
  }

  void _resetUnreadCache(String userId) {
    _unreadStatusCache.remove(userId);
  }

  List<DocumentSnapshot> _processMessages(List<DocumentSnapshot> messages) {
    Set<String> conversationPartners = {};
    List<DocumentSnapshot> latestMessages = [];

    for (var message in messages) {
      final data = message.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants']);
      final otherUserId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => _currentUserId!,
      );

      if (!conversationPartners.contains(otherUserId)) {
        conversationPartners.add(otherUserId);
        latestMessages.add(message);
      }
    }

    return latestMessages;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isInitialLoad) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perpesanan'),
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          _getFilterTitle(),
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterOptions(context);
            },
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
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.error),
                    ),
                  );
                }

                // Show shimmer during initial load or refresh
                if ((snapshot.connectionState == ConnectionState.waiting &&
                        _cachedMessages.isEmpty) ||
                    _isRefreshing) {
                  return ListView.builder(
                    itemCount: 3,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) => _buildShimmerEffect(),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                if (snapshot.hasData) {
                  _cachedMessages = messages;
                }

                final latestMessages = _processMessages(_cachedMessages);

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: latestMessages.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            // Add the quick access cards here
                            _buildQuickAccessCards(),
                            // Main chat list in an Expanded widget
                            Expanded(
                              child: AnimationLimiter(
                                child: ListView.builder(
                                  itemCount: latestMessages.length +
                                      1, // +1 for padding item
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    // Add padding item at the end
                                    if (index == latestMessages.length) {
                                      return SizedBox(
                                          height:
                                              80); // Adjust this height based on your navbar
                                    }

                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration:
                                          const Duration(milliseconds: 375),
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(
                                          child: _buildChatItem(
                                            context,
                                            latestMessages[index],
                                            colorScheme,
                                            textTheme,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
          // Loading overlay during refresh
          if (_isRefreshing)
            Container(
              color: colorScheme.background.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const assetPath = 'assets/images/search.svg';

    String emptyStateMessage;
    String emptyStateSubtitle;

    switch (_currentFilter) {
      case ChatFilter.unread:
        emptyStateMessage = 'Tidak ada pesan yang belum dibaca';
        emptyStateSubtitle = "Semua pesan sudah dibaca";
        break;
      case ChatFilter.recent:
        emptyStateMessage = 'Tidak ada percakapan baru';
        emptyStateSubtitle = "Belum ada percakapan dalam 24 jam terakhir";
        break;
      case ChatFilter.all:
      // ignore: unreachable_switch_default
      default:
        emptyStateMessage = 'Belum ada percakapan';
        emptyStateSubtitle =
            "Mulai percakapan baru dengan menekan tombol Search dibawah";
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    .replaceAll('#000000', theme.colorScheme.primary.toHex())
                    .replaceAll('#263238', '#263238')
                    .replaceAll('#FFB573', '#FFB573')
                    .replaceAll(
                        '#FFFFFF', theme.colorScheme.surfaceContainer.toHex());

                return SvgPicture.string(
                  svgContent,
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            emptyStateMessage,
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              emptyStateSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(
    BuildContext context,
    DocumentSnapshot message,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final messageData = message.data() as Map<String, dynamic>;
    final participants = List<String>.from(messageData['participants']);
    final otherUserId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => _currentUserId!,
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(otherUserId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return _buildShimmerEffect();
        }

        final userData = userSnapshot.data!;
        final username = userData['username'] ?? 'Unknown User';
        final profilePic = userData['profile_image_url'] as String?;
        final timestamp = messageData['timestamp'] as Timestamp;
        final messageTime = timestamp.toDate();
        final formattedTime = _formatMessageTime(messageTime);

        return FutureBuilder<bool>(
          future: _hasUnreadMessages(otherUserId),
          builder: (context, unreadSnapshot) {
            final hasUnread = unreadSnapshot.data ?? false;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _resetUnreadCache(otherUserId);
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.sharedAxisVertical,
                        child: ChatPage(
                          recipientUserId: otherUserId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(32),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: hasUnread
                          ? colorScheme.primaryContainer.withOpacity(0.2)
                          : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: _buildChatItemContent(
                      colorScheme,
                      textTheme,
                      profilePic,
                      hasUnread,
                      username,
                      formattedTime,
                      messageData['message'] ?? '',
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatItemContent(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String? profilePic,
    bool hasUnread,
    String username,
    String formattedTime,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                ),
                clipBehavior: Clip.antiAlias,
                child: profilePic != null
                    ? CachedNetworkImage(
                        imageUrl: profilePic,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: colorScheme.onPrimaryContainer,
                          size: 32,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: textTheme.bodySmall?.copyWith(
                        color: hasUnread
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            hasUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: hasUnread
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceVariant.withOpacity(0.5),
        highlightColor: colorScheme.surface,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime messageTime) {
    final now = DateTime.now();
    if (now.difference(messageTime).inDays == 0) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(messageTime).inDays == 1) {
      return 'Kemarin';
    } else {
      return '${messageTime.day}/${messageTime.month}';
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _userDataCache.clear();
    _unreadStatusCache.clear();
    _fadeAnimationController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }
}

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
