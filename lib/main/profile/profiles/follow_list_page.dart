import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../profile_user.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowListPage(
      {Key? key, required this.userId, required this.initialIndex})
      : super(key: key);

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialIndex);
    _loadFollowData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowData() async {
    try {
      // Fetch followers
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_follows')
          .doc(widget.userId)
          .collection('userFollowers')
          .get();
      _followers = await _getUsersFromSnapshot(followersSnapshot);

      // Fetch following
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('koleksi_follows')
          .doc(widget.userId)
          .collection('userFollowing')
          .get();
      _following = await _getUsersFromSnapshot(followingSnapshot);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading follow data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getUsersFromSnapshot(
      QuerySnapshot snapshot) async {
    List<Map<String, dynamic>> users = [];
    for (var doc in snapshot.docs) {
      String userId = doc.id;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('koleksi_users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          userData['uid'] = userId;
          users.add(userData);
        }
      } catch (e) {
        print("Error loading user data for $userId: $e");
      }
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(' '),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text('Pengikut (${_followers.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Text('Mengikuti (${_following.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState(colorScheme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFollowList(_followers, 'pengikut'),
                _buildFollowList(_following, 'mengikuti'),
              ],
            ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            child: Shimmer.fromColors(
              baseColor: colorScheme.surfaceVariant,
              highlightColor: colorScheme.surface,
              child: ListTile(
                leading: CircleAvatar(radius: 24),
                title: Container(
                  height: 16,
                  width: double.infinity,
                  color: Colors.white,
                ),
                subtitle: Container(
                  height: 12,
                  width: 100,
                  margin: const EdgeInsets.only(top: 8),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowList(List<Map<String, dynamic>> users, String type) {
    final colorScheme = Theme.of(context).colorScheme;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'pengikut' ? Icons.person_add_disabled : Icons.person_off,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              type == 'pengikut'
                  ? 'Belum ada pengikut'
                  : 'Belum mengikuti siapapun',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final user = users[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            clipBehavior: Clip.hardEdge,
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            child: ListTile(
              leading: Hero(
                tag: 'profile-${user['uid']}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: user['profile_image_url'] != null
                      ? NetworkImage(user['profile_image_url'])
                      : null,
                  child: user['profile_image_url'] == null
                      ? Icon(Icons.person,
                          color: colorScheme.onPrimaryContainer)
                      : null,
                ),
              ),
              title: Text(
                user['username'] ?? 'Unknown User',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              subtitle: Text(
                user['email'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: user['uid'],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
