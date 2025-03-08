

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageSelectionPage extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool hasCodeBlocks;

  const MessageSelectionPage({
    Key? key,
    required this.message,
    required this.isUser,
    required this.hasCodeBlocks,
  }) : super(key: key);

  List<Widget> _parseContent(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> widgets = [];
    final RegExp codeBlockExp = RegExp(r'```(\w*)\n(.*?)\n```', dotAll: true);
    int start = 0;

    codeBlockExp.allMatches(text).forEach((codeMatch) {
      if (codeMatch.start > start) {
        final beforeText = text.substring(start, codeMatch.start);
        widgets.add(SelectableText(
          beforeText,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
        ));
      }

      final language = codeMatch.group(1) ?? '';
      final code = codeMatch.group(2) ?? '';
      widgets.add(Container(
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
      ));

      start = codeMatch.end;
    });

    if (start < text.length) {
      widgets.add(SelectableText(
        text.substring(start),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isUser ? 'Pesan Anda' : 'Respons AI',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Pesan disalin ke clipboard'),
                  backgroundColor: colorScheme.primaryContainer,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Salin pesan',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hasCodeBlocks
              ? _parseContent(context, message)
              : [
                  SelectableText(
                    message,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}