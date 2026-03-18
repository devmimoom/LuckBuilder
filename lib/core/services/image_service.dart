import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/app_ux.dart'; // 引用您的 UX 工具箱

class ImageService {
  // 單例模式
  static final ImageService _instance = ImageService._();
  factory ImageService() => _instance;
  ImageService._();

  final ImagePicker _picker = ImagePicker();

  /// 啟動拍照流程 (包含壓縮)
  /// context 用於顯示提示
  /// 回傳：處理好的 File，如果取消則回傳 null
  Future<File?> pickAndCompressImage(BuildContext context, {bool fromCamera = true}) async {
    try {
      // 1. 選擇圖片來源
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      
      // 2. 呼叫相機/相簿
      // image_picker 會自動處理模擬器相機崩潰的問題 (它會回傳錯誤或無反應，但我們最好做個防呆)
      // 固定使用後置鏡頭，不允許切換（雖然系統界面可能仍顯示切換按鈕，但我們已設置預設為後置）
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear, // 固定使用後置鏡頭
        // 注意：image_picker 使用系統相機界面，無法完全隱藏切換按鈕
        // 但我們已設置預設為後置鏡頭，用戶需要手動切換才會使用前置鏡頭
      );

      if (pickedFile == null) {
        // 使用者取消拍照
        return null;
      }

      // 3. 顯示正在處理的提示 (UX 優化)
      if (context.mounted) {
        AppUX.showSnackBar(context, "正在處理圖片...");
      }

      // 4. 執行壓縮
      final File compressedFile = await _compressImage(File(pickedFile.path));
      
      return compressedFile;

    } catch (e) {
      debugPrint("拍照錯誤: $e");
      // 簡單的模擬器防呆：如果 Crash，通常是因為模擬器沒相機
      if (e.toString().contains("camera_access_denied") || e.toString().contains("Source not supported")) {
        if (context.mounted) {
          AppUX.showSnackBar(context, "此裝置不支援相機，請改用相簿", isError: true);
        }
      } else {
        if (context.mounted) {
          AppUX.showSnackBar(context, "讀取圖片失敗，請重試", isError: true);
        }
      }
      return null;
    }
  }

  /// 私有方法：圖片壓縮邏輯
  Future<File> _compressImage(File file) async {
    final directory = await getApplicationDocumentsDirectory();
    // 產生唯一檔名
    final fileName = 'mistake_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = p.join(directory.path, fileName);

    // 執行壓縮
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75, // 品質 75
      minWidth: 1920, // 解析度 Full HD
      minHeight: 1080,
    );

    // 如果壓縮失敗 (極少見)，回傳原圖
    return result != null ? File(result.path) : file;
  }
}

