// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gnoo/main/pages/post_model.dart';
import 'package:gnoo/main/pages/post_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../views/grid_view.dart';
import 'boards/masonry_view.dart';
import '../pages/settings_provider.dart';

class BoardsPage extends StatefulWidget {
  final String selectedFilter;

  const BoardsPage({
    Key? key,
    required this.selectedFilter,
  }) : super(key: key);

  @override
  State<BoardsPage> createState() => BoardsPageState();
}

class BoardsPageState extends State<BoardsPage>
    with AutomaticKeepAliveClientMixin {
  late String _selectedFilter;
  bool _isLoading = true;
  bool _isChangingFilter = false;
  String? _error;
  String? _currentUserId;

  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

  List<Post> _posts = [];

  // ignore: unused_field
  final List<FilterOption> _filterOptions = [
    FilterOption(id: 'latest', label: 'Terbaru', icon: Icons.access_time),
    FilterOption(id: 'following', label: 'Mengikuti', icon: Icons.people),
    FilterOption(id: 'trending', label: 'Trending', icon: Icons.trending_up),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
    _getCurrentUser();
  }

  @override
  void didUpdateWidget(covariant BoardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedFilter != oldWidget.selectedFilter) {
      setState(() {
        _selectedFilter = widget.selectedFilter;
        _isChangingFilter = true;
      });
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      _loadPosts();
    } else {
      setState(() {
        _error = 'User tidak terautentikasi.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    if (_currentUserId == null) {
      setState(() {
        _error = 'User ID tidak tersedia';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final freshPosts =
          await _postService.getPosts(_selectedFilter, userId: _currentUserId);

      if (mounted) {
        setState(() {
          _posts = freshPosts;
          _isLoading = false;
          _isChangingFilter = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isChangingFilter = false;
          _error = 'Gagal memuat data. Tarik ke bawah untuk mencoba lagi.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: _loadPosts,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadPosts();
  }

  Widget _buildPostList(BuildContext context, bool isGridStyle) {
    final theme = Theme.of(context);
    const assetPath = 'assets/images/search.svg';

    if (_posts.isEmpty) {
      return Center(
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
                      .replaceAll('#000000', theme.colorScheme.primary.toHex())
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
              onPressed: _loadPosts,
              child: const Text('Muat Ulang'),
            ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: isGridStyle
          ? GridBoardView(
              posts: _posts,
              onRefresh: _handleRefresh,
              scrollController: _scrollController,
            )
          : MasonryBoardView(
              posts: _posts,
              onRefresh: _handleRefresh,
              scrollController: _scrollController,
            ),
    );
  }

  Future<void> scrollToTopAndRefresh() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<ViewStyleProvider>(
      builder: (context, viewStyleProvider, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (_error != null && _posts.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPosts,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    else if (_isLoading && _posts.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildPostList(context, viewStyleProvider.isGridStyle),
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
      },
    );
  }
}

class FilterOption {
  final String id;
  final String label;
  final IconData icon;

  FilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}
