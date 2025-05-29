
import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Search, Monitor, Eye, RefreshCw } from "lucide-react";
import { collection, getDocs, query, orderBy } from "firebase/firestore";
import { db } from "@/lib/firebase";

interface AmbulanceBooking {
  id: string;
  requesterId: string;
  patientName: string;
  patientPhone: string;
  location: [number, number];
  emergencyType: string;
  status: string;
  createdAt: any;
  completedAt?: any;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  injuredPersons?: string;
  notes?: string;
}

export function AmbulanceBookings() {
  const [bookings, setBookings] = useState<AmbulanceBooking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  useEffect(() => {
    fetchBookings();
  }, []);

  const fetchBookings = async () => {
    try {
      console.log("=== AMBULANCE BOOKINGS: Starting data fetch ===");
      console.log("Firebase DB instance:", db);
      
      setLoading(true);
      setError(null);
      
      console.log("Fetching ambulance_bookings collection...");
      const bookingsCollection = collection(db, "ambulance_bookings");
      console.log("Collection reference created:", bookingsCollection);
      
      const simpleSnapshot = await getDocs(bookingsCollection);
      console.log("Simple query result - Document count:", simpleSnapshot.size);
      console.log("Simple query empty?", simpleSnapshot.empty);
      
      if (simpleSnapshot.empty) {
        console.log("Collection 'ambulance_bookings' is empty or doesn't exist");
        setBookings([]);
        setError("No ambulance bookings found. The collection might be empty or have a different name.");
        return;
      }

      let querySnapshot;
      try {
        console.log("Attempting ordered query...");
        const q = query(bookingsCollection, orderBy("createdAt", "desc"));
        querySnapshot = await getDocs(q);
        console.log("Ordered query successful - Document count:", querySnapshot.size);
      } catch (orderError) {
        console.log("Ordered query failed, falling back to simple query:", orderError);
        querySnapshot = simpleSnapshot;
      }
      
      const bookingsData: AmbulanceBooking[] = [];
      querySnapshot.forEach((doc) => {
        const data = doc.data();
        console.log("Processing booking document:", {
          id: doc.id,
          hasPatientName: !!data.patientName,
          hasPatientPhone: !!data.patientPhone,
          hasStatus: !!data.status,
          hasLocation: !!data.location,
          dataKeys: Object.keys(data)
        });
        
        bookingsData.push({
          id: doc.id,
          requesterId: data.requesterId || "Unknown",
          patientName: data.patientName || "Unknown Patient",
          patientPhone: data.patientPhone || "No phone",
          location: data.location || [0, 0],
          emergencyType: data.emergencyType || "Unknown",
          status: data.status || "pending",
          createdAt: data.createdAt || null,
          completedAt: data.completedAt || null,
          driverId: data.driverId || undefined,
          driverName: data.driverName || undefined,
          driverPhone: data.driverPhone || undefined,
          injuredPersons: data.injuredPersons || undefined,
          notes: data.notes || undefined
        });
      });
      
      console.log("Processed bookings data:", bookingsData);
      console.log("Total bookings processed:", bookingsData.length);
      setBookings(bookingsData);
      
      if (bookingsData.length === 0) {
        setError("Bookings collection exists but contains no valid booking documents");
      }
      
    } catch (error: any) {
      console.error("=== AMBULANCE BOOKINGS: Error details ===");
      console.error("Error type:", error.constructor.name);
      console.error("Error message:", error.message);
      console.error("Error code:", error.code);
      console.error("Full error:", error);
      
      setError(`Failed to fetch bookings: ${error.message || "Unknown error"}`);
      setBookings([]);
    } finally {
      setLoading(false);
      console.log("=== AMBULANCE BOOKINGS: Fetch completed ===");
    }
  };

  const filteredBookings = bookings.filter(booking => {
    const matchesSearch = booking.patientName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         booking.emergencyType?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         booking.patientPhone?.includes(searchTerm);
    const matchesStatus = statusFilter === "all" || booking.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case "pending": return "destructive";
      case "active": return "default";
      case "completed": return "secondary";
      case "cancelled": return "outline";
      default: return "outline";
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg">Loading ambulance bookings...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-64 space-y-4">
        <div className="text-lg text-red-600">{error}</div>
        <Button onClick={fetchBookings} variant="outline">
          <RefreshCw className="h-4 w-4 mr-2" />
          Retry
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Ambulance Bookings</h1>
        <p className="text-gray-500 mt-2">Monitor and manage ambulance bookings</p>
        {bookings.length === 0 && (
          <p className="text-orange-600 mt-2">No ambulance bookings found in the database.</p>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Monitor className="h-5 w-5" />
            Ambulance Bookings Management ({bookings.length} total, {filteredBookings.length} filtered)
          </CardTitle>
          <div className="flex gap-4 mt-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search by patient name, phone, or emergency type..."
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
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
                <SelectItem value="cancelled">Cancelled</SelectItem>
              </SelectContent>
            </Select>
            <Button variant="outline" size="sm" onClick={fetchBookings}>
              <RefreshCw className="h-4 w-4 mr-1" />
              Refresh
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {filteredBookings.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              {bookings.length === 0 ? "No ambulance bookings in database" : "No bookings match your search criteria"}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Patient</TableHead>
                  <TableHead>Emergency Details</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Driver</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Timestamps</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredBookings.map((booking) => (
                  <TableRow key={booking.id}>
                    <TableCell>
                      <div>
                        <div className="font-medium">{booking.patientName || "N/A"}</div>
                        <div className="text-sm text-gray-500">{booking.patientPhone}</div>
                        <div className="text-xs text-gray-400">ID: {booking.requesterId}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="font-medium">{booking.emergencyType || "N/A"}</div>
                        {booking.injuredPersons && (
                          <div className="text-sm text-gray-500">Injured: {booking.injuredPersons}</div>
                        )}
                        {booking.notes && (
                          <div className="text-xs text-gray-400">Notes: {booking.notes}</div>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      {booking.location && Array.isArray(booking.location) && booking.location.length >= 2 ? (
                        <div className="text-sm">
                          {booking.location[0].toFixed(4)}, {booking.location[1].toFixed(4)}
                        </div>
                      ) : (
                        <div className="text-sm text-gray-500">No location</div>
                      )}
                    </TableCell>
                    <TableCell>
                      {booking.driverName ? (
                        <div>
                          <div className="font-medium">{booking.driverName}</div>
                          <div className="text-sm text-gray-500">{booking.driverPhone}</div>
                          <div className="text-xs text-gray-400">ID: {booking.driverId}</div>
                        </div>
                      ) : (
                        <div className="text-sm text-gray-500">No driver assigned</div>
                      )}
                    </TableCell>
                    <TableCell>
                      <Badge variant={getStatusColor(booking.status)}>
                        {booking.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm space-y-1">
                        <div>Created: {booking.createdAt?.toDate?.()?.toLocaleDateString() || "N/A"}</div>
                        {booking.completedAt && (
                          <div>Completed: {booking.completedAt?.toDate?.()?.toLocaleDateString()}</div>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Button variant="outline" size="sm">
                        <Eye className="h-4 w-4 mr-1" />
                        View Details
                      </Button>
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
