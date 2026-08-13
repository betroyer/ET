import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class BackupService {
  BackupService(this._db);

  final DatabaseService _db;

  Future<Directory> get backupDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<File> createBackupFile() async {
    final dump = await _db.exportJsonDump();
    final backupDir = await backupDirectory;
    final file = File(
      p.join(
        backupDir.path,
        'extra_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
      ),
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
    return file;
  }

  Future<void> shareBackup() async {
    final file = await createBackupFile();
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<List<File>> listBackupFiles() async {
    final backupDir = await backupDirectory;
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<bool> restoreFromFile(File file) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file');
    }
    await _db.importJsonDump(decoded);
    return true;
  }

  /// Restores the newest local backup, if any.
  Future<bool> restoreLatestLocalBackup() async {
    final files = await listBackupFiles();
    if (files.isEmpty) return false;
    return restoreFromFile(files.first);
  }
}
