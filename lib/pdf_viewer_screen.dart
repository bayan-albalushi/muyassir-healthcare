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

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: Text(title),

        backgroundColor: Colors.blueAccent,

      ),

      body: PDF().cachedFromUrl(

        url,

        placeholder: (progress) => Center(

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const CircularProgressIndicator(),

              const SizedBox(height: 16),

              Text('Loading PDF... $progress%'),

            ],

          ),

        ),

        errorWidget: (error) => Center(

          child: Text(

            'Failed to load PDF:\n$error',

            style: const TextStyle(color: Colors.red),

            textAlign: TextAlign.center,

          ),

        ),

      ),

    );

  }

}
