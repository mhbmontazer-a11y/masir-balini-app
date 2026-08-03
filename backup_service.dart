import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/app_database.dart';

class BackupResult {
  const BackupResult({required this.success, this.path, this.error});

  final bool success;
  final String? path;
  final String? error;
}

class BackupService {
  BackupService(this.database);

  final AppDatabase database;

  Future<BackupResult> createBackup() async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'پشتیبان_مسیر_بالینی_$date.masirbackup';
    try {
      final bytes = await database.readDatabaseBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره فایل پشتیبان',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['masirbackup'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null) {
        return const BackupResult(success: false, error: 'عملیات ذخیره لغو شد.');
      }
      return BackupResult(success: true, path: path);
    } catch (e) {
      return BackupResult(success: false, error: e.toString());
    }
  }

  Future<BackupResult> restoreBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'انتخاب فایل پشتیبان',
        type: FileType.custom,
        allowedExtensions: const ['masirbackup', 'db'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return const BackupResult(success: false, error: 'فایلی انتخاب نشد.');
      }
      final file = picked.files.single;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        return const BackupResult(success: false, error: 'فایل پشتیبان قابل خواندن نیست.');
      }
      await database.replaceDatabaseBytes(bytes);
      return const BackupResult(success: true);
    } catch (e) {
      return BackupResult(success: false, error: e.toString());
    }
  }
}
