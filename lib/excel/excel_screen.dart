import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:excel_maping/d_helper.dart';
import 'package:excel_maping/print_screen/print_screen.dart';
import 'package:excel_maping/scanner/barcode_scanner.dart';

/// Excel Mapper Page-------------------------
class ExcelMapperPage extends StatefulWidget {
  const ExcelMapperPage({super.key});

  @override
  State<ExcelMapperPage> createState() => _ExcelMapperPageState();
}

class _ExcelMapperPageState extends State<ExcelMapperPage> {
  List<String> headers = [];
  List<List<String>> rows = []; 
  List<String> dbFields = ["name", "age", "category"]; 
  List<int?> mapping = [];

  bool isLoading = false;

  ///----------------------------------------------------------------------------------------

  Future<String?> exportSimplePDF(
    BuildContext context,
    List<String> dbFields,
    List<List<String>> rows,
    List<int?> mapping,
  ) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export')));
      return null;
    }

    final pdf = pw.Document();

    final tableData = [
      dbFields,
      ...rows.map((row) {
        return List.generate(dbFields.length, (c) {
          final mi = (c < 2) ? mapping[c] : null;
          return (mi != null && mi >= 0 && mi < row.length) ? row[mi] : '';
        });
      }),
    ];
    log("------$tableData");
    pdf.addPage(
      pw.MultiPage(
        maxPages: 10,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.DefaultTextStyle(
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12),
              child: pw.Table(
                columnWidths: {
                  for (int i = 0; i < dbFields.length; i++)
                    i: pw.FlexColumnWidth(), 
                },
                children: [
                  pw.TableRow(
                    children: dbFields
                        .map(
                          (header) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text(
                              header,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...tableData.skip(1).map((row) {
                    return pw.TableRow(
                      children: row
                          .map(
                            (cell) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                vertical: 2,
                              ),
                              child: pw.Text(cell),
                            ),
                          )
                          .toList(),
                    );
                  }),
                ],
              ),
            ),
          ];
        },
      ),
    );

    try {
      final dir = Directory('/storage/emulated/0/Download');
      final file = File(
        '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ PDF saved: ${file.path}')));
      return file.path;
    } catch (e, st) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error exporting PDF: $e')));
      return null;
    }
  }


  /// Pick and Parse Excel-------------------

  Future<void> pickExcel(BuildContext context) async {
    setState(() => isLoading = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'json'],
      withData: true,
    );

    if (result == null) {
      setState(() => isLoading = false);
      return;
    }

    final file = result.files.first;

    Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final ext = file.extension?.toLowerCase();

    try {
      if (ext == 'xlsx' || ext == 'xls') {
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) throw Exception("No tables found in Excel");

        final sheet = excel.tables.values.first;
        if (sheet.rows.isEmpty) throw Exception("Excel sheet is empty");

        setState(() {
          headers = sheet.rows.first
              .map((e) => e?.value.toString() ?? "")
              .toList();
          rows = sheet.rows
              .skip(1)
              .map(
                (r) => List.generate(
                  headers.length,
                  (i) => i < r.length ? r[i]?.value.toString() ?? "" : "",
                ),
              )
              .toList();

          mapping = List.generate(
            dbFields.length,
            (i) => i < headers.length ? i : null,
          );
          isLoading = false;
        });
      } else if (ext == 'csv') {
        final content = utf8.decode(bytes);

        final cleaned = content.replaceAll('\uFEFF', '');

        final csvTable = const CsvToListConverter().convert(
          cleaned,
          eol: '\n',
        );

        if (csvTable.isEmpty) {
          setState(() => isLoading = false);
          return;
        }

        final rawHeaders = csvTable.first
            .map((e) => e?.toString().trim() ?? "")
            .toList();

        final rawRows = csvTable
            .skip(1)
            .map(
              (r) => List.generate(
                rawHeaders.length,
                (i) => i < r.length ? r[i]?.toString().trim() ?? "" : "",
              ),
            )
            .toList();

        setState(() {
          headers = rawHeaders;
          rows = rawRows;

          mapping = List.generate(
            dbFields.length,
            (i) => i < headers.length ? i : null,
          );

          isLoading = false;
        });
      } else if (ext == 'json') {
        final content = utf8.decode(bytes);
        final data = jsonDecode(content);

        if (data is List) {
          headers = (data.first as Map<String, dynamic>).keys.toList();
          rows = data.map<List<String>>((row) {
            return headers.map((h) => row[h]?.toString() ?? "").toList();
          }).toList();
        } else if (data is Map) {
          headers = data.keys.toList() as List<String>;
          rows = [headers.map((h) => data[h]?.toString() ?? "").toList()];
        }

        setState(() {
          mapping = List.generate(
            dbFields.length,
            (i) => i < headers.length ? i : null,
          );
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Unsupported file type .$ext")));
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid or corrupted file")),
      );
      setState(() => isLoading = false);
    }
  }


  /// Save Excel Rows to DB -------------------------------

  Future<void> saveToDB() async {
    if (rows.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final db = await DBHelper.database;
      int insertedCount = 0;

      await db.transaction((txn) async {
        final batch = txn.batch();

        for (var r = 0; r < rows.length; r++) {
          String name = "";
          String age = "";
          String category = "";

          for (var c = 0; c < dbFields.length; c++) {
            final idx = mapping[c];
            if (idx == null || idx >= rows[r].length) continue;

            final val = rows[r][idx];
            if (dbFields[c] == "name") name = val;
            if (dbFields[c] == "age") age = val;
            if (dbFields[c] == "category") category = val;
          }

          batch.insert("items", {
            "name": name,
            "age": age,
            "category": category,
          });
          insertedCount++;
        }

        await batch.commit(noResult: true); 
      });

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Successfully saved $insertedCount rows to DB."),
          ),
        );
      }
    } catch (e, st) {
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error while saving: $e")));
      }
    }
  }

  /// printer--------------------------------

  Future<void> printToDefaultPrinter() async {
    // Get all printers-----------
    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      throw Exception('No printers found on this device.');
    }

    // Pick default printer if availablep---------------
    final Printer target = printers.firstWhere(
      (p) => p.isDefault == true,
      orElse: () => printers.first,
    );

    // Direct print-----------
    await Printing.directPrintPdf(
      printer: target,
      onLayout: (PdfPageFormat format) async => _buildPdf(),
    );
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('Direct Print Demo', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 12),
              pw.Text('This was printed without showing a dialog.'),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Excel Mapper"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              exportSimplePDF(context, dbFields, rows, mapping);
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              Database openDB = await DBHelper.openDB();
              log("---openDB---$openDB");
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all_outlined),
            onPressed: () async {
              int clearItemsIndex = await DBHelper.clearItems();
              log("---clearItemsStatus---$clearItemsIndex");
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () async {
              List<Map<String, dynamic>> itemslist = await DBHelper.getItems();
              log("---itemslist---$itemslist");
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: rows.isEmpty ? null : saveToDB,
          ),
        ],
      ),
      floatingActionButton: isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(),
            )
          : FloatingActionButton.extended(
              onPressed: () => pickExcel(context),
              icon: const Icon(Icons.upload_file),
              label: const Text("Import Excel"),
            ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PdfPickerScreen(),
                  ),
                );
              },
              child: const Text('Print now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerWidget()),
                );
              },
              child: const Text("Go to QR Scanner"),
            ),
            _buildMappingSection(),
            if (rows.isNotEmpty) _buildPreviewSection(),
          ],
        ),
      ),
    );
  }

 
  Widget _buildMappingSection() {
    if (headers.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          const ListTile(
            title: Text(
              "Map Excel Columns to DB Fields",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (int i = 0; i < dbFields.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    dbFields[i],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: mapping[i],
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("-- none --"),
                        ),
                        ...List.generate(
                          headers.length,
                          (j) => DropdownMenuItem(
                            value: j,
                            child: Text(headers[j]),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => mapping[i] = v),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildPreviewSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [for (var f in dbFields) DataColumn(label: Text(f))],
        rows: [
          for (var r in rows.take(100))
            DataRow(
              cells: [
                for (var c = 0; c < dbFields.length; c++)
                  DataCell(
                    Text(
                      (mapping[c] != null && mapping[c]! < r.length)
                          ? r[mapping[c]!]
                          : "",
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
