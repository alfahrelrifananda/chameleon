import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gnoo/main/album/albums/album_model.dart';

class SaveToAlbumBottomSheet extends StatefulWidget {
  final String postId;
  final String userId;

  const SaveToAlbumBottomSheet({
    Key? key,
    required this.postId,
    required this.userId,
  }) : super(key: key);

  @override
  State<SaveToAlbumBottomSheet> createState() => _SaveToAlbumBottomSheetState();
}

class _SaveToAlbumBottomSheetState extends State<SaveToAlbumBottomSheet>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<String> selectedAlbums = {};
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Tambahkan controller untuk animasi loading
  late AnimationController _loadingAnimController;
  late Animation<double> _loadingAnimation;
  Set<String> _initialSelectedAlbums = {};

  // Cache untuk data album
  List<Album> _cachedAlbums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Inisialisasi controller untuk animasi loading
    _loadingAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    _loadingAnimation = CurvedAnimation(
      parent: _loadingAnimController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Pre-fetch data album dan cek post sudah disimpan di album mana saja
    _fetchAlbumsAndCheckSavedStatus();
  }

  // Method untuk fetch data album dan cek status saved
  // 1. Perbaikan pada method _fetchAlbumsAndCheckSavedStatus()
  Future<void> _fetchAlbumsAndCheckSavedStatus() async {
    setState(() {
      _isLoading = true; // Pastikan loading state diaktifkan
    });

    try {
      // Ambil semua album user
      final snapshot = await _firestore
          .collection('koleksi_albums')
          .where('userId', isEqualTo: widget.userId)
          .get();

      _cachedAlbums =
          snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList();

      // Reset selected albums
      selectedAlbums = {};

      // Cek di album mana saja post ini sudah disimpan
      for (var album in _cachedAlbums) {
        final savedPostDoc = await _firestore
            .collection('koleksi_albums')
            .doc(album.albumId)
            .collection('saved_posts')
            .doc(widget.postId)
            .get();

        if (savedPostDoc.exists && album.albumId != null) {
          selectedAlbums.add(album.albumId!);
        }
      }

      if (mounted) {
        setState(() {
          _initialSelectedAlbums =
              Set.from(selectedAlbums); // Store initial state
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching albums and saved status: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// 2. Perbaikan pada method _updateAlbumSelections
  void _updateAlbumSelections(BuildContext context, String postId,
      Set<String> newSelections, Set<String> initialSelections) async {
    final currentUserId = _auth.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    // PERUBAHAN: Jangan reverse animasi dulu, proses update dahulu
    // await _animationController.reverse();

    try {
      // Albums to add to
      final albumsToAdd = newSelections.difference(initialSelections);

      // Albums to remove from
      final albumsToRemove = initialSelections.difference(newSelections);

      int addedCount = 0;
      int removedCount = 0;

      print("Albums to add: $albumsToAdd"); // Debug info
      print("Albums to remove: $albumsToRemove"); // Debug info

      // Add to new albums
      for (String albumId in albumsToAdd) {
        try {
          final existingDoc = await _firestore
              .collection('koleksi_albums')
              .doc(albumId)
              .collection('saved_posts')
              .doc(postId)
              .get();

          if (!existingDoc.exists) {
            await _firestore
                .collection('koleksi_albums')
                .doc(albumId)
                .collection('saved_posts')
                .doc(postId)
                .set({
              'fotoId': postId,
              'userId': currentUserId,
              'timestamp': FieldValue.serverTimestamp(),
            });

            print("Added post to album: $albumId"); // Debug info
            addedCount++;
          }
        } catch (e) {
          print("Error saving post to album $albumId: $e");
        }
      }

      // Remove from albums
      for (String albumId in albumsToRemove) {
        try {
          await _firestore
              .collection('koleksi_albums')
              .doc(albumId)
              .collection('saved_posts')
              .doc(postId)
              .delete();

          print("Removed post from album: $albumId"); // Debug info
          removedCount++;
        } catch (e) {
          print("Error removing post from album $albumId: $e");
        }
      }

      // PERUBAHAN: Setelah selesai proses update, baru reverse animasi
      if (mounted) {
        await _animationController.reverse();
        Navigator.pop(context);

        if (addedCount > 0 || removedCount > 0) {
          String message = '';
          IconData icon;
          Color backgroundColor;

          if (addedCount > 0 && removedCount > 0) {
            message = 'Perubahan berhasil disimpan';
            icon = Icons.check_circle_outline;
            backgroundColor = colorScheme.primary;
          } else if (addedCount > 0) {
            message = 'Berhasil menyimpan ke $addedCount album';
            icon = Icons.check_circle_outline;
            backgroundColor = colorScheme.primary;
          } else {
            message = 'Foto dihapus dari $removedCount album';
            icon = Icons.delete_outline;
            backgroundColor = colorScheme.secondary;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    icon,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              backgroundColor: backgroundColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Error in _updateAlbumSelections: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat menyimpan perubahan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// 3. Perbaikan pada _buildBottomButton untuk perhitungan hasChanges dan teks button
  Widget _buildBottomButton(ColorScheme colorScheme, TextTheme textTheme) {
    // Determine if any changes have been made
    bool hasChanges = !setEquals(selectedAlbums, _initialSelectedAlbums);

    // Button text based on selection state
    String buttonText;

    if (!hasChanges) {
      buttonText = 'Simpan Perubahan';
    } else if (selectedAlbums.isEmpty) {
      buttonText = 'Hapus dari Semua Album';
    } else {
      buttonText = 'Simpan ke ${selectedAlbums.length} Album';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: FilledButton(
            key: ValueKey<String>(buttonText),
            onPressed: hasChanges
                ? () {
                    _updateAlbumSelections(context, widget.postId,
                        selectedAlbums, _initialSelectedAlbums);
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selectedAlbums.isEmpty
                      ? Icons.delete_outline
                      : Icons.save_outlined,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  buttonText,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Tambahkan ini di awal file atau gunakan import:
// import 'package:collection/collection.dart';
  bool setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _loadingAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(colorScheme, textTheme),
                Expanded(
                  child:
                      _buildAlbumList(scrollController, colorScheme, textTheme),
                ),
                _buildBottomButton(colorScheme, textTheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Simpan ke Album',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedAlbums.isEmpty
                ? 'Pilih album untuk menyimpan foto ini'
                : 'Foto ini tersimpan di ${selectedAlbums.length} album',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAlbumList(ScrollController scrollController,
      ColorScheme colorScheme, TextTheme textTheme) {
    // Gunakan cached data alih-alih stream
    if (_isLoading) {
      return Center(
        child: _buildLoadingIndicator(colorScheme),
      );
    }

    if (_cachedAlbums.isEmpty) {
      return Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                "Belum ada album",
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Buat album baru untuk menyimpan foto",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedList(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      initialItemCount: _cachedAlbums.length,
      itemBuilder: (context, index, animation) {
        final album = _cachedAlbums[index];
        final isSelected = selectedAlbums.contains(album.albumId);

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuint,
              reverseCurve: Curves.easeInQuint,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: _buildAlbumItem(album, isSelected, colorScheme, textTheme),
          ),
        );
      },
    );
  }

  Widget _buildAlbumItem(Album album, bool isSelected, ColorScheme colorScheme,
      TextTheme textTheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuint,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: ListTile(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedAlbums.remove(album.albumId);
              } else {
                selectedAlbums.add(album.albumId!);
              }
            });
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.1)
                  : colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.photo_album_outlined,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            album.judulAlbum,
            style: textTheme.titleMedium?.copyWith(
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.normal,
            ),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Checkbox(
              key: ValueKey<bool>(isSelected),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    selectedAlbums.add(album.albumId!);
                  } else {
                    selectedAlbums.remove(album.albumId);
                  }
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              checkColor: colorScheme.onPrimary,
              activeColor: colorScheme.primary,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: colorScheme.primary,
                value: _loadingAnimController.status == AnimationStatus.forward
                    ? _loadingAnimation.value
                    : null,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Text(
                'Memuat album...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget _buildBottomButton(ColorScheme colorScheme, TextTheme textTheme) {
  //   // Collection of album IDs where the post was initially saved
  //   // final Set<String> initialSelectedAlbums = Set.from(selectedAlbums);

  //   // Determine if any changes have been made
  //   // bool hasChanges = selectedAlbums.length != initialSelectedAlbums.length ||
  //   //     !selectedAlbums
  //   //         .every((element) => initialSelectedAlbums.contains(element));

  //   bool hasChanges = selectedAlbums.length != _initialSelectedAlbums.length ||
  //       !selectedAlbums
  //           .every((element) => _initialSelectedAlbums.contains(element));

  //   // Button text based on selection state
  //   String buttonText = 'Simpan Perubahan';

  //   if (selectedAlbums.isEmpty) {
  //     buttonText = 'Hapus dari Semua Album';
  //   } else if (selectedAlbums.isNotEmpty) {
  //     buttonText = 'Simpan ke ${selectedAlbums.length} Album';
  //   } else if (selectedAlbums.isEmpty) {
  //     buttonText = 'Pilih Album';
  //   }

  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: colorScheme.surface,
  //       borderRadius: const BorderRadius.vertical(
  //         top: Radius.circular(28),
  //       ),
  //       boxShadow: [
  //         BoxShadow(
  //           color: colorScheme.shadow.withOpacity(0.05),
  //           blurRadius: 8,
  //           offset: const Offset(0, -4),
  //         ),
  //       ],
  //     ),
  //     child: AnimatedSize(
  //       duration: const Duration(milliseconds: 200),
  //       curve: Curves.easeInOut,
  //       child: AnimatedSwitcher(
  //         duration: const Duration(milliseconds: 300),
  //         child: FilledButton(
  //           key: ValueKey<String>(buttonText),
  //           onPressed: hasChanges
  //               ? () {
  //                   _updateAlbumSelections(context, widget.postId,
  //                       selectedAlbums, _initialSelectedAlbums);
  //                   Navigator.pop(context);
  //                 }
  //               : null,
  //           style: FilledButton.styleFrom(
  //             backgroundColor: colorScheme.primary,
  //             foregroundColor: colorScheme.onPrimary,
  //             padding: const EdgeInsets.symmetric(vertical: 16),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(16),
  //             ),
  //             elevation: 0,
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(
  //                 selectedAlbums.isEmpty
  //                     ? Icons.delete_outline
  //                     : Icons.save_outlined,
  //                 color: colorScheme.onPrimary,
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 buttonText,
  //                 style: textTheme.titleMedium?.copyWith(
  //                   color: colorScheme.onPrimary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // void _updateAlbumSelections(BuildContext context, String postId,
  //     Set<String> newSelections, Set<String> initialSelections) async {
  //   final currentUserId = _auth.currentUser?.uid;
  //   final colorScheme = Theme.of(context).colorScheme;

  //   // Animasi fade out pada bottom sheet sebelum pop
  //   await _animationController.reverse();

  //   // Albums to add to
  //   final albumsToAdd = newSelections.difference(initialSelections);

  //   // Albums to remove from
  //   final albumsToRemove = initialSelections.difference(newSelections);

  //   int addedCount = 0;
  //   int removedCount = 0;

  //   // Add to new albums
  //   for (String albumId in albumsToAdd) {
  //     try {
  //       final existingDoc = await _firestore
  //           .collection('koleksi_albums')
  //           .doc(albumId)
  //           .collection('saved_posts')
  //           .doc(postId)
  //           .get();

  //       if (!existingDoc.exists) {
  //         await _firestore
  //             .collection('koleksi_albums')
  //             .doc(albumId)
  //             .collection('saved_posts')
  //             .doc(postId)
  //             .set({
  //           'fotoId': postId,
  //           'userId': currentUserId,
  //           'timestamp': FieldValue.serverTimestamp(),
  //         });

  //         addedCount++;
  //       }
  //     } catch (e) {
  //       print("Error saving post to album: $e");
  //     }
  //   }

  //   // Remove from albums
  //   for (String albumId in albumsToRemove) {
  //     try {
  //       await _firestore
  //           .collection('koleksi_albums')
  //           .doc(albumId)
  //           .collection('saved_posts')
  //           .doc(postId)
  //           .delete();

  //       removedCount++;
  //     } catch (e) {
  //       print("Error removing post from album: $e");
  //     }
  //   }

  //   if (mounted) {
  //     if (addedCount > 0 || removedCount > 0) {
  //       String message = '';
  //       IconData icon;
  //       Color backgroundColor;

  //       if (addedCount > 0 && removedCount > 0) {
  //         message = 'Perubahan berhasil disimpan';
  //         icon = Icons.check_circle_outline;
  //         backgroundColor = colorScheme.primary;
  //       } else if (addedCount > 0) {
  //         message = 'Berhasil menyimpan ke $addedCount album';
  //         icon = Icons.check_circle_outline;
  //         backgroundColor = colorScheme.primary;
  //       } else {
  //         message = 'Foto dihapus dari $removedCount album';
  //         icon = Icons.delete_outline;
  //         backgroundColor = colorScheme.secondary;
  //       }

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Row(
  //             children: [
  //               Icon(
  //                 icon,
  //                 color: colorScheme.onPrimary,
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 message,
  //                 style: TextStyle(
  //                   color: colorScheme.onPrimary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           backgroundColor: backgroundColor,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           margin: const EdgeInsets.all(16),
  //           padding: const EdgeInsets.symmetric(
  //             horizontal: 24,
  //             vertical: 16,
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }
}
