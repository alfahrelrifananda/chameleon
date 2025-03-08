import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:page_transition/page_transition.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../pages/post_model.dart';
import '../pages/post_service.dart';
import 'grid/post_info.dart';
import 'grid/reels_view_page.dart';

class FilteredPostsPage extends StatefulWidget {
  final String tag;

  const FilteredPostsPage({
    Key? key,
    required this.tag,
  }) : super(key: key);

  @override
  State<FilteredPostsPage> createState() => _FilteredPostsPageState();
}

class _FilteredPostsPageState extends State<FilteredPostsPage> {
  // ignore: unused_field
  final PostService _postService = PostService();
  // ignore: unused_field
  final ScrollController _scrollController = ScrollController();
  List<String> _relatedTags = [];
  String? _selectedTag;
  // ignore: unused_field
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.tag;
    _loadRelatedTags();
  }

  Future<void> _loadRelatedTags() async {
    try {
      // Get posts with current tag
      final QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContains: widget.tag)
          .get();

      // Extract unique tags from these posts
      Set<String> tags = {};
      for (var doc in postSnapshot.docs) {
        List<dynamic> postTags =
            (doc.data() as Map<String, dynamic>)['tags'] ?? [];
        tags.addAll(postTags.cast<String>());
      }
      // Remove the current tag and convert to list
      tags.remove(widget.tag);

      setState(() {
        _relatedTags = tags.toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading related tags: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '#${widget.tag}',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Horizontal Filter List
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _relatedTags.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedTag == widget.tag,
                      label: Text('#${widget.tag}'),
                      onSelected: (selected) {
                        setState(() {
                          _selectedTag = widget.tag;
                        });
                      },
                    ),
                  );
                }

                final tag = _relatedTags[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedTag == tag,
                    label: Text('#$tag'),
                    onSelected: (selected) {
                      setState(() {
                        _selectedTag = selected ? tag : widget.tag;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Main Content
          Expanded(
            child: _PostsGrid(
              key: PageStorageKey(
                  'filtered_posts_${_selectedTag ?? widget.tag}'),
              tag: _selectedTag ?? widget.tag,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsGrid extends StatefulWidget {
  const _PostsGrid({
    required Key key,
    required this.tag,
  }) : super(key: key);

  final String tag;

  @override
  _PostsGridState createState() => _PostsGridState();
}

class _PostsGridState extends State<_PostsGrid>
    with AutomaticKeepAliveClientMixin {
  List<Post> _posts = [];
  bool _isLoading = true;
  // ignore: unused_field
  final _postService = PostService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant _PostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tag != oldWidget.tag) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_posts')
          .where('tags', arrayContains: widget.tag)
          .get();

      // // Print first document data
      // if (postSnapshot.docs.isNotEmpty) {
      //   print("First doc data: ${postSnapshot.docs.first.data()}");
      // }

      List<Post> posts =
          postSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading posts: $e");
      setState(() {
        _isLoading = false;
        _posts = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: FutureBuilder<String>(
                  future: DefaultAssetBundle.of(context)
                      .loadString('assets/images/search.svg'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }

                    try {
                      return SvgPicture.string(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      );
                    } catch (e) {
                      return const Icon(Icons.error_outline, size: 64);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada postingan dengan tag ini.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPosts,
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              itemBuilder: (context, index) {
                return KeepAliveBuilder(
                  child: AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    columnCount: 2,
                    child: ScaleAnimation(
                      child: FadeInAnimation(
                        child: _buildPostTile(_posts[index]),
                      ),
                    ),
                  ),
                );
              },
              childCount: _posts.length,
            ),
          ),
        ],
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

class KeepAliveBuilder extends StatefulWidget {
  final Widget child;
  final bool keepAlive; // Add the required parameter

  const KeepAliveBuilder({
    Key? key,
    required this.child,
    this.keepAlive = true, // Provide a default value
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

class AspectRatioImage extends StatelessWidget {
  const AspectRatioImage({
    Key? key,
    required this.imageUrl,
    required this.builder,
  }) : super(key: key);

  final String imageUrl;
  final Widget Function(BuildContext context, Widget child, double aspectRatio)
      builder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatioLayoutBuilder(
      imageUrl: imageUrl,
      builder: (context, aspectRatio) {
        return builder(
          context,
          AspectRatio(
            aspectRatio: aspectRatio,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: colorScheme.surfaceVariant,
                highlightColor: colorScheme.surface,
                child: Container(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Container(
                color: colorScheme.errorContainer,
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
          aspectRatio,
        );
      },
      placeholder: builder(
        context,
        AspectRatio(
          aspectRatio: 1.0,
          child: Shimmer.fromColors(
            baseColor: colorScheme.surfaceVariant,
            highlightColor: colorScheme.surface,
            child: Container(color: Colors.white),
          ),
        ),
        1.0,
      ),
    );
  }
}

class AspectRatioLayoutBuilder extends StatefulWidget {
  const AspectRatioLayoutBuilder({
    Key? key,
    required this.imageUrl,
    required this.builder,
    required this.placeholder,
  }) : super(key: key);

  final String imageUrl;
  final Widget Function(BuildContext context, double aspectRatio) builder;
  final Widget placeholder;

  @override
  State<AspectRatioLayoutBuilder> createState() =>
      _AspectRatioLayoutBuilderState();
}

class _AspectRatioLayoutBuilderState extends State<AspectRatioLayoutBuilder> {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getImage();
  }

  @override
  void didUpdateWidget(AspectRatioLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _getImage();
    }
  }

  void _getImage() {
    final NetworkImage image = NetworkImage(widget.imageUrl);
    final ImageStream newStream =
        image.resolve(createLocalImageConfiguration(context));
    _updateSourceStream(newStream);
  }

  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key != newStream.key) {
      _imageStream?.removeListener(ImageStreamListener(_handleImageLoaded));
      _imageStream = newStream;
      _imageStream!.addListener(ImageStreamListener(_handleImageLoaded));
    }
  }

  void _handleImageLoaded(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _imageInfo = imageInfo;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _imageStream?.removeListener(ImageStreamListener(_handleImageLoaded));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageInfo == null) {
      return widget.placeholder;
    }

    final double aspectRatio =
        _imageInfo!.image.width / _imageInfo!.image.height;

    return widget.builder(context, aspectRatio);
  }
}
