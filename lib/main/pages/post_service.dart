import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:gnoo/main/pages/post_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload a new post
  Future<void> uploadPost({
    required File image,
    required String userId,
    required String judul,
    required String deskripsi,
    required List<String> tags,
  }) async {
    try {
      final String fotoId = Uuid().v4();
      final storageRef = _storage.ref();
      final imageRef = storageRef.child('koleksi_posts/$fotoId.jpg');

      if (kIsWeb) {
        final imageBytes = await image.readAsBytes();
        await imageRef.putData(imageBytes);
      } else {
        await imageRef.putFile(image);
      }

      final imageUrl = await imageRef.getDownloadURL();

      final docRef = await _firestore.collection('koleksi_posts').add({
        'fotoId': fotoId,
        'judulFoto': judul,
        'deskripsiFoto': deskripsi,
        'tanggalUnggah': Timestamp.now(),
        'lokasiFile': imageUrl,
        'albumId': null,
        'userId': userId,
        'tags': tags,
        'likes': 0,
      });

      // Update the document with its ID
      await docRef.update({'id': docRef.id});

      // Update cache for relevant filters after uploading
      await updateCacheForFilters(['latest', 'trending'], userId);
    } catch (e) {
      print("Error uploading post: $e");
      throw _handleError(e);
    }
  }

  // Update the like count in cache
  Future<void> updateLikeCache(String postId, int newLikeCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = [
        'cached_posts_latest',
        'cached_posts_trending',
        'cached_posts_following'
      ];

      for (final key in cacheKeys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          final posts = _parsePosts(cachedData);
          final updatedPosts = posts.map((post) {
            if (post.fotoId == postId) {
              return post.copyWith(likes: newLikeCount);
            }
            return post;
          }).toList();

          await prefs.setString(key, jsonEncode(updatedPosts));
        }
      }

      // Update user-specific cache
      final allKeys = prefs.getKeys();
      final userCacheKeys =
          allKeys.where((key) => key.startsWith('cached_posts_user_'));

      for (final key in userCacheKeys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          final posts = _parsePosts(cachedData);
          final updatedPosts = posts.map((post) {
            if (post.fotoId == postId) {
              return post.copyWith(likes: newLikeCount);
            }
            return post;
          }).toList();

          await prefs.setString(key, jsonEncode(updatedPosts));
        }
      }
    } catch (e) {
      print('Error updating like cache: $e');
    }
  }

  // Get the actual like count from Firestore
  Future<int> getLikeCount(String postId) async {
    try {
      final likesQuery = await _firestore
          .collection('koleksi_likes')
          .where('fotoId', isEqualTo: postId)
          .count()
          .get();

      return likesQuery.count ?? 0;
    } catch (e) {
      print('Error getting like count: $e');
      return 0;
    }
  }

  Future<List<Post>> getFollowingPosts(List<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }

    try {
      // Check cache first
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'cached_posts_following';
      final cachedData = prefs.getString(cacheKey);

      // If we have cached data and it's not too old, use it
      if (cachedData != null) {
        final cachedTimestamp = prefs.getInt('${cacheKey}_timestamp');
        final now = DateTime.now().millisecondsSinceEpoch;

        // Cache is valid for 5 minutes
        if (cachedTimestamp != null && now - cachedTimestamp < 300000) {
          final posts = _parsePosts(cachedData);
          // Filter posts for following users only
          return posts.where((post) => userIds.contains(post.userId)).toList();
        }
      }

      // If no valid cache, fetch from Firestore
      // Split userIds into chunks of 10 due to Firestore 'in' query limitation
      final chunks = <List<String>>[];
      for (var i = 0; i < userIds.length; i += 10) {
        chunks.add(userIds.sublist(
            i, i + 10 > userIds.length ? userIds.length : i + 10));
      }

      // Fetch posts for each chunk and combine results
      final allPosts = <Post>[];
      for (final chunk in chunks) {
        final querySnapshot = await _firestore
            .collection('koleksi_posts')
            .where('userId', whereIn: chunk)
            .orderBy('tanggalUnggah', descending: true)
            .get();

        final posts =
            querySnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
        allPosts.addAll(posts);
      }

      // Sort all posts by upload date
      allPosts.sort((a, b) => b.tanggalUnggah.compareTo(a.tanggalUnggah));

      // Update cache with new data
      await prefs.setString(cacheKey, jsonEncode(allPosts));
      await prefs.setInt(
          '${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Sync like counts periodically
      _periodicLikeSync(allPosts);

      return allPosts;
    } catch (e) {
      print('Error getting following posts: $e');
      throw _handleError(e);
    }
  }

  // Synchronize like count between Firestore and cache
  Future<void> syncLikeCount(String postId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('koleksi_posts').doc(postId);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) return;

        final actualLikeCount = await getLikeCount(postId);

        if (actualLikeCount != postDoc.data()?['likes']) {
          transaction.update(postRef, {'likes': actualLikeCount});
          await updateLikeCache(postId, actualLikeCount);
        }
      });
    } catch (e) {
      print('Error syncing like count: $e');
    }
  }

  // Get posts with filter
  Future<List<Post>> getPosts(String filter, {String? userId}) async {
    try {
      Query query = _firestore.collection('koleksi_posts');

      switch (filter) {
        case 'latest':
          query = query.orderBy('tanggalUnggah', descending: true);
          break;
        case 'trending':
          query = query.orderBy('likes', descending: true);
          break;
        case 'following':
          if (userId == null) {
            throw Exception('User ID is required for following filter');
          }
          final followingUsers = await _getFollowingUsers(userId);
          query = query
              .where('userId', whereIn: followingUsers)
              .orderBy('tanggalUnggah', descending: true);
          break;
        default:
          query = query.orderBy('tanggalUnggah', descending: true);
      }

      final querySnapshot = await query.get();
      final posts =
          querySnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      // Sync like counts periodically rather than every fetch
      _periodicLikeSync(posts);

      return posts;
    } catch (e) {
      print('Error getting posts: $e');
      throw _handleError(e);
    }
  }

  // Get following users
  Future<List<String>> _getFollowingUsers(String userId) async {
    try {
      final followingSnapshot = await _firestore
          .collection('koleksi_follows')
          .doc(userId)
          .collection('userFollowing')
          .get();

      return followingSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting following users: $e');
      return [];
    }
  }

  // Get posts by a specific user
  Future<List<Post>> getPostsByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('koleksi_posts')
          .where('userId', isEqualTo: userId)
          .orderBy('tanggalUnggah', descending: true)
          .get();

      final posts =
          querySnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      return posts;
    } catch (e) {
      print('Error getting user posts: $e');
      throw _handleError(e);
    }
  }

  // Parse posts from cached JSON data
  List<Post> _parsePosts(String data) {
    final parsed = jsonDecode(data);
    return parsed.map<Post>((json) => Post.fromJson(json)).toList();
  }

  // Clear cache (use selectively)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print("Cache cleared.");
  }

  // Periodically synchronize like counts in the background
  void _periodicLikeSync(List<Post> posts) {
    for (var i = 0; i < posts.length; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        syncLikeCount(posts[i].fotoId);
      });
    }
  }

  // Delete a post and its related data
  Future<void> deletePost(String postId) async {
    try {
      final postDoc =
          await _firestore.collection('koleksi_posts').doc(postId).get();
      print('Attempting to delete post: $postId');
      print('Post exists: ${postDoc.exists}');

      if (!postDoc.exists) {
        throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Post dengan ID $postId tidak ditemukan');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final String imageUrl = postData['lokasiFile'] as String? ?? '';
      final batch = _firestore.batch();

      try {
        // Delete image from storage if it exists
        if (imageUrl.isNotEmpty) {
          print('Attempting to delete image: $imageUrl');
          final storageRef = _storage.refFromURL(imageUrl);
          await storageRef.delete();
          print('Image deleted successfully');
        }

        print('Deleting related collections...');

        // Delete comments
        final commentsQuery = await _firestore
            .collection('koleksi_posts')
            .doc(postId)
            .collection('comments')
            .get();
        print('Found ${commentsQuery.docs.length} comments to delete');
        for (var doc in commentsQuery.docs) {
          batch.delete(doc.reference);
        }

        // Delete likes
        final likesQuery = await _firestore
            .collection('koleksi_posts')
            .doc(postId)
            .collection('likes')
            .get();
        print('Found ${likesQuery.docs.length} likes to delete');
        for (var doc in likesQuery.docs) {
          batch.delete(doc.reference);
        }

        // Delete post from all albums that contain it
        print('Searching for albums containing this post...');
        final albumsQuery = await _firestore.collection('koleksi_albums').get();

        for (final albumDoc in albumsQuery.docs) {
          final savedPostRef =
              albumDoc.reference.collection('saved_posts').doc(postId);

          final savedPost = await savedPostRef.get();
          if (savedPost.exists) {
            print('Removing post from album: ${albumDoc.id}');
            batch.delete(savedPostRef);
          }
        }

        // Delete the main post document
        batch.delete(_firestore.collection('koleksi_posts').doc(postId));

        print('Committing batch delete operation...');
        await batch.commit();
        print('Post and related data deleted successfully');

        // Clear the cache after deleting a post
        await clearCache();
      } catch (e) {
        print('Error during deletion process: $e');
        throw _handleError(e);
      }
    } catch (e) {
      print('Error in deletePost: $e');
      throw _handleError(e);
    }
  }

  // Update cache selectively after data changes
  Future<void> updateCacheForFilters(
      List<String> filters, String userId) async {
    for (final filter in filters) {
      await getPosts(filter, userId: userId);
    }
    await getPostsByUser(userId);
  }

  // Handle errors gracefully
  Exception _handleError(dynamic error) {
    print('Handling error: $e');
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return Exception(
              'Anda tidak memiliki izin untuk melakukan operasi ini');
        case 'not-found':
          return Exception('Post tidak ditemukan');
        default:
          return Exception('Terjadi kesalahan: ${error.message}');
      }
    }
    return Exception('Terjadi kesalahan: ${error.toString()}');
  }
}
