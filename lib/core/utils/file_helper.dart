import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileHelper {
  /// 將圖片壓縮並存入 App 專屬資料夾
  ///
  /// 參數：[originalFile] 原始圖片檔案
  /// 回傳：壓縮後的圖片路徑 (String)
  ///
  /// 針對國中生錯題本優化：確保 LaTeX 文字與幾何圖形在 Full HD 下依然清晰
  static Future<String> saveCompressedImage(File originalFile) async {
    // 1. 取得 App 專屬文件目錄 (保密且不會被相簿清理工具刪除)
    final directory = await getApplicationDocumentsDirectory();

    // 2. 使用時間戳記產生唯一檔名，格式為 .jpg
    final fileName = 'mistake_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = p.join(directory.path, fileName);

    // 3. 執行壓縮與尺寸調整
    final result = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      targetPath,
      quality: 75, // 平衡畫質與檔案大小的最佳點
      minWidth: 1920, // 確保寬度達到 Full HD 等級，利於 OCR 辨識
      minHeight: 1080, // 確保高度足夠，避免細小文字模糊
      format: CompressFormat.jpeg, // 統一使用 jpeg 格式
    );

    if (result == null) {
      throw Exception("圖片壓縮失敗");
    }

    // 4. 回傳新路徑
    return result.path;
  }
}
