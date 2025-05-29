import { useState, useEffect, useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { collection, query, getDocs, where, orderBy, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, PieChart, Pie, Cell, LineChart, Line } from "recharts";
import { Button } from "@/components/ui/button";
import { Download } from "lucide-react";

interface ReportsProps {
  selectedReport: string;
  dateRange: {
    from: Date;
    to: Date;
  };
}

interface EmergencyRequest {
  id: string;
  type: string;
  status: string;
  createdAt: Date;
  location: {
    latitude: number;
    longitude: number;
  };
  patientName: string;
  contactNumber: string;
  priority: 'high' | 'medium' | 'low';
  description: string;
}

interface AmbulanceRequest {
  id: string;
  status: string;
  createdAt: Date;
  requestType: 'accident' | 'medical' | 'transfer' | 'other';
  location: {
    pickup: string;
    description: string;
  };
  requesterName: string;
  contactNumber: string;
  patientCount: number;
  urgencyLevel: 'critical' | 'moderate' | 'stable';
}

export function Reports({ selectedReport, dateRange }: ReportsProps) {
  const [emergencies, setEmergencies] = useState<EmergencyRequest[]>([]);
  const [ambulanceRequests, setAmbulanceRequests] = useState<AmbulanceRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const verifyCollections = async () => {
      try {
        // Check if collections exist
        const emergencySnapshot = await getDocs(collection(db, "emergency_requests"));
        const ambulanceSnapshot = await getDocs(collection(db, "ambulance_requests"));

        console.log('Collections verification:', {
          'emergency_requests': emergencySnapshot.size,
          'ambulance_requests': ambulanceSnapshot.size
        });

        // If both collections are empty, we might want to add some sample data
        if (emergencySnapshot.empty && ambulanceSnapshot.empty) {
          console.log('No data found in collections');
          setError('No data available in the database. Please add some emergency requests and ambulance requests.');
          return false;
        }

        return true;
      } catch (error) {
        console.error('Error verifying collections:', error);
        setError('Failed to connect to the database. Please check your connection.');
        return false;
      }
    };

    const fetchData = async () => {
      try {
        setLoading(true);
        setError(null);

        // First verify collections
        const collectionsExist = await verifyCollections();
        if (!collectionsExist) {
          setLoading(false);
          return;
        }

        console.log('Fetching data for date range:', {
          from: dateRange.from.toISOString(),
          to: dateRange.to.toISOString()
        });

        // Create Timestamps for query
        const fromTimestamp = Timestamp.fromDate(dateRange.from);
        const toTimestamp = Timestamp.fromDate(dateRange.to);

        console.log('Using Timestamps:', {
          from: fromTimestamp,
          to: toTimestamp
        });

        // Fetch emergencies within date range
        const emergenciesQuery = query(
          collection(db, "emergency_requests"),
          where("createdAt", ">=", fromTimestamp),
          where("createdAt", "<=", toTimestamp),
          orderBy("createdAt", "desc")
        );
        
        // Fetch ambulance requests within date range
        const ambulanceQuery = query(
          collection(db, "ambulance_requests"),
          where("createdAt", ">=", fromTimestamp),
          where("createdAt", "<=", toTimestamp),
          orderBy("createdAt", "desc")
        );

        console.log('Executing queries...');

        const [emergenciesSnapshot, ambulanceSnapshot] = await Promise.all([
          getDocs(emergenciesQuery),
          getDocs(ambulanceQuery)
        ]);

        console.log('Data received:', {
          emergencies: emergenciesSnapshot.size,
          ambulance: ambulanceSnapshot.size
        });

        if (emergenciesSnapshot.empty && ambulanceSnapshot.empty) {
          console.log('No data found for the selected date range');
          setError('No data available for the selected date range');
          setEmergencies([]);
          setAmbulanceRequests([]);
          setLoading(false);
          return;
        }

        const emergenciesData = emergenciesSnapshot.docs.map(doc => {
          const data = doc.data();
          console.log('Processing emergency doc:', doc.id, data);
          return {
            id: doc.id,
            type: data.type || 'general',
            status: data.status || 'pending',
            createdAt: data.createdAt?.toDate() || new Date(),
            location: data.location || { latitude: 0, longitude: 0 },
            patientName: data.patientName || 'Unknown',
            contactNumber: data.contactNumber || 'N/A',
            priority: data.priority || 'medium',
            description: data.description || ''
          };
        });

        const ambulanceData = ambulanceSnapshot.docs.map(doc => {
          const data = doc.data();
          console.log('Processing ambulance doc:', doc.id, data);
          return {
            id: doc.id,
            status: data.status || 'pending',
            createdAt: data.createdAt?.toDate() || new Date(),
            requestType: data.requestType || 'other',
            location: {
              pickup: data.location?.pickup || 'Not specified',
              description: data.location?.description || ''
            },
            requesterName: data.requesterName || 'Unknown',
            contactNumber: data.contactNumber || 'N/A',
            patientCount: data.patientCount || 1,
            urgencyLevel: data.urgencyLevel || 'moderate'
          };
        });

        console.log('Processed data:', {
          emergencies: emergenciesData.length,
          ambulance: ambulanceData.length
        });

        setEmergencies(emergenciesData);
        setAmbulanceRequests(ambulanceData);
        setLoading(false);
      } catch (error) {
        console.error("Error fetching report data:", error);
        setError(
          error instanceof Error 
            ? `Failed to fetch data: ${error.message}` 
            : "Failed to fetch report data. Please check your connection and try again."
        );
        setLoading(false);
      }
    };

    fetchData();
  }, [dateRange.from, dateRange.to]);

  const emergencyStatusData = useMemo(() => {
    const statusCounts: { [key: string]: number } = {};
    emergencies.forEach(emergency => {
      statusCounts[emergency.status] = (statusCounts[emergency.status] || 0) + 1;
    });
    return Object.entries(statusCounts).map(([status, count]) => ({
      name: status.charAt(0).toUpperCase() + status.slice(1),
      value: count
    }));
  }, [emergencies]);

  const ambulanceTypeData = useMemo(() => {
    const typeCounts: { [key: string]: number } = {};
    ambulanceRequests.forEach(request => {
      typeCounts[request.requestType] = (typeCounts[request.requestType] || 0) + 1;
    });
    return Object.entries(typeCounts).map(([type, count]) => ({
      name: type.charAt(0).toUpperCase() + type.slice(1),
      value: count
    }));
  }, [ambulanceRequests]);

  const dailyStats = useMemo(() => {
    const stats: { [key: string]: { emergencies: number; ambulance: number } } = {};
    
    emergencies.forEach(emergency => {
      const day = emergency.createdAt.toISOString().split('T')[0];
      if (!stats[day]) stats[day] = { emergencies: 0, ambulance: 0 };
      stats[day].emergencies++;
    });

    ambulanceRequests.forEach(request => {
      const day = request.createdAt.toISOString().split('T')[0];
      if (!stats[day]) stats[day] = { emergencies: 0, ambulance: 0 };
      stats[day].ambulance++;
    });

    return Object.entries(stats)
      .map(([date, data]) => ({
        date,
        ...data
      }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }, [emergencies, ambulanceRequests]);

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg">Loading reports...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 text-red-500 bg-red-50 rounded-lg">
        <p>{error}</p>
        <Button 
          variant="outline" 
          className="mt-2"
          onClick={() => window.location.reload()}
        >
          Retry
        </Button>
      </div>
    );
  }

  const renderContent = () => {
    switch (selectedReport) {
      case "overview":
        return (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Card>
                <CardHeader>
                  <CardTitle>Total Medical Emergencies</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{emergencies.length}</div>
                  <p className="text-sm text-gray-500 mt-1">Critical cases requiring immediate response</p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Ambulance Requests</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">{ambulanceRequests.length}</div>
                  <p className="text-sm text-gray-500 mt-1">Bystander-initiated requests</p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Active Cases</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-bold">
                    {emergencies.filter(e => e.status === 'active').length + 
                     ambulanceRequests.filter(r => r.status === 'active').length}
                  </div>
                  <p className="text-sm text-gray-500 mt-1">Currently responding</p>
                </CardContent>
              </Card>
            </div>

            <Card>
              <CardHeader>
                <CardTitle>Daily Emergency Response Activity</CardTitle>
              </CardHeader>
              <CardContent>
                <LineChart width={800} height={400} data={dailyStats}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="emergencies" stroke="#ff4444" name="Medical Emergencies" />
                  <Line type="monotone" dataKey="ambulance" stroke="#4444ff" name="Ambulance Requests" />
                </LineChart>
              </CardContent>
            </Card>
          </div>
        );

      case "emergency":
        return (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader>
                  <CardTitle>Emergency Status Distribution</CardTitle>
                </CardHeader>
                <CardContent>
                  <PieChart width={400} height={300}>
                    <Pie
                      data={emergencyStatusData}
                      cx={200}
                      cy={150}
                      labelLine={false}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}`}
                    >
                      {emergencyStatusData.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Recent Medical Emergencies</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {emergencies.slice(0, 5).map(emergency => (
                      <div key={emergency.id} className="p-4 border rounded-lg">
                        <div className="flex justify-between items-start">
                          <div>
                            <h3 className="font-semibold">{emergency.patientName}</h3>
                            <p className="text-sm text-gray-500">{emergency.contactNumber}</p>
                          </div>
                          <div className={`px-2 py-1 rounded text-sm ${
                            emergency.priority === 'high' ? 'bg-red-100 text-red-800' :
                            emergency.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {emergency.priority.toUpperCase()}
                          </div>
                        </div>
                        <div className="mt-2">
                          <p className="text-sm">Status: {emergency.status}</p>
                          <p className="text-sm">Type: {emergency.type}</p>
                          <p className="text-sm text-gray-600">{emergency.description}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        );

      case "ambulance":
        return (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader>
                  <CardTitle>Request Types</CardTitle>
                </CardHeader>
                <CardContent>
                  <PieChart width={400} height={300}>
                    <Pie
                      data={ambulanceTypeData}
                      cx={200}
                      cy={150}
                      labelLine={false}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                      label={({ name, value }) => `${name}: ${value}`}
                    >
                      {ambulanceTypeData.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Recent Ambulance Requests</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {ambulanceRequests.slice(0, 5).map(request => (
                      <div key={request.id} className="p-4 border rounded-lg">
                        <div className="flex justify-between">
                          <div>
                            <h3 className="font-semibold">{request.requesterName}</h3>
                            <p className="text-sm text-gray-500">{request.contactNumber}</p>
                          </div>
                          <div className={`px-2 py-1 rounded text-sm ${
                            request.urgencyLevel === 'critical' ? 'bg-red-100 text-red-800' :
                            request.urgencyLevel === 'moderate' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {request.urgencyLevel.toUpperCase()}
                          </div>
                        </div>
                        <div className="mt-2 text-sm">
                          <p>Type: {request.requestType}</p>
                          <p>Location: {request.location.pickup}</p>
                          <p>Details: {request.location.description}</p>
                          <p>Patients: {request.patientCount}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      {renderContent()}
    </div>
  );
} 