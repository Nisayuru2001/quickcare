import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/document_service.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final Color primaryColor = const Color(0xFFE53935);
  bool _isLoading = true;
  Map<String, Map<String, dynamic>?> _documents = {
    'police_report': null,
    'driving_license': null,
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      for (String docType in _documents.keys) {
        _documents[docType] = await DocumentService.getDocument(docType);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading documents: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadFile(String documentType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading document...')),
          );
        }

        await DocumentService.uploadDocument(file, documentType);
        await _loadDocuments(); // Refresh documents list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading document: $e')),
        );
      }
    }
  }

  Future<void> _deleteDocument(String documentType) async {
    try {
      await DocumentService.deleteDocument(documentType);
      await _loadDocuments(); // Refresh documents list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting document: $e')),
        );
      }
    }
  }

  Future<void> _viewDocument(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing document: $e')),
        );
      }
    }
  }

  String _getDocumentTitle(String docType) {
    return docType == 'police_report' ? 'Police Report' : 'Driving License';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Documents'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                String docType = _documents.keys.elementAt(index);
                Map<String, dynamic>? docData = _documents[docType];
                bool hasDocument = docData != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              docType == 'police_report'
                                  ? Icons.local_police_outlined
                                  : Icons.card_membership_outlined,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _getDocumentTitle(docType),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (hasDocument) ...[
                          Text(
                            'Uploaded: ${(docData['uploadedAt'] as Timestamp).toDate().toString().split('.')[0]}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _viewDocument(docData['url']),
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Document'),
                                    content: Text(
                                      'Are you sure you want to delete this ${_getDocumentTitle(docType)}?'
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteDocument(docType);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ] else
                          ElevatedButton.icon(
                            onPressed: () => _pickAndUploadFile(docType),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Document'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
} 