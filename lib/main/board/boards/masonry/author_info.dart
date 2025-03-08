import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../profile/profile_user.dart';

class AuthorInfo extends StatefulWidget {
  const AuthorInfo({Key? key, required this.userId}) : super(key: key);

  final String userId;

  @override
  State<AuthorInfo> createState() => _AuthorInfoState();
}

class _AuthorInfoState extends State<AuthorInfo> {
  // Cache untuk menyimpan data pengguna
  static final Map<String, Map<String, dynamic>> _userDataCache = {};
  // bool _isFollowing = false;
  // final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // @override
  // void initState() {
  //   super.initState();
  //   if (_currentUserId != null && _currentUserId != widget.userId) {
  //     // _checkIfFollowing();
  //   }
  // }

  // Future<void> _checkIfFollowing() async {
  //   try {
  //     final followDoc = await FirebaseFirestore.instance
  //         .collection('koleksi_follows')
  //         .doc(_currentUserId)
  //         .collection('userFollowing')
  //         .doc(widget.userId)
  //         .get();

  //     if (mounted) {
  //       setState(() {
  //         _isFollowing = followDoc.exists;
  //       });
  //     }
  //   } catch (e) {
  //     print("Error checking follow status: $e");
  //   }
  // }

  // Future<void> _toggleFollow() async {
  //   if (_currentUserId == null || _currentUserId == widget.userId) return;

  //   try {
  //     final followsRef =
  //         FirebaseFirestore.instance.collection('koleksi_follows');
  //     final followingRef = followsRef
  //         .doc(_currentUserId)
  //         .collection('userFollowing')
  //         .doc(widget.userId);
  //     final followersRef = followsRef
  //         .doc(widget.userId)
  //         .collection('userFollowers')
  //         .doc(_currentUserId);

  //     // Store the new state to use in case of error
  //     final newIsFollowing = !_isFollowing;

  //     setState(() {
  //       _isFollowing = newIsFollowing;
  //     });

  //     // Update Firestore
  //     await FirebaseFirestore.instance.runTransaction((transaction) async {
  //       if (newIsFollowing) {
  //         transaction
  //             .set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
  //         transaction
  //             .set(followersRef, {'timestamp': FieldValue.serverTimestamp()});
  //       } else {
  //         transaction.delete(followingRef);
  //         transaction.delete(followersRef);
  //       }
  //     });

  //     // Notify any listening widgets about the state change
  //     // This ensures that if there are multiple AuthorInfo widgets with the same userId,
  //     // they all get updated after one of them changes the follow state
  //     if (mounted) {
  //       // Force rebuild all AuthorInfo widgets with the same userId
  //       // by updating the cache
  //       _userDataCache.remove(widget.userId);
  //       setState(() {});
  //     }
  //   } catch (e) {
  //     print("Error toggling follow: $e");
  //     // Revert back in case of error
  //     if (mounted) {
  //       setState(() {
  //         _isFollowing = !_isFollowing;
  //       });
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to ${_isFollowing ? 'follow' : 'unfollow'}'),
  //         backgroundColor: Theme.of(context).colorScheme.error,
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserData(widget.userId),
      builder: (context, snapshot) {
        // Check if the data is still loading and not in cache
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_userDataCache.containsKey(widget.userId)) {
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
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildErrorOrPlaceholder(colorScheme);
        }

        // Data sudah di-cache atau di-fetch
        final userData = snapshot.data!;
        final userName = userData['username'];
        final profileImageUrl = userData['profile_image_url'];

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
      },
    );
  }

  // Method to build avatar widget
  Widget _buildAvatar(
      ColorScheme colorScheme, String userName, String? profileImageUrl) {
    return CircleAvatar(
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
    );
  }

  // Method to build follow/unfollow button with improved styling
  // Widget _buildFollowButton(BuildContext context) {
  //   // If viewing own profile or not logged in, don't show follow button
  //   if (_currentUserId == null || _currentUserId == widget.userId) {
  //     return const SizedBox.shrink();
  //   }

  //   final buttonWidth =
  //       MediaQuery.of(context).size.width * 0.26; // Responsive width

  //   if (_isFollowing) {
  //     return SizedBox(
  //       width: buttonWidth,
  //       child: OutlinedButton(
  //         onPressed: _toggleFollow,
  //         style: OutlinedButton.styleFrom(
  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(8),
  //           ),
  //         ),
  //         child: const Text('Unfollow'),
  //       ),
  //     );
  //   } else {
  //     return SizedBox(
  //       width: buttonWidth,
  //       child: FilledButton(
  //         onPressed: _toggleFollow,
  //         style: FilledButton.styleFrom(
  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(8),
  //           ),
  //         ),
  //         child: const Text('Follow'),
  //       ),
  //     );
  //   }
  // }

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

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    // Cek apakah data pengguna sudah ada di cache
    if (_userDataCache.containsKey(userId)) {
      return _userDataCache[userId];
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(userId)
          .get();
      final userData = userDoc.data();

      // Simpan data pengguna ke dalam cache
      _userDataCache[userId] = userData!;

      return userData;
    } catch (e) {
      print("Error fetching user data: $e");
      // Anda bisa menyimpan nilai default atau null ke cache jika terjadi error
      _userDataCache[userId] = {
        'username': 'Unknown User',
        'profile_image_url': null
      };
      return null;
    }
  }
}
