import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

import '../../../profile/profile_user.dart';

class AuthorInfo extends StatefulWidget {
  const AuthorInfo({Key? key, required this.userId}) : super(key: key);

  final String userId;

  @override
  State<AuthorInfo> createState() => _AuthorInfoState();
}

class _AuthorInfoState extends State<AuthorInfo> {
  // Cache for user data - now used only for initial display while stream connects
  static final Map<String, Map<String, dynamic>> _userDataCache = {};

  // Stream subscription for real-time updates
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Local state to store user data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _hasError = false;

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
    _hasError = false;

    // Check if we have cached data to show immediately
    if (_userDataCache.containsKey(widget.userId)) {
      setState(() {
        _userData = _userDataCache[widget.userId];
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
        final data = userDoc.data()!;

        // Update cache
        _userDataCache[widget.userId] = data;

        if (mounted) {
          setState(() {
            _userData = data;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userData = {'username': 'Unknown User', 'profile_image_url': null};
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    }, onError: (e) {
      print("Error in user stream: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading state
    if (_isLoading && _userData == null) {
      return Shimmer.fromColors(
        baseColor: colorScheme.surfaceVariant,
        highlightColor: colorScheme.onSurfaceVariant.withOpacity(0.3),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.surfaceVariant,
            ),
            const SizedBox(width: 12),
            Container(
              width: 150,
              height: 20,
              color: colorScheme.surfaceVariant,
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 32,
              color: colorScheme.surfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    // Handle error or missing data
    if (_hasError || _userData == null) {
      return _buildErrorOrPlaceholder(colorScheme);
    }

    // Data is available
    final userName = _userData!['username'] ?? 'Unknown User';
    final profileImageUrl = _userData!['profile_image_url'];

    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateToUserProfile(context),
          child: _buildAvatar(colorScheme, userName, profileImageUrl),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToUserProfile(context),
            child: Text(
              userName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8), // Add spacing before button
        // _buildFollowButton(context),
        // const SizedBox(width: 8), // Add spacing after button
      ],
    );
  }

  // Method to build avatar widget
  Widget _buildAvatar(
      ColorScheme colorScheme, String userName, String? profileImageUrl) {
    return Hero(
      tag: 'profile_${widget.userId}',
      child: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: profileImageUrl != null
            ? CachedNetworkImageProvider(profileImageUrl)
            : null,
        child: profileImageUrl == null
            ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );
  }

  // Method to navigate to user profile
  void _navigateToUserProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: widget.userId),
      ),
    );
  }

  // Method to build placeholder or error widget
  Widget _buildErrorOrPlaceholder(ColorScheme colorScheme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Unknown User',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
