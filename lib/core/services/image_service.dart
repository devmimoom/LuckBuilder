import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_fonts.dart';
import '../utils/app_ux.dart';

class ImageService {
  // 單例模式
  static final ImageService _instance = ImageService._();
  factory ImageService() => _instance;
  ImageService._();

  final ImagePicker _picker = ImagePicker();

  /// 啟動拍照流程 (包含壓縮)
  /// context 用於顯示提示
  /// 回傳：處理好的 File，如果取消則回傳 null
  Future<File?> pickAndCompressImage(BuildContext context,
      {bool fromCamera = true}) async {
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
      final message = e.toString();
      final isSimulatorNoCamera =
          message.contains("Source not supported") && fromCamera;
      final isCameraPermissionDenied = fromCamera &&
          (message.contains("camera_access_denied") ||
              message.contains("CameraAccessDenied") ||
              message.contains("permission_denied"));

      if (context.mounted) {
        if (isSimulatorNoCamera) {
          AppUX.showSnackBar(
            context,
            "此裝置不支援相機（例如模擬器），請改用相簿",
            isError: true,
          );
        } else if (isCameraPermissionDenied) {
          _showCameraPermissionDeniedDialog(context);
        } else {
          AppUX.showSnackBar(context, "讀取圖片失敗，請重試", isError: true);
        }
      }
      return null;
    }
  }

  /// 相機權限被關閉時，說明如何到系統設定重新開啟。
  static Future<void> _showCameraPermissionDeniedDialog(
    BuildContext context,
  ) async {
    final instruction = Platform.isIOS
        ? '1. 開啟「設定」\n'
            '2. 向下捲動並點選「LuckLab」\n'
            '3. 點選「相機」\n'
            '4. 改為「允許」後回到本 App 再試一次'
        : '1. 開啟「設定」\n'
            '2. 依序進入「應用程式」→「LuckLab」\n'
            '3. 點選「權限」→「相機」\n'
            '4. 改為「允許」後回到本 App 再試一次';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '相機權限已關閉',
          style: AppFonts.resolve(
            const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            instruction,
            style: AppFonts.resolve(
              const TextStyle(
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '關閉',
              style: AppFonts.resolve(
                const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _openAppSettingsPage(context);
            },
            child: Text(
              '前往設定',
              style: AppFonts.resolve(
                const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS：`app_settings` 會先 `canOpenURL`，在部分系統上會誤判而完全不開啟。
  /// 改以 `url_launcher` 開啟 `app-settings:`（等同系統「此 App 的設定」）。
  /// Android：仍用 `AppSettings.openAppSettings()`（走 `ACTION_APPLICATION_DETAILS_SETTINGS`）。
  static Future<void> _openAppSettingsPage(BuildContext context) async {
    void showOpenFailed() {
      if (context.mounted) {
        AppUX.showSnackBar(
          context,
          '無法自動開啟設定，請手動到「設定」找到本 App，並開啟「相機」權限',
          isError: true,
        );
      }
    }

    await Future<void>.delayed(Duration.zero);
    try {
      if (Platform.isIOS) {
        final uri = Uri.parse('app-settings:');
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!ok) showOpenFailed();
        return;
      }
      await AppSettings.openAppSettings();
    } catch (_) {
      showOpenFailed();
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
