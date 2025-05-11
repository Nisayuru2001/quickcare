// lib/screens/profile/driver_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_driver/services/auth_service.dart';
import 'package:quickcare_driver/services/document_upload_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final DriverAuthService _auth = DriverAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _authInstance = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Design colors
  final Color primaryColor = const Color(0xFFE53935);
  final Color textColor = const Color(0xFF212121);
  final Color surfaceColor = const Color(0xFFF8F9FA);

  // Driver profile data
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploadingPoliceReport = false;
  bool _isUploadingLicense = false;

  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Document URLs
  String? _policeReportUrl;
  String? _drivingLicenseUrl;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverProfile() async {
    setState(() => _isLoading = true);

    try {
      String userId = _authInstance.currentUser!.uid;
      print('Loading profile for user: $userId');

      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('Profile data: $data');

        // Check if URL strings are actually strings and not null
        String? policeReportUrl = data['policeReportUrl'] as String?;
        String? drivingLicenseUrl = data['drivingLicenseUrl'] as String?;

        print('Loading Police Report URL: $policeReportUrl');
        print('Loading Driving License URL: $drivingLicenseUrl');

        setState(() {
          _driverProfile = data;
          _fullNameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _licenseController.text = data['licenseNumber'] ?? '';
          _emailController.text = data['email'] ?? '';

          // Set the URLs
          _policeReportUrl = policeReportUrl;
          _drivingLicenseUrl = drivingLicenseUrl;

          // Reset upload flags
          _isUploadingPoliceReport = false;
          _isUploadingLicense = false;
        });
      } else {
        print('No profile document found');
        setState(() {
          _driverProfile = {};
          _policeReportUrl = null;
          _drivingLicenseUrl = null;
          _isUploadingPoliceReport = false;
          _isUploadingLicense = false;
        });
      }
    } catch (e) {
      print('Error loading driver profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }

      setState(() {
        _policeReportUrl = null;
        _drivingLicenseUrl = null;
        _isUploadingPoliceReport = false;
        _isUploadingLicense = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update profile including document URLs
      await _auth.updateDriverProfile(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        licenseNumber: _licenseController.text,
        policeReportUrl: _policeReportUrl,
        drivingLicenseUrl: _drivingLicenseUrl,
      );

      setState(() => _isEditing = false);
      await _loadDriverProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadDocument(String documentType) async {
    // Check if already uploading
    if (documentType == 'police_report' && _isUploadingPoliceReport) return;
    if (documentType == 'driving_license' && _isUploadingLicense) return;

    // Set specific uploading state
    if (!mounted) return; // Early exit if widget is disposed
    setState(() {
      if (documentType == 'police_report') {
        _isUploadingPoliceReport = true;
      } else if (documentType == 'driving_license') {
        _isUploadingLicense = true;
      }
    });

    print('Starting document upload for $documentType');

    // Dialog reference to ensure we can close it properly
    BuildContext? dialogContext;

    try {
      String? userId = _authInstance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      print('User ID: $userId');

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            dialogContext = context; // Store dialog context
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading document...',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      String? url = await DocumentUploadService.uploadPDF(
        userId: userId,
        documentType: documentType,
      );

      // Close the dialog right after upload completes
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }

      // Exit if the widget is disposed
      if (!mounted) return;

      if (url != null) {
        print('Upload successful, URL: $url');

        // Update local state
        setState(() {
          if (documentType == 'police_report') {
            _policeReportUrl = url;
            _isUploadingPoliceReport = false;
          } else if (documentType == 'driving_license') {
            _drivingLicenseUrl = url;
            _isUploadingLicense = false;
          }
        });

        // Update profile in Firestore
        Map<String, dynamic> updateData = {};
        if (documentType == 'police_report') {
          updateData['policeReportUrl'] = url;
        } else if (documentType == 'driving_license') {
          updateData['drivingLicenseUrl'] = url;
        }

        if (updateData.isNotEmpty) {
          print('Updating Firestore with: $updateData');
          await _firestore
              .collection('driver_profiles')
              .doc(userId)
              .update(updateData);
          print('Firestore update successful');

          // Reload profile data to ensure UI is in sync with database
          await _loadDriverProfile();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('${documentType == 'police_report' ? 'Police Report' : 'Driving License'} uploaded successfully'),
                ],
              ),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // No file selected or canceled
        print('No file selected or upload canceled');

        if (!mounted) return;

        // Reset loading state
        setState(() {
          if (documentType == 'police_report') {
            _isUploadingPoliceReport = false;
          } else if (documentType == 'driving_license') {
            _isUploadingLicense = false;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('No file selected'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading document: $e');

      // Close dialog on error
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }

      if (!mounted) return;

      // Reset loading state on error
      setState(() {
        if (documentType == 'police_report') {
          _isUploadingPoliceReport = false;
        } else if (documentType == 'driving_license') {
          _isUploadingLicense = false;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to upload document: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String documentType) async {
    if (!mounted) return;

    // Get document URL based on type
    String? documentUrl;
    if (documentType == 'police_report') {
      documentUrl = _policeReportUrl;
    } else if (documentType == 'driving_license') {
      documentUrl = _drivingLicenseUrl;
    }

    // If no document exists, nothing to delete
    if (documentUrl == null || documentUrl.isEmpty) {
      return;
    }

    // Confirm deletion with dialog
    bool confirmDelete = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Document?"),
        content: Text("Are you sure you want to delete this ${documentType == 'police_report' ? 'Police Report' : 'Driving License'}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              confirmDelete = true;
              Navigator.of(context).pop();
            },
            child: Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!confirmDelete) return;

    // Show loading dialog
    BuildContext? dialogContext;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          dialogContext = context;
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Deleting document...',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    try {
      // 1. Delete from Firebase Storage
      bool deleted = await DocumentUploadService.deleteDocument(documentUrl);

      if (deleted) {
        // 2. Update Firestore document
        String userId = _authInstance.currentUser!.uid;
        Map<String, dynamic> updateData = {};

        if (documentType == 'police_report') {
          updateData['policeReportUrl'] = FieldValue.delete();
        } else if (documentType == 'driving_license') {
          updateData['drivingLicenseUrl'] = FieldValue.delete();
        }

        await _firestore
            .collection('driver_profiles')
            .doc(userId)
            .update(updateData);

        // 3. Update local state
        if (mounted) {
          setState(() {
            if (documentType == 'police_report') {
              _policeReportUrl = null;
            } else if (documentType == 'driving_license') {
              _drivingLicenseUrl = null;
            }
          });
        }

        // 4. Close dialog and show success message
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete document from storage');
      }
    } catch (e) {
      print('Error deleting document: $e');

      // Close dialog
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewDocument(String? url) async {
    try {
      if (url == null || url.isEmpty) {
        throw Exception('Document URL is empty or null');
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open document');
      }
    } catch (e) {
      print('Error viewing document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Could not open document: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColorThemed = isDarkMode ? Colors.grey[850]! : surfaceColor;
    final Color textColorThemed = isDarkMode ? Colors.white : textColor;
    final Color cardColorThemed = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Driver Profile',
                    style: TextStyle(
                      color: textColorThemed,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  if (!_isEditing)
                    IconButton(
                      icon: Icon(Icons.edit, color: primaryColor),
                      onPressed: () {
                        setState(() => _isEditing = true);
                      },
                    )
                  else
                    TextButton(
                      onPressed: _updateProfile,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            _isLoading
                ? Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE53935),
                ),
              ),
            )
                : Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _driverProfile?['fullName'] ?? 'Driver Name',
                              style: TextStyle(
                                color: textColorThemed,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_driverProfile?['status']),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _capitalizeStatus(_driverProfile?['status'] ?? 'unknown'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Personal Information Section
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          color: textColorThemed,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Form fields
                      _buildInputLabel('Full Name', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _buildInputDecoration(
                          'Full Name',
                          Icons.person_outline,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      _buildInputLabel('Phone Number', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _buildInputDecoration(
                          'Phone Number',
                          Icons.phone_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      _buildInputLabel('License Number', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _licenseController,
                        decoration: _buildInputDecoration(
                          'License Number',
                          Icons.badge_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        validator: (val) => val!.isEmpty ? 'Please enter your license number' : null,
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      _buildInputLabel('Email', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration(
                          'Email',
                          Icons.email_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: false,
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 32),

                      // Documents Section
                      Text(
                        'Required Documents',
                        style: TextStyle(
                          color: textColorThemed,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Police Report Upload
                      _buildDocumentCard(
                        title: 'Police Report',
                        icon: Icons.local_police_outlined,
                        documentUrl: _policeReportUrl,
                        isUploading: _isUploadingPoliceReport,
                        onUpload: () => _uploadDocument('police_report'),
                        onView: () => _viewDocument(_policeReportUrl),
                        cardColor: cardColorThemed,
                        textColor: textColorThemed,
                      ),

                      const SizedBox(height: 16),

                      // Driving License Upload
                      _buildDocumentCard(
                        title: 'Driving License',
                        icon: Icons.drive_eta_outlined,
                        documentUrl: _drivingLicenseUrl,
                        isUploading: _isUploadingLicense,
                        onUpload: () => _uploadDocument('driving_license'),
                        onView: () => _viewDocument(_drivingLicenseUrl),
                        cardColor: cardColorThemed,
                        textColor: textColorThemed,
                      ),

                      const SizedBox(height: 32),

                      // Statistics Section
                      Text(
                        'Driver Statistics',
                        style: TextStyle(
                          color: textColorThemed,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '0',
                              'Completed\nTrips',
                              Icons.check_circle_outline,
                              cardColorThemed,
                              textColorThemed,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '0',
                              'In Progress\nTrips',
                              Icons.pending_outlined,
                              cardColorThemed,
                              textColorThemed,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.logout),
                          label: Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            await _auth.signOut();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required IconData icon,
    required String? documentUrl,
    required bool isUploading,
    required VoidCallback onUpload,
    required VoidCallback onView,
    required Color cardColor,
    required Color textColor,
  }) {
    // Check if document URL is valid
    final bool hasValidDocument = documentUrl != null && documentUrl.isNotEmpty;
    final String documentType = title == 'Police Report' ? 'police_report' : 'driving_license';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
      Row(
      children: [
      Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: primaryColor,
        size: 24,
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    title,
    style: TextStyle(
    color: textColor,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 4),
    Row(
    children: [
    Icon(
    hasValidDocument ? Icons.check_circle : Icons.error_outline,
    size: 16,
    color: hasValidDocument ? Colors.green : Colors.grey,
    ),
    const SizedBox(width: 4),
    Text(
    hasValidDocument ? 'Document uploaded' : 'No document uploaded',
    style: TextStyle(
    color: hasValidDocument ? Colors.green : textColor.withOpacity(0.6),
    fontSize: 14,
    ),
    ),
    ],
    ),
    ],
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),
    if (hasValidDocument)
    // Document exists - show view and delete options
    Row(
    children: [
    Expanded(
    child: OutlinedButton.icon(
    icon: Icon(Icons.visibility_outlined),
    label: Text('View'),
    style: OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    onPressed: onView,
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: OutlinedButton.icon(
    icon: Icon(Icons.delete_outline),
    label: Text('Delete'),
    style: OutlinedButton.styleFrom(
    foregroundColor: Colors.red,
    side: BorderSide(color: Colors.red),
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    onPressed: isUploading ? null : () => _deleteDocument(documentType),
    ),
    ),
    ],
    )
    else
    // No document - show upload button
    SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
    icon: Icon(Icons.upload_file),
    label: Text(
    'Upload Document',
    style: TextStyle(fontWeight: FontWeight.w600),
    ),
    style: ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
      onPressed: isUploading ? null : onUpload,
    ),
    ),

            if (isUploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: primaryColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ],
          ],
      ),
    );
  }

  Widget _buildInputLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor.withOpacity(0.8),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
      String hint, IconData icon, Color backgroundColor, Color textColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 22),
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }
}