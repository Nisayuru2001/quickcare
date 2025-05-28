import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalStorageScreen extends StatefulWidget {
  const MedicalStorageScreen({super.key});

  @override
  State<MedicalStorageScreen> createState() => _MedicalStorageScreenState();
}

class _MedicalStorageScreenState extends State<MedicalStorageScreen> {
  List<_MedicalReport> _reports = [];
  String? _userKey;

  @override
  void initState() {
    super.initState();
    _initHiveAndLoad();
  }

  Future<void> _initHiveAndLoad() async {
    await Hive.initFlutter();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _reports = [];
        _userKey = null;
      });
      return;
    }
    final key = 'medical_reports_${user.uid}';
    _userKey = key;
    var box = await Hive.openBox('medical_reports');
    final stored = box.get(key, defaultValue: []);
    if (stored is List) {
      setState(() {
        _reports = stored
            .map((e) => _MedicalReport.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      });
    }
  }

  Future<void> _saveReports() async {
    if (_userKey == null) return;
    var box = await Hive.openBox('medical_reports');
    await box.put(_userKey, _reports.map((e) => e.toMap()).toList());
  }

  Future<void> _addReport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      String? name = await _showNameDialog(context, 'Enter report name');
      if (name != null && name.trim().isNotEmpty) {
        setState(() {
          _reports.add(_MedicalReport(
            name: name.trim(),
            file: File(result.files.single.path!),
          ));
        });
        _saveReports();
      }
    }
  }

  Future<void> _editReportName(int index) async {
    String? newName = await _showNameDialog(context, 'Edit report name', initial: _reports[index].name);
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        _reports[index] = _reports[index].copyWith(name: newName.trim());
      });
      _saveReports();
    }
  }

  void _removeReport(int index) {
    setState(() {
      _reports.removeAt(index);
    });
    _saveReports();
  }

  void _viewReport(_MedicalReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ReportViewer(report: report),
      ),
    );
  }

  Future<String?> _showNameDialog(BuildContext context, String title, {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Report Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color cardColor = Colors.white;
    final Color backgroundColor = Colors.white;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Medical Storage'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Report',
            onPressed: _addReport,
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background circles (or replace with image if needed)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Center(
                child: Card(
                  color: cardColor,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _reports.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 24),
                              const Text(
                                'No medical documents uploaded yet.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'You can upload and manage your medical reports and documents here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _reports.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final report = _reports[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                                child: ListTile(
                                  leading: Icon(Icons.insert_drive_file, color: Colors.red[300], size: 32),
                                  title: Text(report.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(report.file.path.split('/').last, style: const TextStyle(fontSize: 12)),
                                  onTap: () => _viewReport(report),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        tooltip: 'Edit Name',
                                        onPressed: () => _editReportName(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        tooltip: 'Delete',
                                        onPressed: () => _removeReport(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalReport {
  final String name;
  final File file;
  _MedicalReport({required this.name, required this.file});
  _MedicalReport copyWith({String? name, File? file}) => _MedicalReport(name: name ?? this.name, file: file ?? this.file);
  Map<String, dynamic> toMap() => {'name': name, 'filePath': file.path};
  factory _MedicalReport.fromMap(Map<String, dynamic> map) => _MedicalReport(name: map['name'], file: File(map['filePath']));
}

class _ReportViewer extends StatelessWidget {
  final _MedicalReport report;
  const _ReportViewer({required this.report});

  bool get _isPDF => report.file.path.toLowerCase().endsWith('.pdf');
  bool get _isImage => [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'
  ].any((ext) => report.file.path.toLowerCase().endsWith(ext));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report.name),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: _isPDF
          ? PdfViewPinch(
              controller: PdfControllerPinch(document: PdfDocument.openFile(report.file.path)),
            )
          : _isImage
              ? Center(child: Image.file(report.file))
              : Center(
                  child: Text(
                    'Preview not supported for this file type.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
    );
  }
} 