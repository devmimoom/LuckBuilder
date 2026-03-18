import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../utils/app_ux.dart';

class PremiumImageViewer extends StatelessWidget {
  final String imagePath;
  final String heroTag;

  const PremiumImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 核心縮放圖片區 (Hero 動畫)
          Positioned.fill(
            child: Hero(
              tag: heroTag,
              child: PhotoView(
                imageProvider: FileImage(File(imagePath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white24, size: 64),
                ),
              ),
            ),
          ),

          // 2. 左上角關閉按鈕
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () {
                      AppUX.feedbackClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
