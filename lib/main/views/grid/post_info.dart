import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../../pages/post_model.dart';
import '../../profile/profile_user.dart';
import 'like_counter.dart';

class PostTitle extends StatelessWidget {
  const PostTitle({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

class PostInfo extends StatelessWidget {
  const PostInfo({
    Key? key,
    required this.userId,
    required this.post,
  }) : super(key: key);

  final String userId;
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AuthorInfo(userId: userId)),
        LikeCounter(post: post),
      ],
    );
  }
}

class AuthorInfo extends StatefulWidget {
  const AuthorInfo({Key? key, required this.userId}) : super(key: key);

  final String userId;

  @override
  State<AuthorInfo> createState() => _AuthorInfoState();
}

class _AuthorInfoState extends State<AuthorInfo> {
  // Cache for initial display while stream connects
  static final Map<String, Map<String, String?>> _userCache = {};

  // Stream subscription for real-time updates
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Local state to store user data
  Map<String, String?> _userData = {
    'username': 'Unknown User',
    'profile_image_url': null
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupUserStream();
  }

  @override
  void didUpdateWidget(AuthorInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      // User ID changed, update the stream
      _userSubscription?.cancel();
      _setupUserStream();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _setupUserStream() {
    _isLoading = true;

    // Check if we have cached data to show immediately
    if (_userCache.containsKey(widget.userId)) {
      setState(() {
        _userData = _userCache[widget.userId]!;
        _isLoading = false;
      });
    }

    // Set up real-time listener for user data
    _userSubscription = FirebaseFirestore.instance
        .collection('koleksi_users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists) {
        final userData = {
          'username': userDoc.data()?['username'] as String? ?? 'Unknown User',
          'profile_image_url': userDoc.data()?['profile_image_url'] as String?
        };

        // Update cache
        _userCache[widget.userId] = userData;

        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoading = false;
          });
        }
      } else {
        final defaultData = {
          'username': 'Unknown User',
          'profile_image_url': null
        };

        // Update cache with default data
        _userCache[widget.userId] = defaultData;

        if (mounted) {
          setState(() {
            _userData = defaultData;
            _isLoading = false;
          });
        }
      }
    }, onError: (e) {
      print("Error in user stream: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading state if needed
    if (_isLoading && !_userCache.containsKey(widget.userId)) {
      return Shimmer.fromColors(
        baseColor: colorScheme.surfaceVariant,
        highlightColor: colorScheme.surface,
        child: Row(
          children: [
            const CircleAvatar(radius: 12),
            const SizedBox(width: 8),
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    final userName = _userData['username'] ?? 'Unknown User';
    final profileImageUrl = _userData['profile_image_url'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(userId: widget.userId),
          ),
        );
      },
      child: Row(
        children: [
          Hero(
            tag: 'profile_grid_${widget.userId}',
            child: CircleAvatar(
              radius: 12,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: profileImageUrl != null
                  ? CachedNetworkImageProvider(profileImageUrl)
                  : null,
              child: profileImageUrl == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
