import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({Key? key}) : super(key: key);

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isLoading = false;
  double _deletionProgress = 0.0;
  int _confirmationStep = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showConfirmationBottomSheet() {
    setState(() {
      _confirmationStep++;
    });

    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getConfirmationTitle(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              SizedBox(height: 16),
              Text(
                _getConfirmationMessage(),
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(_getButtonText()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        if (_confirmationStep < 3) {
          _showConfirmationBottomSheet();
        } else {
          _deleteAccount();
        }
      } else {
        setState(() {
          _confirmationStep--;
        });
      }
    });
  }

  String _getConfirmationTitle() {
    switch (_confirmationStep) {
      case 1:
        return 'Hapus Akun?';
      case 2:
        return 'Yakin Ingin Melanjutkan?';
      case 3:
        return 'Konfirmasi Terakhir';
      default:
        return '';
    }
  }

  String _getConfirmationMessage() {
    switch (_confirmationStep) {
      case 1:
        return 'Aksi ini akan menghapus semua data pribadi Anda dari aplikasi secara permanen.';
      case 2:
        return 'Sekali lagi, semua data Anda akan dihapus dan tidak dapat dikembalikan.';
      case 3:
        return 'Anda yakin 100% ingin menghapus akun? Semua data akan hilang selamanya.';
      default:
        return '';
    }
  }

  String _getButtonText() {
    switch (_confirmationStep) {
      case 1:
        return 'Lanjutkan';
      case 2:
        return 'Konfirmasi';
      case 3:
        return 'Hapus Akun';
      default:
        return '';
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
      _deletionProgress = 0.0;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final String userId = currentUser.uid;

        // Menghapus data pengguna dari Firestore dengan progress
        await _deleteUserData(userId);

        // Menghapus akun pengguna
        await currentUser.delete();

        // Menghapus shared preferences
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Update progress ke 100%
        setState(() {
          _deletionProgress = 1.0;
        });

        // Tunggu sebentar untuk menampilkan progress 100%
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigasi ke layar login
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menghapus akun: $e');
      setState(() {
        _isLoading = false;
        _deletionProgress = 0.0;
      });
    }
  }

  Future<void> _deleteUserData(String userId) async {
    // Daftar operasi penghapusan
    final List<Future Function()> deletionTasks = [
      () async {
        // Hapus profil pengguna
        await _firestore.collection('koleksi_users').doc(userId).delete();
        _updateProgress(0.1);
      },
      () async {
        // Hapus posting pengguna
        final postsQuery = await _firestore
            .collection('koleksi_posts')
            .where('userId', isEqualTo: userId)
            .get();
        for (var doc in postsQuery.docs) {
          await doc.reference.delete();
        }
        _updateProgress(0.2);
      },
      () async {
        // Hapus komentar pengguna
        final commentsQuery = await _firestore
            .collection('koleksi_comments')
            .where('userId', isEqualTo: userId)
            .get();
        for (var doc in commentsQuery.docs) {
          await doc.reference.delete();
        }
        _updateProgress(0.3);
      },
      () async {
        // Hapus like pengguna
        final likesQuery = await _firestore
            .collection('koleksi_likes')
            .where('userId', isEqualTo: userId)
            .get();
        for (var doc in likesQuery.docs) {
          await doc.reference.delete();
        }
        _updateProgress(0.4);
      },
      () async {
        // Hapus album pengguna
        final albumsQuery = await _firestore
            .collection('koleksi_albums')
            .where('userId', isEqualTo: userId)
            .get();
        for (var doc in albumsQuery.docs) {
          await doc.reference.delete();
        }
        _updateProgress(0.5);
      },
      () async {
        // Hapus pesan pengguna
        final messagesQuery = await _firestore
            .collection('koleksi_messages')
            .where('senderId', isEqualTo: userId)
            .get();
        for (var doc in messagesQuery.docs) {
          await doc.reference.delete();
        }
        _updateProgress(0.6);
      },
      () async {
        // Hapus followers dan following
        await _deleteFollowData(userId);
        _updateProgress(0.8);
      },
      () async {
        // Hapus data tambahan
        await _firestore.collection('user_tokens').doc(userId).delete();
        await _firestore
            .collection('koleksi_archived_chats')
            .doc(userId)
            .delete();
        await _removeUserFromOtherUsersFollowLists(userId);
        _updateProgress(1.0);
      },
    ];

    // Jalankan semua tugas penghapusan
    for (var task in deletionTasks) {
      await task();
    }
  }

  void _updateProgress(double progress) {
    setState(() {
      _deletionProgress = progress;
    });
  }

  Future<void> _deleteFollowData(String userId) async {
    // Hapus followers
    final followersSnapshot = await _firestore
        .collection('koleksi_follows')
        .doc(userId)
        .collection('userFollowers')
        .get();
    for (var doc in followersSnapshot.docs) {
      await doc.reference.delete();
    }

    // Hapus following
    final followingSnapshot = await _firestore
        .collection('koleksi_follows')
        .doc(userId)
        .collection('userFollowing')
        .get();
    for (var doc in followingSnapshot.docs) {
      await doc.reference.delete();
    }

    // Hapus dokumen utama follows
    await _firestore.collection('koleksi_follows').doc(userId).delete();
  }

  Future<void> _removeUserFromOtherUsersFollowLists(String userId) async {
    final allUsersSnapshot =
        await _firestore.collection('koleksi_follows').get();

    for (var userDoc in allUsersSnapshot.docs) {
      // Hapus dari following list
      final followingDoc =
          await userDoc.reference.collection('userFollowing').doc(userId).get();
      if (followingDoc.exists) {
        await followingDoc.reference.delete();
      }

      // Hapus dari followers list
      final followerDoc =
          await userDoc.reference.collection('userFollowers').doc(userId).get();
      if (followerDoc.exists) {
        await followerDoc.reference.delete();
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Akun'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: colorScheme.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _deletionProgress,
                    backgroundColor: colorScheme.surfaceVariant,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Menghapus Akun...',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_deletionProgress * 100).toStringAsFixed(0)}%',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hapus Akun',
                    style: textTheme.displaySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Anda akan diarahkan untuk mengkonfirmasi penghapusan akun dalam 3 tahap',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      _confirmationStep = 0;
                      _showConfirmationBottomSheet();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      minimumSize: const Size(200, 56),
                    ),
                    child: const Text('Mulai Hapus Akun'),
                  ),
                ],
              ),
            ),
    );
  }
}
