import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class BackupService {
  BackupService(this._db);

  final DatabaseService _db;

  Future<File> createBackupFile() async {
    final dump = await _db.exportJsonDump();
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    final file = File(
      p.join(
        backupDir.path,
        'expense_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
      ),
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
    return file;
  }

  Future<void> shareBackup() async {
    final file = await createBackupFile();
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<bool> restoreFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;

    final file = result.files.first;
    final content = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString();

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file');
    }
    await _db.importJsonDump(decoded);
    return true;
  }
}
