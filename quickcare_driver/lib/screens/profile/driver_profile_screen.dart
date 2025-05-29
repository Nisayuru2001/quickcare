// lib/screens/profile/driver_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide FieldValue;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore show FieldValue;
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_driver/services/auth_service.dart';
import 'package:quickcare_driver/services/document_upload_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../documents/driver_documents_screen.dart';

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
      print('MEGA DEBUG: Loading profile for user: $userId');
      
      // Make direct call to Firestore
      print('MEGA DEBUG: Direct Firestore access for driver_profiles document');
      
      DocumentReference docRef = _firestore.collection('driver_profiles').doc(userId);
      DocumentSnapshot doc = await docRef.get();
      
      // Very detailed debugging dump
      if (doc.exists) {
        final Map<String, dynamic> rawData = doc.data() as Map<String, dynamic>;
        print('MEGA DEBUG: Raw Firestore document data:');
        
        // Show each field with type and value
        rawData.forEach((key, value) {
          print('MEGA DEBUG:   Field: $key');
          print('MEGA DEBUG:     Value: $value');
          print('MEGA DEBUG:     Type: ${value?.runtimeType}');
          print('MEGA DEBUG:     Null?: ${value == null}');
        });
        
        // Explicitly check for URL fields
        print('MEGA DEBUG: Document has policeReportUrl field: ${rawData.containsKey('policeReportUrl')}');
        print('MEGA DEBUG: Document has drivingLicenseUrl field: ${rawData.containsKey('drivingLicenseUrl')}');
      } else {
        print('MEGA DEBUG: NO DOCUMENT FOUND IN FIRESTORE for $userId');
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Explicitly check for document URLs in the data
        String? policeReportUrl;
        String? drivingLicenseUrl;
        
        // Super explicit checks for document URLs
        print('MEGA DEBUG: Checking for document URLs');
        
        // Police report URL check
        if (data.containsKey('policeReportUrl')) {
          print('MEGA DEBUG: policeReportUrl field exists in document');
          var urlValue = data['policeReportUrl'];
          print('MEGA DEBUG: policeReportUrl value: $urlValue');
          print('MEGA DEBUG: policeReportUrl value type: ${urlValue?.runtimeType}');
          
          if (urlValue != null && urlValue is String && urlValue.isNotEmpty) {
            policeReportUrl = urlValue;
            print('MEGA DEBUG: Valid policeReportUrl found: $policeReportUrl');
          } else {
            print('MEGA DEBUG: Invalid policeReportUrl value');
          }
        } else {
          print('MEGA DEBUG: No policeReportUrl field in document');
        }
        
        // Driving license URL check
        if (data.containsKey('drivingLicenseUrl')) {
          print('MEGA DEBUG: drivingLicenseUrl field exists in document');
          var urlValue = data['drivingLicenseUrl'];
          print('MEGA DEBUG: drivingLicenseUrl value: $urlValue');
          print('MEGA DEBUG: drivingLicenseUrl value type: ${urlValue?.runtimeType}');
          
          if (urlValue != null && urlValue is String && urlValue.isNotEmpty) {
            drivingLicenseUrl = urlValue;
            print('MEGA DEBUG: Valid drivingLicenseUrl found: $drivingLicenseUrl');
          } else {
            print('MEGA DEBUG: Invalid drivingLicenseUrl value');
          }
        } else {
          print('MEGA DEBUG: No drivingLicenseUrl field in document');
        }

        print('MEGA DEBUG: Final Police Report URL: $policeReportUrl');
        print('MEGA DEBUG: Final Driving License URL: $drivingLicenseUrl');

        setState(() {
          _driverProfile = data;
          _fullNameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phoneNumber']?.toString() ?? '';
          _licenseController.text = data['licenseNumber'] ?? '';
          _emailController.text = data['email'] ?? '';

          // Set the URLs - ensure they're not empty strings
          _policeReportUrl = (policeReportUrl != null && policeReportUrl.isNotEmpty) 
              ? policeReportUrl 
              : null;
              
          _drivingLicenseUrl = (drivingLicenseUrl != null && drivingLicenseUrl.isNotEmpty) 
              ? drivingLicenseUrl 
              : null;
              
          print('MEGA DEBUG: State updated with:');
          print('MEGA DEBUG:   _policeReportUrl = $_policeReportUrl');
          print('MEGA DEBUG:   _drivingLicenseUrl = $_drivingLicenseUrl');

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

  // Updated methods for your driver_profile_screen.dart

// Replace the existing _uploadDocument method with this one:
  Future<void> _uploadDocument(String documentType) async {
    // Check if already uploading
    if (documentType == 'police_report' && _isUploadingPoliceReport) return;
    if (documentType == 'driving_license' && _isUploadingLicense) return;

    // Check if document already exists - must delete first before uploading a new one
    if (documentType == 'police_report' && _policeReportUrl != null && _policeReportUrl!.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Please delete the existing Police Report before uploading a new one'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    if (documentType == 'driving_license' && _drivingLicenseUrl != null && _drivingLicenseUrl!.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Please delete the existing Driving License before uploading a new one'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Set specific uploading state
    if (!mounted) return;
    setState(() {
      if (documentType == 'police_report') {
        _isUploadingPoliceReport = true;
      } else if (documentType == 'driving_license') {
        _isUploadingLicense = true;
      }
    });

    print('PROFILE SCREEN: Starting document upload for $documentType');

    // Dialog reference to ensure we can close it properly
    BuildContext? dialogContext;

    try {
      String? userId = _authInstance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      print('PROFILE SCREEN: User ID: $userId');

      // Show loading dialog
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

      // Use the improved DocumentUploadService
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
        print('PROFILE SCREEN: Upload successful, URL: $url');

        // Update local state immediately since the service handles Firestore
        setState(() {
          if (documentType == 'police_report') {
            _policeReportUrl = url;
            _isUploadingPoliceReport = false;
          } else if (documentType == 'driving_license') {
            _drivingLicenseUrl = url;
            _isUploadingLicense = false;
          }
        });

        // Reload profile to ensure UI is synced with Firestore
        await _loadDriverProfile();

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
        print('PROFILE SCREEN: No file selected or upload canceled');

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
      print('PROFILE SCREEN ERROR: $e');

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

// Also replace the _deleteDocument method:
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
      String? userId = _authInstance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Use improved delete service that handles both storage and Firestore
      bool deleted = await DocumentUploadService.deleteDocument(
        documentUrl,
        documentType: documentType,
        userId: userId,
      );

      if (deleted) {
        // Update local state
        if (mounted) {
          setState(() {
            if (documentType == 'police_report') {
              _policeReportUrl = null;
            } else if (documentType == 'driving_license') {
              _drivingLicenseUrl = null;
            }
          });
        }

        // Close dialog and show success message
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
      print('PROFILE SCREEN DELETE ERROR: $e');

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
    if (!mounted) return;

    BuildContext? dialogContext;
    try {
      if (url == null || url.isEmpty) {
        throw Exception('Document URL is empty or null');
      }

      // Show loading dialog
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
                    'Opening document...',
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

      // Try to open with direct URL first
      final Uri uri = Uri.parse(url);
      bool canOpen = await canLaunchUrl(uri);
      
      if (canOpen) {
        // Close loading dialog
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.pop(dialogContext!);
        }
        
        // Try to open directly
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      
      // If direct opening fails, download and open locally
      final http.Response response = await http.get(uri);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download document: HTTP ${response.statusCode}');
      }
      
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // Write to file
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Close loading dialog
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      
      // Open the file
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }
      
    } catch (e) {
      print('Error viewing document: $e');
      
      // Close loading dialog if open
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      
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
                        description: "Upload your police report (only one allowed)",
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
                        description: "Upload your driving license (only one allowed)",
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

                      // Profile Actions
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.settings_outlined),
                              title: const Text('Settings'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navigate to settings
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.help_outline),
                              title: const Text('Help & Support'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navigate to help & support
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _auth.signOut();
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    String? description,
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
    if (description != null) ...[
      const SizedBox(height: 4),
      Text(
        description,
        style: TextStyle(
          color: textColor.withOpacity(0.7),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
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