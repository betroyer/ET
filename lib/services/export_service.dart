import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

String csvEncode(List<List<dynamic>> rows) => csv.encode(rows);

class ExportService {
  Future<File> exportCsv(List<TransactionModel> transactions) async {
    final rows = <List<dynamic>>[
      [
        'ID',
        'Type',
        'Amount',
        'Category',
        'Source',
        'Date',
        'Time',
        'Payment Method',
        'Note',
      ],
      ...transactions.map(
        (t) => [
          t.id,
          t.type,
          t.amount,
          t.category,
          t.source ?? '',
          t.date,
          t.time,
          t.paymentMethod ?? '',
          t.note ?? '',
        ],
      ),
    ];

    final csv = csvEncode(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'expense_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv'),
    );
    await file.writeAsString(csv);
    return file;
  }

  Future<File> exportPdf({
    required List<TransactionModel> transactions,
    required double income,
    required double expenses,
  }) async {
    final doc = pw.Document();
    final balance = income - expenses;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('ExTra Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Generated ${DateFormatter.displayDateTime(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text('Income: ${CurrencyFormatter.format(income)}'),
          pw.Text('Expenses: ${CurrencyFormatter.format(expenses)}'),
          pw.Text('Balance: ${CurrencyFormatter.format(balance)}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Category', 'Amount', 'Note'],
            data: transactions
                .map(
                  (t) => [
                    t.date,
                    t.type,
                    t.category,
                    CurrencyFormatter.format(t.amount),
                    t.note ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'expense_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf'),
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> shareFile(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  String encodeJson(Map<String, dynamic> data) => const JsonEncoder.withIndent('  ').convert(data);
}
