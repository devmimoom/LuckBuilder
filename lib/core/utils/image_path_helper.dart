import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImagePathHelper {
  /// 取得應用程式的文件資料夾路徑
  static Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// 取得圖片儲存資料夾（如果不存在則建立）
  static Future<Directory> getImagesDirectory() async {
    final documentsDir = await getDocumentsDirectory();
    final imagesDir = Directory(path.join(documentsDir.path, 'mistake_images'));
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    return imagesDir;
  }

  /// 儲存圖片並回傳路徑
  /// [sourceFile] 是原始圖片檔案
  /// 回傳儲存後的新路徑
  static Future<String> saveImage(File sourceFile) async {
    final imagesDir = await getImagesDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'mistake_$timestamp${path.extension(sourceFile.path)}';
    final newPath = path.join(imagesDir.path, fileName);
    
    // 複製檔案到新位置
    await sourceFile.copy(newPath);
    
    return newPath;
  }

  /// 解析儲存的圖片路徑
  /// 有些平台在重裝/還原後，App container 的絕對路徑可能改變，
  /// 這裡會優先嘗試用檔名回推目前的永久圖片位置。
  static Future<String> resolveStoredImagePath(String imagePath) async {
    if (imagePath.isEmpty || imagePath.startsWith('assets/')) {
      return imagePath;
    }

    final normalizedPath = path.normalize(imagePath);
    final originalFile = File(normalizedPath);
    if (await originalFile.exists()) {
      return normalizedPath;
    }

    final fileName = path.basename(normalizedPath);
    if (fileName.isEmpty) {
      return normalizedPath;
    }

    final imagesDir = await getImagesDirectory();
    final currentPermanentPath = path.join(imagesDir.path, fileName);

    if (await File(currentPermanentPath).exists()) {
      return currentPermanentPath;
    }

    return normalizedPath;
  }

  /// 檢查路徑是否已在永久錯題圖片資料夾內
  static Future<bool> isInPermanentImagesDirectory(String imagePath) async {
    final imagesDir = await getImagesDirectory();
    return path.normalize(imagePath).startsWith(path.normalize(imagesDir.path));
  }

  /// 確保圖片路徑為永久路徑
  /// - assets 路徑：直接回傳
  /// - 已在永久資料夾：直接回傳
  /// - 其他實體檔案路徑：複製到永久資料夾並回傳新路徑
  /// - 檔案不存在：回傳原路徑（避免中斷流程）
  static Future<String> ensurePersistentImagePath(String imagePath) async {
    if (imagePath.isEmpty || imagePath.startsWith('assets/')) {
      return imagePath;
    }

    final resolvedPath = await resolveStoredImagePath(imagePath);

    if (await isInPermanentImagesDirectory(resolvedPath)) {
      return resolvedPath;
    }

    final sourceFile = File(resolvedPath);
    if (!await sourceFile.exists()) {
      return resolvedPath;
    }

    return saveImage(sourceFile);
  }

  /// 刪除圖片檔案
  static Future<void> deleteImage(String imagePath) async {
    final resolvedPath = await resolveStoredImagePath(imagePath);
    final file = File(resolvedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 檢查圖片檔案是否存在
  static Future<bool> imageExists(String imagePath) async {
    final resolvedPath = await resolveStoredImagePath(imagePath);
    final file = File(resolvedPath);
    return await file.exists();
  }
}

