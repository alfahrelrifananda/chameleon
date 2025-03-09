import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gnoo/main/chat/chats/ai_image_page.dart';
import 'package:gnoo/main/chat/chats/ai_page.dart';
import 'package:gnoo/main/album/albums/album_device_subpage.dart';
import 'package:gnoo/main/album/albums/downloads_page.dart';
import 'package:gnoo/main/profile/profiles/follow_post_page.dart';
import 'package:gnoo/main/board/boards/notification_subpage.dart';
import 'package:gnoo/main/pages/settings_bottom_sheet.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/scroll_notifier.dart';
import 'board/board_page.dart';
import 'album/album_page.dart';
import 'profile/profile_page.dart';
import 'album/albums/bottom_sheet_device.dart';
import 'album/albums/create_album_page.dart';
import 'pages/upload_posts.dart';
import 'chat/chat_list.dart';
import 'pages/settings_provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  static _MainPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainPageState>();
  }

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late PageController _pageController;
  final GlobalKey<BoardsPageState> _boardsKey = GlobalKey<BoardsPageState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _isNavBarVisible = true; // Navbar visibility
  bool _isMiniFabVisible = true; // Mini FAB visibility
  bool _isSwipingToProfile = false; // Flag to prevent double login prompt
  String? _uid; // User ID
  String _selectedFilter = 'latest'; // Selected filter

  final ScrollNotifier _scrollNotifier = ScrollNotifier();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadUid(); // Load user ID

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _showDevelopmentNotification();
    // });
  }

  // void _showDevelopmentNotification() {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     builder: (BuildContext context) {
  //       return Container(
  //         decoration: BoxDecoration(
  //           color: colorScheme.surface,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  //         ),
  //         padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Dalam Pengembangan',
  //               style: TextStyle(
  //                 fontSize: 24,
  //                 fontWeight: FontWeight.bold,
  //                 color: colorScheme.onSurface,
  //               ),
  //             ),
  //             SizedBox(height: 16),
  //             Text(
  //               'Aplikasi ini masih dalam tahap pengembangan. Kami mohon maaf jika Anda menemukan bug atau fungsionalitas yang belum sempurna.',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 color: colorScheme.onSurfaceVariant,
  //               ),
  //             ),
  //             SizedBox(height: 24),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //                 OutlinedButton(
  //                   onPressed: () => Navigator.of(context).pop(),
  //                   style: FilledButton.styleFrom(
  //                     backgroundColor: Colors.transparent,
  //                     foregroundColor: colorScheme.onSurface,
  //                     padding:
  //                         EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                   ),
  //                   child: Text('Baiklah'),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose PageController
    super.dispose();
  }

  // Load user ID from SharedPreferences
  Future<void> _loadUid() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _uid = prefs.getString('uid');
    });
  }

  // Handle navigation between pages
  Future<void> _handleNavigation(int index) async {
    if (index == 0 && _currentIndex == 0) {
      // Access BoardsPage state through GlobalKey and trigger scroll to top and refresh
      final boardsState = _boardsKey.currentState;
      if (boardsState != null) {
        await boardsState.scrollToTopAndRefresh();
        return;
      }
    }

    // Check if user is trying to access Profile page without being logged in
    if (index == 3 && _uid == null) {
      // await showLoginReminder(context);
      // Prevent going to Profile page if still not logged in after reminder
      if (_currentIndex == 3 && _uid == null) {
        _pageController.animateToPage(
          _currentIndex - 1, // Go back to the previous page
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() {
      _currentIndex = index;
      _isNavBarVisible = true; // Reset navbar visibility
      _isMiniFabVisible = true; // Reset mini FAB visibility
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Update visibility of navbar and mini FAB
  void _updateVisibility(
      bool isNavBarVisible, bool isMiniFabVisible, int pageIndex) {
    if (pageIndex == _currentIndex) {
      // Only update if the visibility change is for the current page
      setState(() {
        _isNavBarVisible = isNavBarVisible;
        _isMiniFabVisible = isMiniFabVisible;
      });
    }
  }

  // Handle page changes from PageView
  Future<void> _handlePageChange(int index) async {
    // Same login check as _handleNavigation
    if (index == 3 && _uid == null) {
      if (!_isSwipingToProfile) {
        _isSwipingToProfile = true; // Prevent multiple prompts
        // await showLoginReminder(context);
        _isSwipingToProfile = false; // Reset the flag
        _pageController.animateToPage(
          _currentIndex, // Stay on the current page
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    setState(() {
      _currentIndex = index;
      _isNavBarVisible = true; // Reset visibility
      _isMiniFabVisible = true;
    });
  }

  Widget _buildMiniFABFollow(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Add async
            final prefs =
                await SharedPreferences.getInstance(); // Add user check
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: FollowPostPage(),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            Icons.group_outlined, // Changed icon to match functionality
            color: colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
      ),
    );
  }

  void setNavBarVisible(bool visible) {
    _scrollNotifier.setVisible(visible);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final viewStyleProvider = Provider.of<ViewStyleProvider>(context);

    return ChangeNotifierProvider.value(
        value: _scrollNotifier,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _buildDrawer(context),
          backgroundColor: colorScheme.background,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: _handlePageChange,
                children: [
                  // Boards Page
                  ScrollNotificationListener(
                    pageIndex: 0,
                    onVisibilityChanged: (isNavBarVisible, isMiniFabVisible) {
                      _updateVisibility(isNavBarVisible, isMiniFabVisible, 0);
                    },
                    child: BoardsPage(
                      key: _boardsKey,
                      // isGridStyle: _isGridStyle,
                      selectedFilter: _selectedFilter,
                    ),
                  ),
                  // Album Page
                  ScrollNotificationListener(
                    pageIndex: 1,
                    onVisibilityChanged: (isNavBarVisible, isMiniFabVisible) {
                      _updateVisibility(isNavBarVisible, isMiniFabVisible, 1);
                    },
                    child: const AlbumPage(),
                  ),
                  // Chat List Page
                  ScrollNotificationListener(
                    pageIndex: 2,
                    onVisibilityChanged: (isNavBarVisible, isMiniFabVisible) {
                      _updateVisibility(isNavBarVisible, isMiniFabVisible, 2);
                    },
                    child: ChatListPage(),
                  ),
                  // Profile Page
                  ScrollNotificationListener(
                    pageIndex: 3,
                    onVisibilityChanged: (isNavBarVisible, isMiniFabVisible) {
                      _updateVisibility(isNavBarVisible, isMiniFabVisible, 3);
                    },
                    child: ProfilePage(),
                  ),
                ],
              ),
              // Animated Mini FABs (Upload, Album, Chat)
              if (viewStyleProvider.isFloatingNavbar) ...[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 23,
                  bottom:
                      _currentIndex == 0 ? (_isMiniFabVisible ? 100 : 0) : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:
                        _currentIndex == 0 && _isMiniFabVisible ? 1.0 : 0.0,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildMiniFABFollow(context, colorScheme),
                      ],
                    ),
                  ),
                ),
                // Album Page Mini FAB
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 23,
                  bottom:
                      _currentIndex == 1 ? (_isMiniFabVisible ? 100 : 0) : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:
                        _currentIndex == 1 && _isMiniFabVisible ? 1.0 : 0.0,
                    child: _buildMiniFABAlbum(colorScheme),
                  ),
                ),
                // Chat Page Mini FAB
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: 23,
                  bottom:
                      _currentIndex == 2 ? (_isMiniFabVisible ? 100 : 0) : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:
                        _currentIndex == 2 && _isMiniFabVisible ? 1.0 : 0.0,
                    child: _buildMiniFABChat(colorScheme),
                  ),
                ),
              ],

              // Animated Navbar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: viewStyleProvider.isFloatingNavbar
                    ? 16
                    : 0, // Only add margin if floating
                right: viewStyleProvider.isFloatingNavbar
                    ? 16
                    : 0, // Only add margin if floating
                bottom: _isNavBarVisible
                    ? (viewStyleProvider.isFloatingNavbar ? 24 : 0)
                    : -100, // Hide navbar on scroll down
                child: viewStyleProvider.isFloatingNavbar
                    ? Row(
                        children: [
                          Expanded(
                              child: _buildFloatingNavBar(
                                  colorScheme)), // Floating Navbar items
                          const SizedBox(width: 8),
                          _buildMainFAB(colorScheme), // Search FAB
                        ],
                      )
                    : _buildMaterial3NavBar(colorScheme), // Material 3 Navbar
              ),
            ],
          ),
          floatingActionButton:
              !viewStyleProvider.isFloatingNavbar && _isNavBarVisible
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: _buildMainFAB(colorScheme),
                    )
                  : null,
        ));
  }

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return NavigationDrawer(
      backgroundColor: colorScheme.surface,
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) async {
        Navigator.pop(context); // Close drawer first

        switch (index) {
          case 1: // Unggah Post
            final prefs = await SharedPreferences.getInstance();
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: UploadPosts(),
                ),
              );
            }
            break;
          case 2: // Buat Album
            final prefs = await SharedPreferences.getInstance();
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: CreateAlbumPage(),
                ),
              );
            }
            break;
          case 3: // Album Perangkat
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.sharedAxisVertical,
                child: const DeviceAlbumPage(),
              ),
            );
            break;
          case 4: // Download
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.sharedAxisVertical,
                child: const DownloadsPage(),
              ),
            );
            break;
          case 5: // Aktivitas
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.sharedAxisVertical,
                child: const NotificationPage(),
              ),
            );
            break;
          case 6: // AI Chat
            final prefs = await SharedPreferences.getInstance();
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: const AIPage(),
                ),
              );
            }
            break;
          case 7: // AI Image
            final prefs = await SharedPreferences.getInstance();
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.sharedAxisVertical,
                  child: const ImageGenerationPage(),
                ),
              );
            }
            break;

          case 8:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.sharedAxisVertical,
                child: const SettingsPage(),
              ),
            );
            break;
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Menu Utama',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: const Text('Beranda'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.add_a_photo_outlined),
          selectedIcon: const Icon(Icons.add_a_photo),
          label: const Text('Unggah Post'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.create_new_folder_outlined),
          selectedIcon: const Icon(Icons.create_new_folder),
          label: const Text('Buat Album'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.photo_library_outlined),
          selectedIcon: const Icon(Icons.photo_library),
          label: const Text('Album Perangkat'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.download_outlined),
          selectedIcon: const Icon(Icons.download),
          label: const Text('Unduhan'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.mark_email_unread_outlined),
          selectedIcon: const Icon(Icons.mark_email_unread),
          label: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('koleksi_users')
                .doc(_uid)
                .collection('koleksi_notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final int unreadCount = snapshot.data?.docs.length ?? 0;
              return Row(
                children: [
                  const Text('Aktivitas'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
        ),

        const Divider(height: 1),
        // AI Features Section
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Fitur AI',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),

        NavigationDrawerDestination(
          icon: const Icon(Icons.auto_awesome_outlined),
          selectedIcon: const Icon(Icons.auto_awesome),
          label: const Text('AI Chat'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.auto_fix_high_outlined),
          selectedIcon: const Icon(Icons.auto_fix_high),
          label: const Text('AI Image'),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
        ),

        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Pengaturan',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),

        NavigationDrawerDestination(
          icon: const Icon(Icons.tune_outlined),
          selectedIcon: const Icon(Icons.tune),
          label: const Text('Pengaturan'),
        ),
      ],
    );
  }

  Widget _buildFloatingNavBar(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.auto_awesome_mosaic_outlined,
                  Icons.auto_awesome_mosaic, 0, 'Boards'),
              _buildNavItem(Icons.burst_mode_outlined, Icons.burst_mode_rounded,
                  1, 'Album'),
              _buildNavItem(
                  Icons.textsms_outlined, Icons.textsms_rounded, 2, 'Chat'),
              _buildNavItem(Icons.person_outline, Icons.person, 3, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial3NavBar(ColorScheme colorScheme) {
    return MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
        child: NavigationBar(
          height: 80,
          elevation: 0,
          backgroundColor: colorScheme.surfaceContainerHighest,
          indicatorColor: colorScheme.secondaryContainer,
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _handleNavigation,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_mosaic_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_mosaic),
              label: 'Boards',
            ),
            NavigationDestination(
              icon: const Icon(Icons.burst_mode_outlined),
              selectedIcon: const Icon(Icons.burst_mode_rounded),
              label: 'Album',
            ),
            NavigationDestination(
              icon: Stack(
                children: [
                  const Icon(Icons.textsms_outlined),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('koleksi_messages')
                        .where('receiverId', isEqualTo: _uid)
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final int unreadCount = snapshot.data!.docs.length;

                      return Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 8,
                            minHeight: 8,
                          ),
                          child: unreadCount > 9
                              ? Center(
                                  child: Text(
                                    '9+',
                                    style: TextStyle(
                                      color: colorScheme.onError,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              selectedIcon: const Icon(Icons.textsms_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ));
  }

  // Build individual navigation item
  Widget _buildNavItem(
      IconData outlinedIcon, IconData filledIcon, int index, String label) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _handleNavigation(index), // Handle navigation
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Animated icon container
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
            ),
            child: Icon(
              isSelected ? filledIcon : outlinedIcon, // Toggle icon
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          // Unread message indicator (for Chat)
          if (index == 2) // Chat icon
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('koleksi_messages')
                  .where('receiverId', isEqualTo: _uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink(); // Hide if no unread messages
                }

                final int unreadCount = snapshot.data!.docs.length;

                return Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Build the main search FAB
  Widget _buildMainFAB(ColorScheme colorScheme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showAddBottomSheet(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Icon(
            Icons.add,
            color: colorScheme.onPrimaryContainer,
            size: 32,
          ),
        ),
      ),
    );
  }

  // Build the mini FAB for creating an album
  Widget _buildMiniFABAlbum(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final String? userID = prefs.getString('uid');

            if (userID == null) {
              // await showLoginReminder(context);
            } else {
              // ignore: unused_local_variable
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const BottomSheetDevice(),
              );

              // You can handle the result from CreateAlbumPage if needed
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            Icons.sd_card, // Simpler add icon for creating an album
            color: colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
      ),
    );
  }

  // Build the mini FAB for AI options
  Widget _buildMiniFABChat(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _showBottomSheet(context), // Show AI options bottom sheet
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            Icons.auto_awesome, // Icon for AI
            color: colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
      ),
    );
  }

  Future<void> _showBottomSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userID = prefs.getString('uid');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (userID == null) {
      // await showLoginReminder(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle and Title
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Row(
                        children: [
                          Text(
                            'Eksplorasi Kemampuan AI',
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  colorScheme.surfaceVariant.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Chat Option
                      _AIFeatureCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'Ngobrol dengan AI',
                        subtitle: 'Dapatkan jawaban dan ide dari AI',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.sharedAxisVertical,
                              child: const AIPage(),
                            ),
                          );
                        },
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),

                      const SizedBox(height: 16),

                      // AI Image Generation Option
                      _AIFeatureCard(
                        icon: Icons.image_outlined,
                        title: 'Kreasi Gambar Artistik',
                        subtitle: 'Hasilkan gambar unik dengan AI',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.sharedAxisVertical,
                              child: const ImageGenerationPage(),
                            ),
                          );
                        },
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Kembali',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddBottomSheet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userID = prefs.getString('uid');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (userID == null) {
      // await showLoginReminder(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle and Title
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Row(
                        children: [
                          Text(
                            'Pilih Aksi',
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  colorScheme.surfaceVariant.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upload Post Option
                      _AIFeatureCard(
                        icon: Icons.upload_file,
                        title: 'Unggah Post',
                        subtitle: 'Bagikan momen Anda dengan post.',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.sharedAxisVertical,
                              child: UploadPosts(),
                            ),
                          );
                        },
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),

                      const SizedBox(height: 16),

                      // Create Album Option
                      _AIFeatureCard(
                        icon: Icons.photo_album,
                        title: 'Buat Album',
                        subtitle: 'Kumpulkan foto dalam album.',
                        onTap: () async {
                          Navigator.pop(context);
                          // ignore: unused_local_variable
                          final result = await Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.sharedAxisVertical,
                              child: CreateAlbumPage(),
                            ),
                          );
                          // Handle result if needed (e.g., refresh list after album creation)
                        },
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Kembali',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.normal,
                    ),
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

// Custom ScrollNotificationListener (for hiding navbar and mini FAB)
class ScrollNotificationListener extends StatefulWidget {
  final Widget child;
  final Function(bool, bool) onVisibilityChanged;
  final int pageIndex;

  const ScrollNotificationListener({
    Key? key,
    required this.child,
    required this.onVisibilityChanged,
    required this.pageIndex,
  }) : super(key: key);

  @override
  _ScrollNotificationListenerState createState() =>
      _ScrollNotificationListenerState();
}

class _ScrollNotificationListenerState
    extends State<ScrollNotificationListener> {
  bool _isNavBarVisible = true;
  bool _isMiniFabVisible = true;
  double _lastScrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Only handle notifications from the child ScrollView
        if (notification.depth > 0) {
          return false;
        }
        if (notification is ScrollUpdateNotification) {
          final double currentScrollOffset = notification.metrics.pixels;
          final bool isScrollingDown = currentScrollOffset > _lastScrollOffset;

          // Hide navbar and mini FAB when scrolling down, but only after scrolling 50 pixels
          if (isScrollingDown && currentScrollOffset > 50) {
            if (_isNavBarVisible || _isMiniFabVisible) {
              setState(() {
                _isNavBarVisible = false;
                _isMiniFabVisible = false;
              });
              widget.onVisibilityChanged(
                  false, false); // Notify MainPage of visibility change
            }
          } else if (!isScrollingDown) {
            // Show navbar and mini FAB when scrolling up, or when reaching the top
            if (currentScrollOffset <= 0) {
              if (!_isNavBarVisible || !_isMiniFabVisible) {
                setState(() {
                  _isNavBarVisible = true;
                  _isMiniFabVisible = true;
                });
                widget.onVisibilityChanged(true,
                    true); // Notify MainPage of visibility change (scrolled to top)
              }
            } else if (!_isNavBarVisible || !_isMiniFabVisible) {
              // Show even if not at the top, but only if they were hidden.
              setState(() {
                _isNavBarVisible = true;
                _isMiniFabVisible = true;
              });
              widget.onVisibilityChanged(
                  true, true); // Notify MainPage of visibility change
            }
          }

          _lastScrollOffset = currentScrollOffset; // Update last scroll offset
        }
        return false;
      },
      child:
          widget.child, // The actual page content (BoardsPage, AlbumPage, etc.)
    );
  }
}

// Custom widget for AI feature cards
class _AIFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _AIFeatureCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
