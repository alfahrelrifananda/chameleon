import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'message_selection_subpage.dart';

class AIPage extends StatefulWidget {
  const AIPage({Key? key}) : super(key: key);

  @override
  _AIPageState createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  static const String _storageKey = 'koleksi_chat_messages';

  final String _apiKey = "AIzaSyDGdimQUrUUYk_hp16C1IUBtPZK-0I2_dw";

  // Add a list of suggestion questions
  final List<String> _suggestions = [
    'Apa itu kecerdasan buatan?',
    'Bagaimana cara kerja machine learning?',
    'Apa perbedaan AI dan machine learning?',
    'Apa aplikasi AI dalam kehidupan sehari-hari?',
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_storageKey);
      if (messagesJson != null) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        setState(() {
          _messages.clear();
          _messages.addAll(
            decoded.map((msg) => ChatMessage(
                  text: msg['text'],
                  isUser: msg['isUser'],
                  timestamp: DateTime.parse(msg['timestamp']),
                )),
          );
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String messagesJson = jsonEncode(
        _messages
            .map((msg) => {
                  'text': msg.text,
                  'isUser': msg.isUser,
                  'timestamp': msg.timestamp.toIso8601String(),
                })
            .toList(),
      );
      await prefs.setString(_storageKey, messagesJson);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _saveMessages(); // Save after adding user message
    _scrollToBottom();

    _generateAIResponse(text).then((aiResponse) {
      setState(() {
        _isLoading = false;
        _messages.insert(0, ChatMessage(text: aiResponse, isUser: false));
        // Limit the number of messages stored in memory
        if (_messages.length > 50) {
          _messages.removeRange(50, _messages.length);
        }
      });
      _saveMessages(); // Save after adding AI response
      _scrollToBottom();
    });
  }

  Future<String> _generateAIResponse(String userInput) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$_apiKey');

    final headers = {'Content-Type': 'application/json'};

    // Create a list of previous messages
    List<Map<String, dynamic>> previousMessages = [];
    for (int i = 0; i < _messages.length && i < 5; i++) {
      previousMessages.add({
        "parts": [
          {"text": _messages[i].text}
        ],
        "role": _messages[i].isUser ? "user" : "model"
      });
    }

    // Add the current user input
    previousMessages.add({
      "parts": [
        {"text": userInput}
      ],
      "role": "user"
    });

    final body = jsonEncode({
      "contents": previousMessages.reversed.toList(),
      "generationConfig": {
        "temperature": 0.7,
        "topK": 1,
        "topP": 1,
        "maxOutputTokens": 2048,
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] ??
              'Maaf, saya tidak dapat memproses permintaan Anda saat ini.';
        }
        return 'Maaf, saya tidak dapat memahami respons dari AI.';
      } else {
        print('Error Response: ${response.body}');
        return response.statusCode == 400
            ? 'Terjadi kesalahan dalam format permintaan. Mohon coba lagi.'
            : 'Error ${response.statusCode}: Mohon coba lagi nanti.';
      }
    } catch (e) {
      print('Exception caught: $e');
      return 'Terjadi kesalahan jaringan. Mohon periksa koneksi Anda.';
    }
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Chat',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
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
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.onSurfaceVariant,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              child: Text('Batal'),
                            ),
                            SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove(_storageKey);
                                setState(() {
                                  _messages.clear();
                                });
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
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
            },
            tooltip: 'Hapus riwayat chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeMessageWithSuggestions(colorScheme)
                : _buildChatList(colorScheme),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 12.0,
                ),
                child: _buildInputField(colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessageWithSuggestions(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Selamat datang di AI Assistant!\nSilakan ajukan pertanyaan Anda.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
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
            child: Icon(Icons.auto_awesome,
                color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: colorScheme.surfaceVariant,
              highlightColor: colorScheme.surface,
              child: Container(
                height: 100,
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

  Widget _buildChatList(ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == 0) {
          return _buildLoadingIndicator(colorScheme);
        }
        return _messages[_isLoading ? index - 1 : index];
      },
    );
  }

  // Widget _buildTypingIndicator(ColorScheme colorScheme) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.start,
  //       children: [
  //         CircleAvatar(
  //           backgroundColor: colorScheme.secondaryContainer,
  //           child: Icon(Icons.auto_awesome,
  //               color: colorScheme.onSecondaryContainer),
  //         ),
  //         const SizedBox(width: 8),
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: colorScheme.secondaryContainer,
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           child: Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               _buildDot(colorScheme),
  //               const SizedBox(width: 4),
  //               _buildDot(colorScheme),
  //               const SizedBox(width: 4),
  //               _buildDot(colorScheme),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildDot(ColorScheme colorScheme) {
  //   return Container(
  //     width: 8,
  //     height: 8,
  //     decoration: BoxDecoration(
  //       color: colorScheme.onSecondaryContainer.withOpacity(0.5),
  //       shape: BoxShape.circle,
  //     ),
  //   );
  // }

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final textTheme = Theme.of(context).textTheme;
                    return TextField(
                      controller: _textController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan apa saja...',
                        hintStyle:
                            TextStyle(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
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
                        padding: const EdgeInsets.all(8),
                      ),
                      icon: Icon(
                        Icons.send_rounded,
                        color: hasText
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant.withOpacity(0.5),
                        size: 24,
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

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  late final DateTime timestamp;

  ChatMessage({
    Key? key,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : super(key: key) {
    this.timestamp = timestamp ?? DateTime.now();
  }

  bool _hasCodeBlocks(String text) {
    final RegExp codeBlockExp =
        RegExp(r'\`\`\`(\w*)\n(.*?)\n\`\`\`', dotAll: true);
    return codeBlockExp.hasMatch(text);
  }

  List<Widget> _parseContent(String text, TextStyle defaultStyle) {
    final List<Widget> widgets = [];
    final RegExp codeBlockExp = RegExp(r'```(\w*)\n(.*?)```', dotAll: true);
    // ignore: unused_local_variable
    final RegExp boldExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    codeBlockExp.allMatches(text).forEach((codeMatch) {
      // Add text before code block
      if (codeMatch.start > start) {
        final beforeText = text.substring(start, codeMatch.start);
        widgets.add(_buildRichText(beforeText, defaultStyle));
      }

      // Add code block
      final language = codeMatch.group(1) ?? '';
      final code = codeMatch.group(2) ?? '';
      widgets.add(_buildCodeBlock(language, code));

      start = codeMatch.end;
    });

    // Add remaining text after last code block
    if (start < text.length) {
      widgets.add(_buildRichText(text.substring(start), defaultStyle));
    }

    return widgets;
  }

  Widget _buildRichText(String text, TextStyle defaultStyle) {
    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: _parseBoldSpans(text),
      ),
    );
  }

  Widget _buildCodeBlock(String language, String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                language,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
          SelectableText(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseBoldSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    boldExp.allMatches(text).forEach((match) {
      // Add text before bold
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));

      start = match.end;
    });

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  void _showMessageOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: colorScheme.surface,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      Icons.copy,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      'Lihat & Salin',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessageSelectionPage(
                            message: text,
                            isUser: isUser,
                            hasCodeBlocks: _hasCodeBlocks(text),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      Icons.content_copy,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      'Salin',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.copy_all,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Pesan disalin ke clipboard'),
                          backgroundColor: colorScheme.primaryContainer,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(Icons.auto_awesome,
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
                    ..._parseContent(
                      text,
                      TextStyle(
                        color: isUser
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timestamp.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : colorScheme.onSecondaryContainer.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child:
                    Icon(Icons.person, color: colorScheme.onPrimaryContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
