import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';

class PdfPickerScreen extends StatefulWidget {
  const PdfPickerScreen({super.key});

  @override
  State<PdfPickerScreen> createState() => _PdfPickerScreenState();
}

class _PdfPickerScreenState extends State<PdfPickerScreen> {
  File? _pdfFile;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _printPdf() async {
    if (_pdfFile != null) {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfFile!.readAsBytes(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick, View & Print PDF"),
        actions: [
          if (_pdfFile != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Print PDF",
              onPressed: _printPdf,
            ),
        ],
      ),
      body: _pdfFile == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickPdf,
                child: const Text("Pick PDF File"),
              ),
            )
          : PDFView(filePath: _pdfFile!.path),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPdf,
        tooltip: "Pick another PDF",
        child: Icon(Icons.folder_open),
      ),
    );
  }
}
