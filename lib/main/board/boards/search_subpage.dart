import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gnoo/main/album/albums/album_detail_search.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gnoo/main/album/albums/album_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pages/post_model.dart';
import '../../views/grid/post_info.dart';
import '../../views/grid/reels_view_page.dart';
import '../../profile/profile_user.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;

  final FocusNode _searchFocusNode = FocusNode();

  List<String> _searchHistory = [];
  bool _searchAttempted = false;

  final List<Map<String, dynamic>> _searchSuggestionCards = [
    {
      'title': 'Wallpaper',
      'icon': Icons.wallpaper,
      'query': 'wallpaper'
    }, // Ikon wallpaper yang lebih spesifik
    {
      'title': 'Kristal',
      'icon': Icons.diamond,
      'query': 'kristal'
    }, // Ikon berlian untuk kristal
    {
      'title': 'Cerah',
      'icon': Icons.wb_sunny,
      'query': 'cerah'
    }, // Ikon matahari untuk cerah
    {
      'title': 'Gelap',
      'icon': Icons.brightness_2,
      'query': 'gelap'
    }, // Ikon bulan untuk gelap
    {
      'title': 'Elegan',
      'icon': Icons
          .style, // ikon style lebih umum dan bisa merepresentasikan elegan
      'query': 'Elegan'
    },
    {
      'title': 'Segar',
      'icon': Icons.grass,
      'query': 'segar'
    }, // Ikon garis untuk minimalist
  ];
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSearchHistory();
    Future.delayed(Duration.zero, () {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 1) {
      _getSearchSuggestions(_searchController.text);
    } else {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _getSearchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      String lowerQuery = query.toLowerCase();

      final fotoSnapshot = await _firestore.collection('koleksi_posts').get();
      final albumSnapshot = await _firestore.collection('koleksi_albums').get();
      final userSnapshot = await _firestore.collection('koleksi_users').get();

      Set<String> suggestions = {};

      for (var doc in fotoSnapshot.docs) {
        String title = doc['judulFoto'] as String;
        if (title.toLowerCase().contains(lowerQuery)) {
          suggestions.add(title);
        }
      }

      for (var doc in albumSnapshot.docs) {
        String title = doc['judulAlbum'] as String;
        if (title.toLowerCase().contains(lowerQuery)) {
          suggestions.add(title);
        }
      }

      for (var doc in userSnapshot.docs) {
        String username = doc['username'] as String;
        if (username.toLowerCase().contains(lowerQuery)) {
          suggestions.add(username);
        }
      }

      List<String> sortedSuggestions = suggestions.toList()
        ..sort((a, b) {
          bool aStartsWith = a.toLowerCase().startsWith(lowerQuery);
          bool bStartsWith = b.toLowerCase().startsWith(lowerQuery);
          if (aStartsWith && !bStartsWith) return -1;
          if (!aStartsWith && bStartsWith) return 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });

      // Only show suggestions if we haven't performed a search yet
      if (!_isLoading && _searchResults.isEmpty) {
        setState(() {
          _searchSuggestions = sortedSuggestions.take(5).toList();
          _showSuggestions = _searchSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error getting search suggestions: $e');
    }
  }

  Future<void> _performSearch(String query, {bool unfocus = false}) async {
    // Clear suggestions immediately when performing a search
    setState(() {
      _searchAttempted = true;
      _searchSuggestions = [];
      _showSuggestions = false;
    });

    // If query is empty, set empty results but with proper UI state
    if (query.isEmpty) {
      setState(() {
        _searchResults = []; // Empty results
        _isLoading = false;
      });
      return;
    }

    // Add the query to search history if it's not already there
    if (!_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 5) {
          _searchHistory.removeLast();
        }
      });
      // Save the updated search history to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('searchHistory', _searchHistory);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String lowerQuery = query.toLowerCase();

      final results = await Future.wait([
        _firestore.collection('koleksi_posts').get(),
        _firestore.collection('koleksi_albums').get(),
        _firestore.collection('koleksi_users').get(),
      ]);

      List<Map<String, dynamic>> searchResults = [];

      final posts = results[0].docs.where((doc) {
        final title = doc['judulFoto'] as String;
        return title.toLowerCase().contains(lowerQuery);
      }).map((doc) => {
            ...doc.data(),
            'id': doc.id,
            'type': 'post',
          });

      final albums = results[1].docs.where((doc) {
        final title = doc['judulAlbum'] as String;
        return title.toLowerCase().contains(lowerQuery);
      }).map((doc) => {
            ...doc.data(),
            'id': doc.id,
            'type': 'album',
            'albumId': doc.id,
            'judulAlbum': doc['judulAlbum'],
            'deskripsiAlbum': doc['deskripsiAlbum'],
            'userId': doc['userId'],
            'createdAt': doc['createdAt'],
          });

      final users = results[2].docs.where((doc) {
        final username = doc['username'] as String;
        return username.toLowerCase().contains(lowerQuery);
      }).map((doc) => {
            ...doc.data(),
            'id': doc.id,
            'type': 'user',
          });

      searchResults.addAll(users);
      searchResults.addAll(albums);
      searchResults.addAll(posts);

      setState(() {
        _searchResults = searchResults;
        _isLoading = false;
        if (unfocus) {
          _searchFocusNode.unfocus();
        }
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() {
        _isLoading = false;
        _searchResults = []; // Ensure empty results on error
      });
    }
  }

  Widget _buildSearchBar() {
    return SearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      padding: const MaterialStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 16.0),
      ),
      leading: const Icon(Icons.search),
      trailing: <Widget>[
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResults = [];
                _searchSuggestions = [];
                _showSuggestions = false;
                _searchAttempted = false;
              });
            },
          ),
      ],
      hintText: 'Cari postingan, album, atau pengguna...',
      onSubmitted: (value) => _performSearch(value),
      elevation: const MaterialStatePropertyAll<double>(1),
      backgroundColor: MaterialStatePropertyAll<Color>(
        Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
      ),
      overlayColor: MaterialStatePropertyAll<Color>(
        Theme.of(context).colorScheme.surfaceVariant,
      ),
      shape: MaterialStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (!_showSuggestions) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {},
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _searchSuggestions.map((suggestion) {
            return ListTile(
              leading: const Icon(Icons.search),
              title: Text(suggestion),
              onTap: () {
                _searchController.text = suggestion;
                _performSearch(suggestion);
                setState(() {
                  _showSuggestions = false;
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchAttempted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada hasil ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coba kata kunci lain atau periksa ejaan Anda',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_searchResults.any((item) => item['type'] == 'user')) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._searchResults
              .where((item) => item['type'] == 'user')
              .map((user) => _buildUserTile(user))
              .toList(),
        ],
        if (_searchResults.any((item) => item['type'] == 'album')) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Albums',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _searchResults
                  .where((item) => item['type'] == 'album')
                  .length,
              itemBuilder: (context, index) {
                final albums = _searchResults
                    .where((item) => item['type'] == 'album')
                    .map((albumData) => Album.fromMap(albumData))
                    .toList();
                return _buildAlbumCard(context, albums[index]);
              },
            ),
          ),
        ],
        if (_searchResults.any((item) => item['type'] == 'post')) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              itemCount:
                  _searchResults.where((item) => item['type'] == 'post').length,
              itemBuilder: (context, index) {
                final posts = _searchResults
                    .where((item) => item['type'] == 'post')
                    .toList();
                return _buildPostTile(posts[index]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user['profile_image_url'] != null
            ? CachedNetworkImageProvider(user['profile_image_url'])
            : null,
        child:
            user['profile_image_url'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user['username'] ?? 'Unknown User'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              userId: user['id'],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostTile(Map<String, dynamic> post) {
    final Post currentPost = Post.fromMap(post);
    final List<Post> postsForReels = _searchResults
        .where((item) => item['type'] == 'post')
        .map((postMap) => Post.fromMap(postMap))
        .toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.sharedAxisScale,
            child: ReelsViewPage(
              imageUrl: currentPost.lokasiFile,
              posts: postsForReels,
              initialIndex: postsForReels
                  .indexWhere((p) => p.fotoId == currentPost.fotoId),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: CachedNetworkImage(
              imageUrl: post['lokasiFile'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[300],
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.red),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['judulFoto'] ?? 'Untitled',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                PostInfo(userId: post['userId'], post: currentPost),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () {
        print(
            "Long press on album in search results - Implement your action here");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('koleksi_albums')
                  .doc(album.albumId)
                  .collection('saved_posts')
                  .orderBy('timestamp', descending: false)
                  .limit(4)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Material(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Shimmer.fromColors(
                      baseColor: colorScheme.surfaceVariant,
                      highlightColor:
                          colorScheme.onSurfaceVariant.withOpacity(0.2),
                      child: Container(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print(
                      "Error di FutureBuilder (saved_posts): ${snapshot.error}");
                  return _buildPlaceholderAlbumCard(colorScheme, album);
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildPlaceholderAlbumCard(colorScheme, album);
                }

                final savedPosts = snapshot.data!.docs;
                final List<Widget> imageWidgets = [];

                for (int i = 0; i < 4; i++) {
                  if (i < savedPosts.length) {
                    final fotoId = savedPosts[i]['fotoId'];

                    imageWidgets.add(
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('koleksi_posts')
                            .doc(fotoId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Shimmer.fromColors(
                                baseColor: colorScheme.surfaceVariant,
                                highlightColor: colorScheme.onSurfaceVariant
                                    .withOpacity(0.2),
                                child: Container(
                                    color: colorScheme.surfaceVariant),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            print(
                                "Error di Inner FutureBuilder (koleksi_posts): ${snapshot.error}");
                            return _buildPlaceholderImage(colorScheme);
                          }

                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return _buildPlaceholderImage(colorScheme);
                          }

                          final post = snapshot.data!;
                          final imageUrl = post['lokasiFile'];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: colorScheme.surfaceVariant,
                                highlightColor: colorScheme.onSurfaceVariant
                                    .withOpacity(0.2),
                                child: Container(
                                    color: colorScheme.surfaceVariant),
                              ),
                              errorWidget: (context, url, error) {
                                print("Error loading image: $error");
                                return _buildPlaceholderImage(colorScheme);
                              },
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    imageWidgets.add(_buildPlaceholderImage(colorScheme));
                  }
                }
                return Material(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.sharedAxisScale,
                          child: AlbumDetailPageUser(album: album),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GridView.count(
                        crossAxisCount: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: imageWidgets,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              album.judulAlbum,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAlbumCard(ColorScheme colorScheme, Album album) {
    return Material(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          print('Album tapped: ${album.judulAlbum}');
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: List.generate(4, (index) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSuggestionCards() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_searchResults.isNotEmpty || _showSuggestions) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Kamu mungkin suka',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid of suggestion cards
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchSuggestionCards.length,
            itemBuilder: (context, index) {
              final suggestion = _searchSuggestionCards[index];
              return InkWell(
                onTap: () {
                  _searchController.text = suggestion['query'];
                  _performSearch(suggestion['query'], unfocus: true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          suggestion['icon'],
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestion['title'],
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Riwayat Pencarian',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchHistory.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(_searchHistory[index]),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  setState(() {
                    _searchHistory.removeAt(index);
                  });
                  // Save the updated search history to SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('searchHistory', _searchHistory);
                },
              ),
              onTap: () {
                _searchController.text = _searchHistory[index];
                _performSearch(_searchHistory[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('searchHistory') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSuggestions = false;
        });
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildSearchBar(),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_searchAttempted)
              _buildSearchResults()
            else if (_searchResults.isNotEmpty)
              _buildSearchResults()
            else
              SingleChildScrollView(
                child: Column(
                  children: [
                    if (_searchHistory.isNotEmpty) _buildSearchHistory(),
                    _buildSuggestionCards(),
                  ],
                ),
              ),
            if (_showSuggestions) _buildSuggestionsList(),
          ],
        ),
      ),
    );
  }
}
