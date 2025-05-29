import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Search, Users, Edit, FileText, Eye, CheckCircle, XCircle, AlertCircle, RefreshCw, Upload } from "lucide-react";
import { collection, getDocs, query, orderBy, doc, updateDoc } from "firebase/firestore";
import { ref, getDownloadURL, listAll } from "firebase/storage";
import { db, storage, auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { CardDescription, CardFooter } from "@/components/ui/card";

interface Driver {
  id: string;
  email: string;
  fullName: string;
  isVerified: boolean;
  licenseNumber: string;
  phoneNumber: string;
  rating: number;
  status: string;
  totalTrips: number;
  createdAt: any;
  updatedAt: any;
  licenseImageUrl?: string;
  policeReportUrl?: string;
}

interface DocumentState {
  url: string;
  type: 'license' | 'police_report';
  loading: boolean;
  error: string | null;
}

// Mock document data for demo purposes
const mockDocuments = {
  "sample-license": "data:application/pdf;base64,JVBERi0xLjQKJcOkw7zDtsO...", // Base64 encoded PDF
  "sample-police-report": "data:application/pdf;base64,JVBERi0xLjQKJcOkw7zDtsO...", // Base64 encoded PDF
};

export function DriverManagement() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [documents, setDocuments] = useState<{
    license: DocumentState | null;
    police_report: DocumentState | null;
  }>({
    license: null,
    police_report: null
  });
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setIsAuthenticated(!!user);
      if (user) {
        fetchDrivers();
      } else {
        console.log("User not authenticated, clearing drivers");
        setDrivers([]);
      }
    });

    return () => unsubscribe();
  }, []);

  const fetchDrivers = async () => {
    try {
      console.log("=== FETCHING DRIVERS FROM FIRESTORE ===");
      setLoading(true);
      
      // Fetch all drivers from Firestore
      const driversCollection = collection(db, "driver_profiles");
      const querySnapshot = await getDocs(driversCollection);
      
      console.log(`Found ${querySnapshot.size} drivers in Firestore`);
      
      const driversData = querySnapshot.docs.map(doc => {
        const data = doc.data();
        console.log(`Driver: ${doc.id} - ${data.fullName} - License: ${data.licenseNumber}`);
        return {
          id: doc.id,
          ...data
        };
      }) as Driver[];
      
      // Sort by most recent first
      driversData.sort((a, b) => {
        if (a.updatedAt && b.updatedAt) {
          return b.updatedAt.seconds - a.updatedAt.seconds;
        }
        return 0;
      });
      
      console.log("Drivers loaded and sorted:", driversData.map(d => ({
        id: d.id,
        name: d.fullName,
        email: d.email,
        status: d.status
      })));
      
      setDrivers(driversData);
    } catch (error) {
      console.error("Error fetching drivers:", error);
      setDrivers([]);
    } finally {
      setLoading(false);
    }
  };

  const fetchDocument = async (driverId: string, documentType: 'license' | 'police_report') => {
    if (!isAuthenticated) {
      setDocuments(prev => ({
        ...prev,
        [documentType]: {
          url: '',
          type: documentType,
          loading: false,
          error: "User not authenticated"
        }
      }));
      return;
    }

    setDocuments(prev => ({
      ...prev,
      [documentType]: {
        ...prev[documentType],
        loading: true,
        error: null
      }
    }));
    
    try {
      console.log(`=== FETCHING ${documentType.toUpperCase()} FOR DRIVER ${driverId} ===`);
      
      let documentUrl = null;
      let foundFileName = null;

      // Method 1: Use listAll to scan the driver's folder dynamically
      try {
        const folderRef = ref(storage, `driver_documents/${driverId}/`);
        console.log(`📁 Scanning folder: driver_documents/${driverId}/`);
        
        const folderContents = await listAll(folderRef);
        
        const targetPrefix = documentType === 'license' ? 'driving_license' : 'police_report';
        console.log(`🔍 Looking for files starting with: ${targetPrefix}`);
        
        const matchingFile = folderContents.items.find(item => {
          const fileName = item.name.toLowerCase();
          return fileName.startsWith(targetPrefix.toLowerCase()) && fileName.endsWith('.pdf');
        });
        
        if (matchingFile) {
          console.log(`🎯 FOUND MATCHING FILE: ${matchingFile.name}`);
          foundFileName = matchingFile.name;
          documentUrl = await getDownloadURL(matchingFile);
        }
        
      } catch (listError) {
        console.log(`❌ Folder listing failed:`, listError);
        
        // Method 2: Try direct paths based on known patterns
        const baseFileName = documentType === 'license' ? 'driving_license' : 'police_report';
        
        const directPaths = [
          `driver_documents/${driverId}/${baseFileName}.pdf`,
          `driver_documents/${driverId}/${documentType}.pdf`,
          `driver_documents/${driverId}/${baseFileName}_${Date.now()}.pdf`
        ];
        
        for (const testPath of directPaths) {
          try {
            console.log(`🧪 Testing direct path: ${testPath}`);
            const documentRef = ref(storage, testPath);
            documentUrl = await getDownloadURL(documentRef);
            foundFileName = testPath.split('/').pop();
            break;
          } catch (pathError) {
            continue;
          }
        }
      }

      if (documentUrl) {
        setDocuments(prev => ({
          ...prev,
          [documentType]: {
            url: documentUrl,
            type: documentType,
            loading: false,
            error: null
          }
        }));
      } else {
        setDocuments(prev => ({
          ...prev,
          [documentType]: {
            url: createMockDocument(documentType, driverId),
            type: documentType,
            loading: false,
            error: `${documentType === 'license' ? 'Driving license' : 'Police clearance report'} not found`
          }
        }));
      }
      
    } catch (error: any) {
      console.error(`💥 CRITICAL ERROR fetching ${documentType}:`, error);
      
      setDocuments(prev => ({
        ...prev,
        [documentType]: {
          url: createMockDocument(documentType, driverId),
          type: documentType,
          loading: false,
          error: error.message
        }
      }));
    }
  };

  const createMockDocument = (documentType: string, driverId: string) => {
    // Create a mock document showing what would be displayed if the driver had uploaded their document
    const mockContent = `
      <html>
        <head>
          <meta charset="utf-8">
          <title>Document Viewer - ${documentType.toUpperCase()}</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              padding: 20px;
              background: #f5f5f5;
              margin: 0;
            }
            .container {
              max-width: 800px;
              margin: 0 auto;
              background: white;
              border-radius: 8px;
              box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              overflow: hidden;
            }
            .header {
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
              padding: 30px;
              text-align: center;
            }
            .header h1 {
              margin: 0;
              font-size: 28px;
              font-weight: 300;
            }
            .header p {
              margin: 10px 0 0 0;
              opacity: 0.9;
            }
            .content {
              padding: 30px;
            }
            .document-info {
              background: #f8f9fa;
              border-left: 4px solid #667eea;
              padding: 20px;
              margin: 20px 0;
            }
            .info-row {
              display: flex;
              justify-content: space-between;
              margin: 10px 0;
              padding: 8px 0;
              border-bottom: 1px solid #eee;
            }
            .info-row:last-child {
              border-bottom: none;
            }
            .label {
              font-weight: 600;
              color: #495057;
              flex: 1;
            }
            .value {
              flex: 2;
              color: #212529;
            }
            .status-badge {
              display: inline-block;
              padding: 4px 12px;
              border-radius: 20px;
              font-size: 12px;
              font-weight: 600;
              text-transform: uppercase;
            }
            .status-demo {
              background: #fff3cd;
              color: #856404;
              border: 1px solid #ffeaa7;
            }
            .alert {
              background: #e3f2fd;
              border: 1px solid #2196f3;
              color: #1565c0;
              padding: 15px;
              border-radius: 4px;
              margin: 20px 0;
            }
            .alert-icon {
              font-size: 18px;
              margin-right: 8px;
            }
            .footer {
              background: #f8f9fa;
              padding: 20px;
              text-align: center;
              color: #6c757d;
              font-size: 14px;
              border-top: 1px solid #dee2e6;
            }
            .document-placeholder {
              border: 2px dashed #ccc;
              padding: 40px;
              text-align: center;
              color: #666;
              margin: 20px 0;
              border-radius: 8px;
              background: #fafafa;
            }
            .document-icon {
              font-size: 48px;
              margin-bottom: 15px;
              color: #999;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>${documentType === 'license' ? '🚗 Driving License' : '🛡️ Police Clearance Report'}</h1>
              <p>Admin Document Viewer</p>
            </div>
            
            <div class="content">
              <div class="alert">
                <span class="alert-icon">ℹ️</span>
                <strong>Admin View:</strong> This is where uploaded driver documents would be displayed. 
                The actual document is not available in storage.
              </div>

              <div class="document-info">
                <h3>Document Information</h3>
                <div class="info-row">
                  <span class="label">Document Type:</span>
                  <span class="value">${documentType === 'license' ? 'Driving License' : 'Police Clearance Report'}</span>
                </div>
                <div class="info-row">
                  <span class="label">Driver ID:</span>
                  <span class="value">${driverId.substring(0, 12)}...</span>
                </div>
                <div class="info-row">
                  <span class="label">Expected Format:</span>
                  <span class="value">PDF Document</span>
                </div>
                <div class="info-row">
                  <span class="label">Storage Status:</span>
                  <span class="value">
                    <span class="status-badge status-demo">Not Found</span>
                  </span>
                </div>
                <div class="info-row">
                  <span class="label">Last Checked:</span>
                  <span class="value">${new Date().toLocaleString()}</span>
                </div>
              </div>

              <div class="document-placeholder">
                <div class="document-icon">📄</div>
                <h3>Document Not Available</h3>
                <p>The ${documentType === 'license' ? 'driving license' : 'police clearance report'} for this driver is not found in Firebase Storage.</p>
                <p><strong>Possible reasons:</strong></p>
                <ul style="text-align: left; display: inline-block;">
                  <li>Driver hasn't uploaded this document yet</li>
                  <li>Document is stored in a different storage location</li>
                  <li>Storage path configuration needs to be updated</li>
                  <li>File permissions may need adjustment</li>
                </ul>
              </div>

              ${documentType === 'license' ? `
              <div class="document-info">
                <h3>Expected License Information</h3>
                <div class="info-row">
                  <span class="label">License Number:</span>
                  <span class="value">Would be displayed from uploaded document</span>
                </div>
                <div class="info-row">
                  <span class="label">License Class:</span>
                  <span class="value">Would be extracted from document</span>
                </div>
                <div class="info-row">
                  <span class="label">Issue Date:</span>
                  <span class="value">Would be shown from document</span>
                </div>
                <div class="info-row">
                  <span class="label">Expiry Date:</span>
                  <span class="value">Would be verified from document</span>
                </div>
              </div>
              ` : `
              <div class="document-info">
                <h3>Expected Police Report Information</h3>
                <div class="info-row">
                  <span class="label">Report Number:</span>
                  <span class="value">Would be displayed from uploaded document</span>
                </div>
                <div class="info-row">
                  <span class="label">Issue Date:</span>
                  <span class="value">Would be shown from document</span>
                </div>
                <div class="info-row">
                  <span class="label">Clearance Status:</span>
                  <span class="value">Would be verified from document</span>
                </div>
                <div class="info-row">
                  <span class="label">Validity:</span>
                  <span class="value">Would be checked from document</span>
                </div>
              </div>
              `}
            </div>
            
            <div class="footer">
              <p><strong>QuickCare Admin System</strong> - Document Management Interface</p>
              <p>In production, this would display the actual uploaded driver documents</p>
            </div>
          </div>
        </body>
      </html>
    `;
    
    return `data:text/html;charset=utf-8,${encodeURIComponent(mockContent)}`;
  };

  const approveDriver = async (driverId: string) => {
    try {
      const driverRef = doc(db, "driver_profiles", driverId);
      await updateDoc(driverRef, {
        status: "approved",
        isVerified: true,
        updatedAt: new Date()
      });
      
      // Update local state
      setDrivers(prev => prev.map(driver => 
        driver.id === driverId 
          ? { ...driver, status: "approved", isVerified: true }
          : driver
      ));
      
      console.log("Driver approved successfully");
    } catch (error) {
      console.error("Error approving driver:", error);
    }
  };

  const rejectDriver = async (driverId: string) => {
    try {
      const driverRef = doc(db, "driver_profiles", driverId);
      await updateDoc(driverRef, {
        status: "rejected",
        isVerified: false,
        updatedAt: new Date()
      });
      
      // Update local state
      setDrivers(prev => prev.map(driver => 
        driver.id === driverId 
          ? { ...driver, status: "rejected", isVerified: false }
          : driver
      ));
      
      console.log("Driver rejected successfully");
    } catch (error) {
      console.error("Error rejecting driver:", error);
    }
  };

  const filteredDrivers = drivers.filter(driver => {
    const matchesSearch = driver.fullName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         driver.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         driver.licenseNumber?.includes(searchTerm);
    const matchesStatus = statusFilter === "all" || driver.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case "approved": return "default";
      case "rejected": return "destructive";
      case "pending": return "secondary";
      default: return "outline";
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="flex items-center space-x-2">
          <RefreshCw className="h-4 w-4 animate-spin" />
          <span className="text-lg">Loading drivers...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Driver Management</h1>
        <p className="text-gray-500 mt-2">Manage driver profiles, view documents, and approve drivers</p>
      </div>

      {/* Info Alert */}
      <Alert>
        <AlertCircle className="h-4 w-4" />
        <AlertDescription>
          <strong>Admin Document Viewer:</strong> View documents that drivers have uploaded during registration. 
          Click "View License" or "View Report" to open documents in a modal dialog.
        </AlertDescription>
      </Alert>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Driver Profiles ({drivers.length} total, {filteredDrivers.length} filtered)
          </CardTitle>
          <div className="flex gap-4 mt-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search by name, email, or license..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-9"
              />
            </div>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-48">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="approved">Approved</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="rejected">Rejected</SelectItem>
              </SelectContent>
            </Select>
            <Button onClick={fetchDrivers} variant="outline" size="sm">
              <RefreshCw className="h-4 w-4 mr-2" />
              Refresh
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {filteredDrivers.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              {drivers.length === 0 ? "No drivers found" : "No drivers match your search criteria"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Driver Info</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>License</TableHead>
                  <TableHead>Documents</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredDrivers.map((driver) => (
                  <TableRow key={driver.id}>
                    <TableCell>
                      <div>
                        <div className="font-medium">{driver.fullName}</div>
                        <div className="text-sm text-gray-500">{driver.email}</div>
                        <div className="text-xs text-gray-400">ID: {driver.id}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm">{driver.phoneNumber}</div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <span className="font-mono text-sm">{driver.licenseNumber}</span>
                        <div className="flex items-center gap-1 mt-1">
                        
                        </div>
                      </div>
                    </TableCell>
          
                    <TableCell>
                      <div className="flex gap-2">
                        <Dialog onOpenChange={(open) => {
                          if (!open) {
                            setDocuments(prev => ({
                              ...prev,
                              license: null,
                              police_report: null
                            }));
                          }
                        }}>
                          <DialogTrigger asChild>
                            <Button 
                              variant="outline" 
                              size="sm"
                              onClick={() => fetchDocument(driver.id, 'license')}
                              className="text-blue-600 hover:text-blue-700"
                            >
                              <Eye className="h-3 w-3 mr-1" />
                              View License
                            </Button>
                          </DialogTrigger>
                          <DialogContent className="max-w-4xl max-h-[85vh] flex flex-col p-0">
                            <DialogHeader className="px-6 py-4 border-b">
                              <DialogTitle className="flex items-center gap-2 text-xl">
                                {documents.license?.type === 'license' ? (
                                  <>Driver Review</>
                                ) : (
                                  <> Police Clearance Review</>
                                )}
                              </DialogTitle>
                              <DialogDescription className="text-base">
                                Reviewing documents for <span className="font-semibold">{driver.fullName}</span>
                              </DialogDescription>
                            </DialogHeader>

                            <ScrollArea className="flex-1">
                              <div className="px-6 py-4">
                                <Tabs defaultValue="document" className="w-full">
                                  <TabsList className="grid w-full grid-cols-3 mb-4">
                                    <TabsTrigger value="document">Document View</TabsTrigger>
                                    <TabsTrigger value="info">Driver Info</TabsTrigger>
                                    <TabsTrigger value="verification">Verification</TabsTrigger>
                                  </TabsList>

                                  <TabsContent value="document" className="mt-0">
                                    <Card className="border-0 shadow-none">
                                      <CardHeader className="px-0 pt-0">
                                        <CardTitle className="text-lg flex items-center gap-2">
                                          <FileText className="h-5 w-5" />
                                          Driver Documents
                                        </CardTitle>
                                        <CardDescription>
                                          Review both driving license and police clearance report
                                        </CardDescription>
                                      </CardHeader>
                                      <CardContent className="space-y-4 px-0">
                                        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                                          {/* Driving License Section */}
                                          <div className="space-y-3">
                                            <div className="flex items-center justify-between">
                                              <h3 className="text-sm font-semibold flex items-center gap-2">
                                                Driving License
                                              </h3>
                                              <Button 
                                                variant="ghost" 
                                                size="sm" 
                                                onClick={() => fetchDocument(driver.id, 'license')}
                                              >
                                                <RefreshCw className="h-4 w-4 mr-1" />
                                                Refresh
                                              </Button>
                                            </div>
                                            
                                            <div className="border rounded-lg overflow-hidden bg-secondary/5">
                                              <div className="bg-secondary/20 p-2 flex items-center justify-between">
                                                <span className="text-sm font-medium">License Preview</span>
                                                {documents.license?.url && !documents.license.error && (
                                                  <Button 
                                                    variant="ghost" 
                                                    size="sm" 
                                                    onClick={() => window.open(documents.license.url, '_blank')}
                                                  >
                                                    <Eye className="h-4 w-4 mr-1" />
                                                    Open
                                                  </Button>
                                                )}
                                              </div>
                                              <ScrollArea className="h-[400px]">
                                                {documents.license?.loading ? (
                                                  <div className="flex flex-col items-center justify-center h-full p-4">
                                                    <RefreshCw className="h-8 w-8 animate-spin mb-2" />
                                                    <p className="text-sm text-muted-foreground">Loading license...</p>
                                                  </div>
                                                ) : documents.license?.url && !documents.license.error ? (
                                                  <iframe 
                                                    src={documents.license.url} 
                                                    title={`License for ${driver.fullName}`}
                                                    className="w-full h-full"
                                                  />
                                                ) : (
                                                  <div className="flex flex-col items-center justify-center h-full p-4">
                                                    <FileText className="h-12 w-12 text-muted-foreground mb-2" />
                                                    <p className="text-sm font-medium mb-1">No License Loaded</p>
                                                    <p className="text-sm text-muted-foreground mb-4">
                                                      {documents.license?.error || "Click refresh to load the license"}
                                                    </p>
                                                  </div>
                                                )}
                                              </ScrollArea>
                                            </div>
                                          </div>

                                          {/* Police Report Section */}
                                          <div className="space-y-3">
                                            <div className="flex items-center justify-between">
                                              <h3 className="text-sm font-semibold flex items-center gap-2">
                                                 Police Report
                                              </h3>
                                              <Button 
                                                variant="ghost" 
                                                size="sm" 
                                                onClick={() => fetchDocument(driver.id, 'police_report')}
                                              >
                                                <RefreshCw className="h-4 w-4 mr-1" />
                                                Refresh
                                              </Button>
                                            </div>
                                            
                                            <div className="border rounded-lg overflow-hidden bg-secondary/5">
                                              <div className="bg-secondary/20 p-2 flex items-center justify-between">
                                                <span className="text-sm font-medium">Report Preview</span>
                                                {documents.police_report?.url && !documents.police_report.error && (
                                                  <Button 
                                                    variant="ghost" 
                                                    size="sm" 
                                                    onClick={() => window.open(documents.police_report.url, '_blank')}
                                                  >
                                                    <Eye className="h-4 w-4 mr-1" />
                                                    Open
                                                  </Button>
                                                )}
                                              </div>
                                              <ScrollArea className="h-[400px]">
                                                {documents.police_report?.loading ? (
                                                  <div className="flex flex-col items-center justify-center h-full p-4">
                                                    <RefreshCw className="h-8 w-8 animate-spin mb-2" />
                                                    <p className="text-sm text-muted-foreground">Loading report...</p>
                                                  </div>
                                                ) : documents.police_report?.url && !documents.police_report.error ? (
                                                  <iframe 
                                                    src={documents.police_report.url} 
                                                    title={`Police Report for ${driver.fullName}`}
                                                    className="w-full h-full"
                                                  />
                                                ) : (
                                                  <div className="flex flex-col items-center justify-center h-full p-4">
                                                    <FileText className="h-12 w-12 text-muted-foreground mb-2" />
                                                    <p className="text-sm font-medium mb-1">No Report Loaded</p>
                                                    <p className="text-sm text-muted-foreground mb-4">
                                                      {documents.police_report?.error || "Click refresh to load the report"}
                                                    </p>
                                                  </div>
                                                )}
                                              </ScrollArea>
                                            </div>
                                          </div>
                                        </div>

                                        {(documents.license?.error || documents.police_report?.error) && (
                                          <Alert variant="destructive">
                                            <AlertCircle className="h-4 w-4" />
                                            <AlertDescription>
                                              {documents.license?.error && `License: ${documents.license.error}`}
                                              {documents.license?.error && documents.police_report?.error && <br />}
                                              {documents.police_report?.error && `Police Report: ${documents.police_report.error}`}
                                            </AlertDescription>
                                          </Alert>
                                        )}
                                      </CardContent>
                                    </Card>
                                  </TabsContent>

                                  <TabsContent value="info" className="mt-0">
                                    <Card className="border-0 shadow-none">
                                      <CardHeader className="px-0 pt-0">
                                        <CardTitle className="text-lg flex items-center gap-2">
                                          <Users className="h-5 w-5" />
                                          Driver Information
                                        </CardTitle>
                                      </CardHeader>
                                      <CardContent className="px-0">
                                        <div className="grid grid-cols-2 gap-4">
                                          <div className="space-y-3">
                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-2">Personal Details</h4>
                                              <div className="space-y-2 text-sm">
                                                <p><span className="text-muted-foreground">Full Name:</span> {driver.fullName}</p>
                                                <p><span className="text-muted-foreground">Email:</span> {driver.email}</p>
                                                <p><span className="text-muted-foreground">Phone:</span> {driver.phoneNumber}</p>
                                              </div>
                                            </div>
                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-2">License Information</h4>
                                              <div className="space-y-2 text-sm">
                                                <p><span className="text-muted-foreground">License Number:</span> {driver.licenseNumber}</p>
                                                <p><span className="text-muted-foreground">Status:</span> 
                                                  <Badge variant={getStatusColor(driver.status)} className="ml-2">
                                                    {driver.status}
                                                  </Badge>
                                                </p>
                                              </div>
                                            </div>
                                          </div>
                                          <div className="space-y-3">
                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-2">Performance Metrics</h4>
                                              <div className="space-y-2 text-sm">
                                                <p><span className="text-muted-foreground">Total Trips:</span> {driver.totalTrips || 0}</p>
                                                <p><span className="text-muted-foreground">Rating:</span> {driver.rating || 'N/A'}</p>
                                              </div>
                                            </div>
                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-2">Account Status</h4>
                                              <div className="space-y-2 text-sm">
                                                <p>
                                                  <span className="text-muted-foreground">Verification:</span>
                                                  {driver.isVerified ? (
                                                    <Badge variant="default" className="ml-2 bg-green-600">Verified</Badge>
                                                  ) : (
                                                    <Badge variant="secondary" className="ml-2">Pending</Badge>
                                                  )}
                                                </p>
                                                <p><span className="text-muted-foreground">Member Since:</span> {driver.createdAt?.toDate().toLocaleDateString()}</p>
                                              </div>
                                            </div>
                                          </div>
                                        </div>
                                      </CardContent>
                                    </Card>
                                  </TabsContent>

                                  <TabsContent value="verification" className="mt-0">
                                    <Card className="border-0 shadow-none">
                                      <CardHeader className="px-0 pt-0">
                                        <CardTitle className="text-lg flex items-center gap-2">
                                          <CheckCircle className="h-5 w-5" />
                                          Document Verification
                                        </CardTitle>
                                        <CardDescription>
                                          Review and verify the authenticity of the driver's documents
                                        </CardDescription>
                                      </CardHeader>
                                      <CardContent className="px-0">
                                        <ScrollArea className="h-[400px] pr-4">
                                          <div className="space-y-6">
                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-3">Verification Checklist</h4>
                                              <div className="space-y-4">
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Document Authenticity</p>
                                                    <p className="text-sm text-muted-foreground">Verify that the document appears genuine and hasn't been altered</p>
                                                  </div>
                                                </div>
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Personal Information Match</p>
                                                    <p className="text-sm text-muted-foreground">Confirm that the details match the driver's profile</p>
                                                  </div>
                                                </div>
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Document Validity</p>
                                                    <p className="text-sm text-muted-foreground">Check if the document is current and not expired</p>
                                                  </div>
                                                </div>
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Photo Verification</p>
                                                    <p className="text-sm text-muted-foreground">Verify that the photo matches the driver's appearance</p>
                                                  </div>
                                                </div>
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Document Format</p>
                                                    <p className="text-sm text-muted-foreground">Ensure the document follows required format and standards</p>
                                                  </div>
                                                </div>
                                                <div className="flex items-start gap-3 p-2 hover:bg-secondary/5 rounded-md transition-colors">
                                                  <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                                                  <div>
                                                    <p className="font-medium">Issuing Authority</p>
                                                    <p className="text-sm text-muted-foreground">Verify the document is issued by a recognized authority</p>
                                                  </div>
                                                </div>
                                              </div>
                                            </div>

                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-3">Additional Verification Notes</h4>
                                              <div className="space-y-3 text-sm text-muted-foreground">
                                                <p>• Check for any restrictions or conditions on the license</p>
                                                <p>• Verify the document's security features if present</p>
                                                <p>• Ensure all required fields are filled and legible</p>
                                                <p>• Check for any endorsements or special permissions</p>
                                              </div>
                                            </div>

                                            <div className="bg-secondary/10 p-4 rounded-lg">
                                              <h4 className="font-semibold mb-3">Admin Decision</h4>
                                              <div className="space-y-4">
                                                <p className="text-sm text-muted-foreground">
                                                  Make a decision based on the document review and verification checklist
                                                </p>
                                                <div className="flex gap-3">
                                                  <Button 
                                                    className="flex-1 bg-green-600 hover:bg-green-700"
                                                    onClick={() => {
                                                      approveDriver(driver.id);
                                                      setDocuments(prev => ({
                                                        ...prev,
                                                        license: null,
                                                        police_report: null
                                                      }));
                                                    }}
                                                    disabled={driver.status !== 'pending'}
                                                  >
                                                    <CheckCircle className="h-4 w-4 mr-2" />
                                                    Approve Documents
                                                  </Button>
                                                  <Button 
                                                    variant="destructive"
                                                    className="flex-1"
                                                    onClick={() => {
                                                      rejectDriver(driver.id);
                                                      setDocuments(prev => ({
                                                        ...prev,
                                                        license: null,
                                                        police_report: null
                                                      }));
                                                    }}
                                                    disabled={driver.status !== 'pending'}
                                                  >
                                                    <XCircle className="h-4 w-4 mr-2" />
                                                    Reject Documents
                                                  </Button>
                                                </div>
                                                {driver.status !== 'pending' && (
                                                  <Alert>
                                                    <AlertCircle className="h-4 w-4" />
                                                    <AlertDescription>
                                                      This driver's documents have already been {driver.status}.
                                                      Current status cannot be changed.
                                                    </AlertDescription>
                                                  </Alert>
                                                )}
                                              </div>
                                            </div>
                                          </div>
                                        </ScrollArea>
                                      </CardContent>
                                    </Card>
                                  </TabsContent>
                                </Tabs>
                              </div>
                            </ScrollArea>

                            <DialogFooter className="px-6 py-4 border-t mt-auto">
                              <div className="w-full flex justify-between items-center">
                                <div className="text-sm text-muted-foreground">
                                  Last updated: {driver.updatedAt?.toDate().toLocaleString()}
                                </div>
                                <Button variant="outline" onClick={() => setDocuments(prev => ({
                                  ...prev,
                                  license: null,
                                  police_report: null
                                }))}>
                                  Close Preview
                                </Button>
                              </div>
                            </DialogFooter>
                          </DialogContent>
                        </Dialog>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getStatusColor(driver.status)}>
                        {driver.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        {driver.status === "pending" && (
                          <>
                            <Button 
                              variant="default" 
                              size="sm"
                              onClick={() => approveDriver(driver.id)}
                              className="bg-green-600 hover:bg-green-700"
                            >
                              <CheckCircle className="h-3 w-3 mr-1" />
                              Approve
                            </Button>
                            <Button 
                              variant="destructive" 
                              size="sm"
                              onClick={() => rejectDriver(driver.id)}
                            >
                              <XCircle className="h-3 w-3 mr-1" />
                              Reject
                            </Button>
                          </>
                        )}
                 
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}