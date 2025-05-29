
import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Search, Users, Eye, Ban, CheckCircle, RefreshCw } from "lucide-react";
import { collection, getDocs, query, orderBy } from "firebase/firestore";
import { db } from "@/lib/firebase";

interface User {
  id: string;
  fullName: string;
  emergencyContact: string;
  emergencyEmail: string;
  bloodType: string;
  allergies: string;
  medicalConditions: string;
  medications: string;
  isActive?: boolean;
  updatedAt: any;
}

export function UserManagement() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      console.log("=== USER MANAGEMENT: Starting data fetch ===");
      console.log("Firebase DB instance:", db);
      console.log("Attempting to connect to Firestore...");
      
      setLoading(true);
      setError(null);
      
      console.log("Fetching user_profiles collection...");
      const userCollection = collection(db, "user_profiles");
      console.log("Collection reference created:", userCollection);
      
      const simpleSnapshot = await getDocs(userCollection);
      console.log("Simple query result - Document count:", simpleSnapshot.size);
      console.log("Simple query empty?", simpleSnapshot.empty);
      
      if (simpleSnapshot.empty) {
        console.log("Collection 'user_profiles' is empty or doesn't exist");
        setUsers([]);
        setError("No users found. The collection might be empty or have a different name.");
        return;
      }

      let querySnapshot;
      try {
        console.log("Attempting ordered query...");
        const q = query(userCollection, orderBy("updatedAt", "desc"));
        querySnapshot = await getDocs(q);
        console.log("Ordered query successful - Document count:", querySnapshot.size);
      } catch (orderError) {
        console.log("Ordered query failed, falling back to simple query:", orderError);
        querySnapshot = simpleSnapshot;
      }
      
      const usersData: User[] = [];
      querySnapshot.forEach((doc) => {
        const data = doc.data();
        console.log("Processing user document:", {
          id: doc.id,
          hasFullName: !!data.fullName,
          hasEmergencyContact: !!data.emergencyContact,
          hasBloodType: !!data.bloodType,
          dataKeys: Object.keys(data)
        });
        
        usersData.push({
          id: doc.id,
          fullName: data.fullName || "Unknown User",
          emergencyContact: data.emergencyContact || "No contact",
          emergencyEmail: data.emergencyEmail || "No email",
          bloodType: data.bloodType || "Unknown",
          allergies: data.allergies || "None",
          medicalConditions: data.medicalConditions || "None",
          medications: data.medications || "None",
          isActive: data.isActive !== undefined ? data.isActive : true,
          updatedAt: data.updatedAt || null
        });
      });
      
      console.log("Processed users data:", usersData);
      console.log("Total users processed:", usersData.length);
      setUsers(usersData);
      
      if (usersData.length === 0) {
        setError("Users collection exists but contains no valid user documents");
      }
      
    } catch (error: any) {
      console.error("=== USER MANAGEMENT: Error details ===");
      console.error("Error type:", error.constructor.name);
      console.error("Error message:", error.message);
      console.error("Error code:", error.code);
      console.error("Full error:", error);
      console.error("Error stack:", error.stack);
      
      setError(`Failed to fetch users: ${error.message || "Unknown error"}`);
      setUsers([]);
    } finally {
      setLoading(false);
      console.log("=== USER MANAGEMENT: Fetch completed ===");
    }
  };

  const filteredUsers = users.filter(user => {
    return user.fullName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
           user.emergencyEmail?.toLowerCase().includes(searchTerm.toLowerCase()) ||
           user.emergencyContact?.includes(searchTerm);
  });

  const getUserStatusColor = (isActive: boolean) => {
    return isActive ? "default" : "secondary";
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg">Loading users...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-64 space-y-4">
        <div className="text-lg text-red-600">{error}</div>
        <Button onClick={fetchUsers} variant="outline">
          <RefreshCw className="h-4 w-4 mr-2" />
          Retry
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">User Management</h1>
        <p className="text-gray-500 mt-2">Monitor and manage registered users</p>
        {users.length === 0 && (
          <p className="text-orange-600 mt-2">No users found in the database.</p>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            User Management ({users.length} total, {filteredUsers.length} filtered)
          </CardTitle>
          <div className="flex gap-4 mt-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search by name, email, or contact..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-9"
              />
            </div>
            <Button variant="outline" size="sm" onClick={fetchUsers}>
              <RefreshCw className="h-4 w-4 mr-1" />
              Refresh
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {filteredUsers.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              {users.length === 0 ? "No users in database" : "No users match your search criteria"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Contact Info</TableHead>
                  <TableHead>Emergency Contact</TableHead>
                  <TableHead>Medical Info</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Last Updated</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredUsers.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell>
                      <div>
                        <div className="font-medium">{user.fullName}</div>
                        <div className="text-sm text-gray-500">ID: {user.id}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="text-sm">{user.emergencyEmail}</div>
                        <div className="text-sm text-gray-500">{user.emergencyContact}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm">{user.emergencyContact || "N/A"}</div>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm space-y-1">
                        <div>Blood: {user.bloodType || "N/A"}</div>
                        <div>Allergies: {user.allergies || "None"}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getUserStatusColor(user.isActive || true)}>
                        {user.isActive !== false ? "Active" : "Inactive"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {user.updatedAt?.toDate?.()?.toLocaleDateString() || "Never"}
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
