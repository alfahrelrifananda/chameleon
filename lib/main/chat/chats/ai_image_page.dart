import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';

import '../../pages/upload_posts.dart';

class ImageGenerationPage extends StatefulWidget {
  const ImageGenerationPage({Key? key}) : super(key: key);

  @override
  _ImageGenerationPageState createState() => _ImageGenerationPageState();
}

class _ImageGenerationPageState extends State<ImageGenerationPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ImageMessage> _messages = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;

  final List<String> _suggestions = [
    'Buatkan gambar pemandangan alam',
    'Buatkan gambar kucing lucu',
    'Buatkan gambar rumah modern',
    'Buatkan gambar mobil sport',
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedMessages = prefs.getString('image_chat_messages');
    if (cachedMessages != null) {
      setState(() {
        _messages = (jsonDecode(cachedMessages) as List)
            .map((item) => ImageMessage.fromJson(item))
            .toList();
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _saveMessagesToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('image_chat_messages', jsonEncode(_messages));
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.insert(0, ImageMessage(prompt: text, isUser: true));
      _isLoading = true;
      _isFirstLoad = false;
    });
    _scrollToBottom();

    _generateImage(text).then((imageBytes) {
      setState(() {
        _isLoading = false;
        _messages.insert(
            0, ImageMessage(prompt: text, isUser: false, image: imageBytes));
      });
      _scrollToBottom();
      _saveMessagesToCache();
    }).catchError((error) {
      setState(() {
        _isLoading = false;
        _messages.insert(
            0, ImageMessage(prompt: 'Error: $error', isUser: false));
      });
      _scrollToBottom();
      _saveMessagesToCache();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<Uint8List> _generateImage(String prompt) async {
    final response = await http.post(
      Uri.parse('https://api.edenai.run/v2/image/generation'),
      headers: {
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2E0Y2EyMzItMjc2Ni00ZmJkLTk1ZjgtMTY0NWNhMDdlNDMyIiwidHlwZSI6ImFwaV90b2tlbiJ9.zCa05RHcqWXbj1ngjtpQWTbTkTZWQ9IkNsIYQG8mU7E',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'providers': 'stabilityai',
        'text': prompt,
        'resolution': '512x512',
        'num_images': 1,
        'response_as_dict': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['stabilityai'] != null &&
          data['stabilityai']['items'] != null &&
          data['stabilityai']['items'].isNotEmpty) {
        final item = data['stabilityai']['items'][0];
        if (item['image_resource_url'] != null) {
          final imageResponse =
              await http.get(Uri.parse(item['image_resource_url']));
          if (imageResponse.statusCode == 200) {
            return imageResponse.bodyBytes;
          }
        }
        if (item['image_base64'] != null) {
          return base64Decode(item['image_base64']);
        }
        if (item['image'] != null) {
          final imageResponse = await http.get(Uri.parse(item['image']));
          if (imageResponse.statusCode == 200) {
            return imageResponse.bodyBytes;
          }
        }
      }
    }
    throw Exception('Failed to generate image');
  }

  // ignore: unused_element
  Future<void> _downloadImage(Uint8List imageBytes) async {
    if (kIsWeb) {
      final base64 = base64Encode(imageBytes);
      html.AnchorElement(href: 'data:image/png;base64,$base64')
        ..setAttribute('download', 'generated_image.png')
        ..click();
    } else {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/generated_image_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(filePath).writeAsBytes(imageBytes);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Image saved to: $filePath')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied to save image')));
      }
    }
  }

  void _clearHistory() {
    showModalBottomSheet(
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
                'Hapus Riwayat Chat?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah Anda yakin ingin menghapus seluruh riwayat chat? Klik batal untuk membatalkan',
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
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                        _isFirstLoad = true;
                      });
                      _saveMessagesToCache();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Visual Generatif',
            style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.onSurface),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isFirstLoad
                ? _buildPlaceholder(colorScheme)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        return _buildLoadingIndicator(colorScheme);
                      }
                      return _messages[_isLoading ? index - 1 : index];
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 12.0,
            ),
            child: _buildInputField(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_high_outlined,
              size: 64, color: colorScheme.primary),
          SizedBox(height: 16),
          Text(
            'Mulai buat gambar!',
            style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            'Ketikkan perintah di bawah untuk membuat gambar.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _buildSuggestionCards(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSuggestionCards(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((suggestion) {
          return Card(
            color: colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () => _handleSubmitted(suggestion),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: MediaQuery.of(context).size.width *
                    0.45, // Set width to about half of the screen width
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  suggestion,
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(Icons.auto_fix_high_rounded,
                color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: colorScheme.surfaceVariant,
              highlightColor: colorScheme.surface,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 12.0,
        bottom: 12.0,
      ),
      color: colorScheme.surface,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center as mentioned in comments
            children: [
              Expanded(
                child: Container(
                  // Added Container as per your comment
                  child: TextField(
                    controller: _textController,
                    maxLines: null, // Kept as null for multiline support
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Deskripsikan gambar ...', // Kept your hint text
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, // Adjusted horizontal padding as noted
                        vertical: 10, // Adjusted vertical padding as noted
                      ),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                    right: 8), // Removed bottom padding as noted
                child: AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    final bool hasText = _textController.text.isNotEmpty;
                    return IconButton(
                      onPressed: hasText
                          ? () => _handleSubmitted(_textController.text)
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: hasText
                            ? colorScheme.primary
                            : colorScheme.surfaceVariant,
                        padding:
                            const EdgeInsets.all(8), // Kept padding as noted
                      ),
                      icon: Icon(
                        Icons.send_rounded,
                        color: hasText
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        size: 20, // Kept your icon size of 20
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageMessage extends StatelessWidget {
  final String prompt;
  final bool isUser;
  final Uint8List? image;

  const ImageMessage({
    Key? key,
    required this.prompt,
    required this.isUser,
    this.image,
  }) : super(key: key);

  factory ImageMessage.fromJson(Map<String, dynamic> json) {
    return ImageMessage(
      prompt: json['prompt'],
      isUser: json['isUser'],
      image: json['image'] != null ? base64Decode(json['image']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'isUser': isUser,
      'image': image != null ? base64Encode(image!) : null,
    };
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.status;
        if (status.isDenied) {
          final result = await Permission.manageExternalStorage.request();
          return result.isGranted;
        }
        return status.isGranted;
      } else {
        final status = await Permission.storage.status;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        return status.isGranted;
      }
    }
    return true;
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Izin Diperlukan'),
          content: Text(
              'Aplikasi memerlukan izin penyimpanan untuk mengunduh gambar. Silakan buka pengaturan aplikasi untuk memberikan izin.'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: Text('Buka Pengaturan'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showWebDownloadInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Unduh Gambar di Web'),
          content: Text(
              'Untuk mengunduh gambar di web, klik kanan pada gambar dan pilih "Simpan gambar sebagai..."'),
          actions: <Widget>[
            TextButton(
              child: Text('Mengerti'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDownload(BuildContext context) async {
    double _downloadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Mengunduh'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 16),
                  Text('${(_downloadProgress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getExternalStorageDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Tidak dapat menemukan direktori unduhan');
      }

      String aiImagePath = '${downloadsDir.path}/Chameleon/AI';
      Directory aiImageDir = Directory(aiImagePath);
      if (!await aiImageDir.exists()) {
        await aiImageDir.create(recursive: true);
      }

      // Mengubah ekstensi file menjadi jpg
      final fileName = 'ai_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('$aiImagePath/$fileName');

      await file.writeAsBytes(image!);

      Navigator.of(context).pop(); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gambar berhasil diunduh ke Download/AI_Images'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () async {
              final result = await OpenFile.open(file.path);
              if (result.type != ResultType.done) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal membuka gambar: ${result.message}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh gambar: $error')),
      );
    }
  }

  Future<void> _downloadImage(BuildContext context) async {
    if (kIsWeb) {
      _showWebDownloadInfo(context);
      return;
    }

    final bool hasPermission = await _requestStoragePermission();

    if (hasPermission) {
      _startDownload(context);
    } else {
      if (await Permission.storage.isPermanentlyDenied ||
          await Permission.manageExternalStorage.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin penyimpanan diperlukan untuk mengunduh'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(Icons.auto_fix_high_rounded,
                  color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primaryContainer
                    : colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt,
                    style: TextStyle(
                      color: isUser
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                  if (image != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullScreenImage(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          image!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh, color: colorScheme.primary),
                          onPressed: () => _regenerateImage(context, prompt),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.download, color: colorScheme.primary),
                          onPressed: () => _downloadImage(context),
                        ),
                        IconButton(
                          icon: Icon(Icons.file_upload,
                              color: colorScheme.primary),
                          onPressed: () async {
                            // ignore: unused_local_variable
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UploadPosts(initialImage: image),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageBytes: image!),
      ),
    );
  }

  void _regenerateImage(BuildContext context, String prompt) {
    final imageGenerationState =
        context.findAncestorStateOfType<_ImageGenerationPageState>();
    if (imageGenerationState != null) {
      imageGenerationState._handleSubmitted(prompt);
    }
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;

  const FullScreenImageViewer({Key? key, required this.imageBytes})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: MemoryImage(imageBytes),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
