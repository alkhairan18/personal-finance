import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:personal_finance/core/database/app_database.dart';

class BackupExportService {
  const BackupExportService._();

  static Future<String> generateBackupJsonString(AppDatabase db) async {
    final snapshot = await db.exportSnapshotMap();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot);
  }

  static Future<File> exportJsonBackupToFile({
    required AppDatabase db,
    required String directoryPath,
  }) async {
    final jsonContent = await generateBackupJsonString(db);
    final dateTag = DateTime.now().toIso8601String().substring(0, 10);
    final sanitizedUser = db.userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath =
        p.join(directoryPath, 'backup_${sanitizedUser}_$dateTag.json');
    final file = File(filePath);
    return file.writeAsString(jsonContent);
  }
}
