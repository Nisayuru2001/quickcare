// lib/documentService.ts - Simple service for viewing driver documents

import { ref, getDownloadURL } from "firebase/storage";
import { storage } from "@/lib/firebase";

export interface DocumentResult {
  url: string;
  path?: string;
  isMock: boolean;
  error?: string;
}

export class DocumentService {
  // Common storage paths where drivers might upload documents
  private static getDocumentPaths(driverId: string, documentType: 'license' | 'police_report'): string[] {
    const baseFileName = documentType === 'license' ? 'driving_license' : 'police_report';
    
    return [
      // Most common paths
      `driver_documents/${driverId}/${baseFileName}.pdf`,
      `driver_documents/${driverId}/${documentType}.pdf`,
      
      // Alternative paths
      `drivers/${driverId}/${baseFileName}.pdf`,
      `drivers/${driverId}/${documentType}.pdf`,
      
      // Other possible paths
      `uploads/drivers/${driverId}/${documentType}.pdf`,
      `documents/drivers/${driverId}/${baseFileName}.pdf`,
      `user_documents/${driverId}/${documentType}.pdf`,
      
      // Legacy paths
      `${driverId}/${documentType}.pdf`,
      `${driverId}/documents/${documentType}.pdf`
    ];
  }

  // Main method to fetch driver documents for admin viewing
  static async fetchDriverDocument(
    driverId: string, 
    documentType: 'license' | 'police_report'
  ): Promise<DocumentResult> {
    const possiblePaths = this.getDocumentPaths(driverId, documentType);
    
    console.log(`🔍 Admin fetching ${documentType} for driver: ${driverId}`);
    
    // Try each storage path
    for (const path of possiblePaths) {
      try {
        console.log(`📁 Checking: ${path}`);
        const documentRef = ref(storage, path);
        const url = await getDownloadURL(documentRef);
        
        console.log(`✅ Found document at: ${path}`);
        return {
          url,
          path,
          isMock: false
        };
      } catch (error: any) {
        console.log(`❌ No document at: ${path} (${error.code})`);
        continue;
      }
    }
    
    // No document found - return mock for demo
    console.log(`⚠️ No uploaded document found for driver ${driverId}`);
    return {
      url: this.createMockDocumentViewer(documentType, driverId),
      isMock: true,
      error: `${documentType === 'license' ? 'Driving license' : 'Police clearance report'} not found in storage. Driver may not have uploaded this document yet.`
    };
  }

  // Create a professional-looking mock document for demo purposes
  private static createMockDocumentViewer(documentType: string, driverId: string): string {
    const docTitle = documentType === 'license' ? 'Driving License' : 'Police Clearance Report';
    const docIcon = documentType === 'license' ? '🚗' : '🛡️';
    
    const mockContent = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Admin Document Viewer - ${docTitle}</title>
        <style>
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }
          
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
            padding: 20px;
          }
          
          .document-container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
            overflow: hidden;
          }
          
          .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
            position: relative;
          }
          
          .header::before {
            content: '${docIcon}';
            font-size: 60px;
            position: absolute;
            top: 20px;
            right: 30px;
            opacity: 0.3;
          }
          
          .header h1 {
            font-size: 32px;
            font-weight: 300;
            margin-bottom: 8px;
          }
          
          .header p {
            font-size: 16px;
            opacity: 0.9;
          }
          
          .admin-badge {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 14px;
            margin-top: 15px;
            border: 1px solid rgba(255, 255, 255, 0.3);
          }
          
          .content {
            padding: 40px;
          }
          
          .status-alert {
            background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
            border: none;
            color: #8b4513;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            display: flex;
            align-items: center;
            gap: 12px;
          }
          
          .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
          }
          
          .info-card {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 25px;
            border-radius: 8px;
          }
          
          .info-card h3 {
            color: #333;
            margin-bottom: 15px;
            font-size: 18px;
          }
          
          .info-row {
            display: flex;
            justify-content: space-between;
            margin: 12px 0;
            padding: 8px 0;
            border-bottom: 1px solid #e9ecef;
          }
          
          .info-row:last-child {
            border-bottom: none;
          }
          
          .info-label {
            font-weight: 600;
            color: #495057;
            flex: 1;
          }
          
          .info-value {
            flex: 1.5;
            color: #212529;
            text-align: right;
          }
          
          .document-placeholder {
            border: 2px dashed #dee2e6;
            border-radius: 12px;
            padding: 50px;
            text-align: center;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            margin: 30px 0;
          }
          
          .doc-icon {
            font-size: 80px;
            margin-bottom: 20px;
            color: #6c757d;
          }
          
          .placeholder-title {
            font-size: 24px;
            color: #495057;
            margin-bottom: 10px;
          }
          
          .placeholder-subtitle {
            color: #6c757d;
            margin-bottom: 20px;
            line-height: 1.5;
          }
          
          .reasons-list {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px auto;
            max-width: 400px;
            text-align: left;
          }
          
          .reasons-list ul {
            list-style: none;
            padding: 0;
          }
          
          .reasons-list li {
            padding: 8px 0;
            position: relative;
            padding-left: 25px;
          }
          
          .reasons-list li::before {
            content: '•';
            color: #667eea;
            font-weight: bold;
            position: absolute;
            left: 0;
          }
          
          .footer {
            background: #f8f9fa;
            padding: 30px;
            text-align: center;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
          }
          
          .footer-title {
            font-weight: 600;
            color: #495057;
            margin-bottom: 5px;
          }
          
          .timestamp {
            background: #e9ecef;
            padding: 15px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
            color: #495057;
          }
        </style>
      </head>
      <body>
        <div class="document-container">
          <div class="header">
            <h1>${docTitle}</h1>
            <p>Administrative Document Viewer</p>
            <div class="admin-badge">QuickCare Admin Panel</div>
          </div>
          
          <div class="content">
            <div class="status-alert">
              <span style="font-size: 24px;">⚠️</span>
              <div>
                <strong>Document Not Available</strong><br>
                This driver's ${docTitle.toLowerCase()} is not found in the system storage.
              </div>
            </div>

            <div class="info-grid">
              <div class="info-card">
                <h3>Document Information</h3>
                <div class="info-row">
                  <span class="info-label">Document Type</span>
                  <span class="info-value">${docTitle}</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Driver ID</span>
                  <span class="info-value">${driverId.substring(0, 12)}...</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Expected Format</span>
                  <span class="info-value">PDF Document</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Storage Status</span>
                  <span class="info-value" style="color: #dc3545;">Not Found</span>
                </div>
              </div>

              <div class="info-card">
                <h3>Admin Actions</h3>
                <div class="info-row">
                  <span class="info-label">Current Status</span>
                  <span class="info-value">Under Review</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Action Required</span>
                  <span class="info-value">Document Upload</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Priority</span>
                  <span class="info-value">Medium</span>
                </div>
                <div class="info-row">
                  <span class="info-label">Review Status</span>
                  <span class="info-value">Pending</span>
                </div>
              </div>
            </div>

            <div class="document-placeholder">
              <div class="doc-icon">📄</div>
              <h3 class="placeholder-title">Document Missing</h3>
              <p class="placeholder-subtitle">
                The ${docTitle.toLowerCase()} for this driver could not be located in Firebase Storage.
              </p>
              
              <div class="reasons-list">
                <h4>Possible Reasons:</h4>
                <ul>
                  <li>Driver hasn't uploaded the document yet</li>
                  <li>Document stored in different location</li>
                  <li>File path configuration issue</li>
                  <li>Storage permissions need adjustment</li>
                  <li>Document pending approval process</li>
                </ul>
              </div>
            </div>

            <div class="timestamp">
              <strong>System Check:</strong> ${new Date().toLocaleString()}<br>
              <strong>Storage Paths Checked:</strong> 8 different locations<br>
              <strong>Admin Interface:</strong> QuickCare Document Management System
            </div>
          </div>
          
          <div class="footer">
            <div class="footer-title">QuickCare Emergency Services</div>
            <p>Administrative Document Verification System</p>
            <p>This interface allows admins to review driver-uploaded documents for approval</p>
          </div>
        </div>
      </body>
      </html>
    `;
    
    return `data:text/html;charset=utf-8,${encodeURIComponent(mockContent)}`;
  }

  // Get all possible document storage paths (useful for debugging)
  static getStoragePaths(driverId: string): { license: string[], police_report: string[] } {
    return {
      license: this.getDocumentPaths(driverId, 'license'),
      police_report: this.getDocumentPaths(driverId, 'police_report')
    };
  }

  // Check if a document exists (without fetching the URL)
  static async documentExists(driverId: string, documentType: 'license' | 'police_report'): Promise<boolean> {
    const possiblePaths = this.getDocumentPaths(driverId, documentType);
    
    for (const path of possiblePaths) {
      try {
        const documentRef = ref(storage, path);
        await getDownloadURL(documentRef);
        return true;
      } catch {
        continue;
      }
    }
    
    return false;
  }
}