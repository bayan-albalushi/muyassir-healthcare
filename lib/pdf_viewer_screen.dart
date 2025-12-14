import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';

class PDFViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PDFViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  bool _isNetworkUrl(String path) {
    return path.startsWith("http://") || path.startsWith("https://");
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.blueAccent,
      ),

      body: _isNetworkUrl(url)
          ? const PDF(
        swipeHorizontal: true,
      ).cachedFromUrl(url)
          : PDF(
        swipeHorizontal: true,
      ).fromPath(url),
    );
  }
}
