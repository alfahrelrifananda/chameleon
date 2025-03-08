import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String fotoId;
  final String judulFoto;
  final String deskripsiFoto;
  final Timestamp tanggalUnggah;
  final String lokasiFile;
  final String? albumId;
  final String userId;
  final List<String> tags;
  final int? likes;
  final String? username; // Optional username field

  Post({
    required this.fotoId,
    required this.judulFoto,
    required this.deskripsiFoto,
    required this.tanggalUnggah,
    required this.lokasiFile,
    this.albumId,
    required this.userId,
    required this.tags,
    this.likes,
    this.username,
  });

  // Factory constructor to create Post from Firestore document
  factory Post.fromFirestore(DocumentSnapshot doc, [String? username]) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      fotoId: data['fotoId'] ?? '',
      judulFoto: data['judulFoto'] ?? '',
      deskripsiFoto: data['deskripsiFoto'] ?? '',
      tanggalUnggah: data['tanggalUnggah'] as Timestamp? ?? Timestamp.now(),
      lokasiFile: data['lokasiFile'] ?? '',
      albumId: data['albumId'],
      userId: data['userId'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      likes: data['likes'],
      username: username,
    );
  }

  // Factory constructor to create Post from JSON
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      fotoId: json['fotoId'] ?? '',
      judulFoto: json['judulFoto'] ?? '',
      deskripsiFoto: json['deskripsiFoto'] ?? '',
      tanggalUnggah: Timestamp.fromMillisecondsSinceEpoch(
          json['tanggalUnggah'] ?? Timestamp.now().millisecondsSinceEpoch),
      lokasiFile: json['lokasiFile'] ?? '',
      albumId: json['albumId'],
      userId: json['userId'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      likes: json['likes'],
      username: json['username'],
    );
  }

  // Sesuaikan factory constructor fromMap
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      fotoId: map['id'] ?? '', // Sesuaikan dengan ID yang ada di map
      judulFoto: map['judulFoto'] ?? '',
      deskripsiFoto: map['deskripsiFoto'] ?? '',
      tanggalUnggah: map['tanggalUnggah'] ?? Timestamp.now(),
      lokasiFile: map['lokasiFile'] ?? '',
      albumId: map['albumId'],
      userId: map['userId'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      likes: map['likes'], // Atau sesuaikan dengan cara Anda menghitung likes
      username: map['username'],
    );
  }

  // Method to convert Post to JSON
  Map<String, dynamic> toJson() {
    return {
      'fotoId': fotoId,
      'judulFoto': judulFoto,
      'deskripsiFoto': deskripsiFoto,
      'tanggalUnggah': tanggalUnggah.millisecondsSinceEpoch,
      'lokasiFile': lokasiFile,
      'albumId': albumId,
      'userId': userId,
      'tags': tags,
      'likes': likes,
      'username': username,
    };
  }

  // copyWith method untuk membuat salinan Post dengan field yang diperbarui
  Post copyWith({
    String? fotoId,
    String? judulFoto,
    String? deskripsiFoto,
    Timestamp? tanggalUnggah,
    String? lokasiFile,
    String? albumId,
    String? userId,
    List<String>? tags,
    int? likes,
    String? username,
  }) {
    return Post(
      fotoId: fotoId ?? this.fotoId,
      judulFoto: judulFoto ?? this.judulFoto,
      deskripsiFoto: deskripsiFoto ?? this.deskripsiFoto,
      tanggalUnggah: tanggalUnggah ?? this.tanggalUnggah,
      lokasiFile: lokasiFile ?? this.lokasiFile,
      albumId: albumId ?? this.albumId,
      userId: userId ?? this.userId,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      username: username ?? this.username,
    );
  }

  @override
  String toString() {
    return 'Post(fotoId: $fotoId, judulFoto: $judulFoto, likes: $likes)';
  }
}
