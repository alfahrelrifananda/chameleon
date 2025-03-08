import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';

import '../../../pages/post_model.dart';
import '../../../views/grid/post_info.dart';
import '../../../views/grid/reels_view_page.dart';
import '../../../views/tags_page.dart';
import 'post_action_bar.dart';

class PostDetailsSheet extends StatefulWidget {
  final Post post;

  const PostDetailsSheet({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<PostDetailsSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd MMMM yyyy').format(dateTime);
  }

  void _navigateToFilteredPosts(BuildContext context, String tag) {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.sharedAxisVertical,
        child: FilteredPostsPage(tag: tag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle for dragging the sheet
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Main content with a single CustomScrollView
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Post details section
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        widget.post.judulFoto,
                       
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formatTimestamp(widget.post.tanggalUnggah),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.post.deskripsiFoto,
                        style: textTheme.bodyLarge,
                      ),
                      if (widget.post.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.post.tags
                              .map((tag) => Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _navigateToFilteredPosts(
                                          context, tag),
                                      child: Chip(
                                        label: Text('#$tag'),
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        labelStyle: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      if (currentUser != null) ...[
                        const SizedBox(height: 24),
                        PostActionBar(
                          post: widget.post,
                          currentUserId: currentUser.uid,
                        ),
                      ],
                      // Added more padding here to create visual separation
                      const SizedBox(height: 0),
                    ]),
                  ),
                ),

                // Relevant posts section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Text(
                      'Posts yang mungkin Anda suka',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Relevant posts grid
                _RelevantPostsSliverGrid(
                  key: PageStorageKey('relevant_posts_${widget.post.fotoId}'),
                  currentPost: widget.post,
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(50), // Sets the button height
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('Jelajahi Lebih Banyak'),
                    ),
                  ),
                ),

                // Bottom padding
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Dedicated widget for relevant posts that uses the same layout as _PostsGrid
// Sliver version of the relevant posts grid
class _RelevantPostsSliverGrid extends StatefulWidget {
  const _RelevantPostsSliverGrid({
    required Key key,
    required this.currentPost,
  }) : super(key: key);

  final Post currentPost;

  @override
  _RelevantPostsSliverGridState createState() =>
      _RelevantPostsSliverGridState();
}

class _RelevantPostsSliverGridState extends State<_RelevantPostsSliverGrid>
    with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRelevantPosts();
  }

  Future<void> _loadRelevantPosts() async {
    if (!mounted || widget.currentPost.tags.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Query for relevant posts using the same tag filtering as FilteredPostsPage
      final QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_posts')
          .where('tags', arrayContainsAny: widget.currentPost.tags)
          .limit(20) // Limit results for performance
          .get();

      // Convert to Post objects and filter out the current post
      List<Post> posts = postSnapshot.docs
          .map((doc) => Post.fromFirestore(doc))
          .where((post) => post.fotoId != widget.currentPost.fotoId)
          .toList();

      // Sort by relevance (number of matching tags)
      posts.sort((a, b) {
        int aMatches =
            a.tags.where((tag) => widget.currentPost.tags.contains(tag)).length;
        int bMatches =
            b.tags.where((tag) => widget.currentPost.tags.contains(tag)).length;
        return bMatches.compareTo(aMatches); // Descending order
      });

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading relevant posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _posts = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada postingan yang relevan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use SliverMasonryGrid instead of RefreshIndicator + CustomScrollView
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemBuilder: (context, index) {
          return KeepAliveBuilder(
            child: _buildPostTile(_posts[index]),
          );
        },
        childCount: _posts.length,
      ),
    );
  }

  Widget _buildPostTile(Post post) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.sharedAxisScale,
            child: ReelsViewPage(
              imageUrl: post.lokasiFile,
              posts: _posts,
              initialIndex: _posts.indexWhere((p) => p.fotoId == post.fotoId),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatioImage(
            imageUrl: post.lokasiFile,
            builder: (context, child, aspectRatio) {
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shadowColor: colorScheme.shadow.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: child,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.judulFoto,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                PostInfo(userId: post.userId, post: post),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper classes from FilteredPostsPage that are needed for _RelevantPostsGrid
class KeepAliveBuilder extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const KeepAliveBuilder({
    Key? key,
    required this.child,
    this.keepAlive = true,
  }) : super(key: key);

  @override
  State<KeepAliveBuilder> createState() => _KeepAliveBuilderState();
}

class _KeepAliveBuilderState extends State<KeepAliveBuilder>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
