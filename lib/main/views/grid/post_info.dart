import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
  // Cache untuk menyimpan nama pengguna dan URL foto profil
  static final Map<String, Map<String, String?>> _userCache = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, String?>>(
      future: _fetchUserData(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_userCache.containsKey(widget.userId)) {
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

        final userData = snapshot.data ??
            _userCache[widget.userId] ??
            {'username': 'Unknown User', 'profile_image_url': null};
        final userName = userData['username'] ?? 'Unknown User';
        final profileImageUrl = userData['profile_image_url'];

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
              CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: profileImageUrl != null
                    ? NetworkImage(profileImageUrl)
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
      },
    );
  }

  Future<Map<String, String?>> _fetchUserData(String userId) async {
    // Cek apakah data pengguna sudah ada di cache
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(userId)
          .get();
      final userData = {
        'username': userDoc.data()?['username'] as String? ?? 'Unknown User',
        'profile_image_url': userDoc.data()?['profile_image_url'] as String?
      };

      // Simpan data pengguna ke dalam cache
      _userCache[userId] = userData;
      return userData;
    } catch (e) {
      print("Error fetching user data: $e");
      // Simpan data default ke cache jika terjadi error
      final defaultUserData = {
        'username': 'Unknown User',
        'profile_image_url': null
      };
      _userCache[userId] = defaultUserData;
      return defaultUserData;
    }
  }
}
