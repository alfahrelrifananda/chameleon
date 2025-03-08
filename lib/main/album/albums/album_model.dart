import 'package:cloud_firestore/cloud_firestore.dart';

class Album {
  final String? albumId; // Now nullable
  final String judulAlbum;
  final String deskripsiAlbum;
  final String userId;
  final Timestamp createdAt;

  Album({
    this.albumId, // Allow null
    required this.judulAlbum,
    required this.deskripsiAlbum,
    required this.userId,
    required this.createdAt,
  });

  factory Album.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Album(
      albumId: data['albumId'], // Can be null
      judulAlbum: data['judulAlbum'],
      deskripsiAlbum: data['deskripsiAlbum'],
      userId: data['userId'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Tambahkan factory constructor fromMap di sini
  factory Album.fromMap(Map<String, dynamic> map) {
    return Album(
      albumId: map['albumId'],
      judulAlbum: map['judulAlbum'],
      deskripsiAlbum: map['deskripsiAlbum'],
      userId: map['userId'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Album copyWith({
    String? albumId,
    String? judulAlbum,
    String? deskripsiAlbum,
    String? userId,
    Timestamp? createdAt,
  }) {
    return Album(
      albumId: albumId ?? this.albumId,
      judulAlbum: judulAlbum ?? this.judulAlbum,
      deskripsiAlbum: deskripsiAlbum ?? this.deskripsiAlbum,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
