import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Users, FileText, Monitor, Database, AlertCircle } from "lucide-react";
import { useEffect, useState } from "react";
import { collection, query, orderBy, limit, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { Alert, AlertDescription } from "@/components/ui/alert";

interface EmergencyRequest {
  id: string;
  location: string | { _lat: number; _long: number } | any;
  status: string;
  patientName: string;
  createdAt: any;
  priority: string;
}

interface DashboardProps {
  stats: {
    totalEmergencies: number;
    activeBookings: number;
    totalDrivers: number;
    onlineDrivers: number;
    totalUsers: number;
    totalAdmins: number;
  };
}

export function Dashboard({ stats }: DashboardProps) {
  const [emergencyRequests, setEmergencyRequests] = useState<EmergencyRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const formatLocation = (location: any): string => {
    if (!location) return "Location not provided";
    
    // If location is a GeoPoint
    if (location._lat && location._long) {
      return `${location._lat.toFixed(6)}, ${location._long.toFixed(6)}`;
    }
    
    // If location is a string (address)
    if (typeof location === 'string') {
      return location;
    }

    // If location has address property
    if (location.address) {
      return location.address;
    }

    // Fallback
    return "Location format unknown";
  };

  useEffect(() => {
    // Set up real-time listener for emergency requests
    const emergencyRef = collection(db, "emergency_requests");
    const emergencyQuery = query(
      emergencyRef,
      orderBy("createdAt", "desc"),
      limit(5)
    );

    const unsubscribe = onSnapshot(
      emergencyQuery,
      (snapshot) => {
        const requests: EmergencyRequest[] = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          requests.push({
            id: doc.id,
            location: data.location || "Location not provided",
            status: data.status || "pending",
            patientName: data.patientName || "Anonymous",
            createdAt: data.createdAt,
            priority: data.priority || "medium"
          });
        });
        setEmergencyRequests(requests);
        setLoading(false);
        setError(null);
      },
      (err) => {
        console.error("Error fetching emergency requests:", err);
        setError("Failed to load emergency requests");
        setLoading(false);
      }
    );

    // Cleanup subscription
    return () => unsubscribe();
  }, []);

  const cards = [
    {
      title: "Emergency Requests",
      value: stats.totalEmergencies,
      icon: FileText,
      color: "text-red-500",
      bgColor: "bg-red-50",
    },
    {
      title: "Active Bookings",
      value: stats.activeBookings,
      icon: Monitor,
      color: "text-blue-500",
      bgColor: "bg-blue-50",
    },
    {
      title: "Total Drivers",
      value: stats.totalDrivers,
      icon: Users,
      color: "text-green-500",
      bgColor: "bg-green-50",
    },
    {
      title: "Online Drivers",
      value: stats.onlineDrivers,
      icon: Database,
      color: "text-yellow-500",
      bgColor: "bg-yellow-50",
    },
    {
      title: "Total Users",
      value: stats.totalUsers,
      icon: Users,
      color: "text-purple-500",
      bgColor: "bg-purple-50",
    },
    {
      title: "Total Admins",
      value: stats.totalAdmins,
      icon: Users,
      color: "text-indigo-500",
      bgColor: "bg-indigo-50",
    },
  ];

  const getStatusColor = (status: string): string => {
    switch (status.toLowerCase()) {
      case 'active':
      case 'in_progress':
        return 'bg-yellow-100 text-yellow-800';
      case 'completed':
        return 'bg-green-100 text-green-800';
      case 'cancelled':
        return 'bg-gray-100 text-gray-800';
      case 'pending':
        return 'bg-blue-100 text-blue-800';
      default:
        return 'bg-red-100 text-red-800';
    }
  };

  const getPriorityBadge = (priority: string) => {
    switch (priority.toLowerCase()) {
      case 'high':
        return <Badge variant="destructive">High Priority</Badge>;
      case 'medium':
        return <Badge variant="default">Medium Priority</Badge>;
      case 'low':
        return <Badge variant="secondary">Low Priority</Badge>;
      default:
        return null;
    }
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return '';
    const date = timestamp.toDate();
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard Overview</h1>
        <p className="text-gray-500 mt-2">Monitor your emergency response system</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {cards.map((card, index) => {
          const Icon = card.icon;
          return (
            <Card key={index} className="hover:shadow-lg transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium text-gray-600">
                  {card.title}
                </CardTitle>
                <div className={`p-2 rounded-full ${card.bgColor}`}>
                  <Icon className={`h-4 w-4 ${card.color}`} />
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-gray-900">{card.value}</div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Recent Emergency Requests</span>
              {loading && <Badge variant="outline">Updating...</Badge>}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {error ? (
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            ) : (
              <div className="space-y-4">
                {loading ? (
                  // Loading skeleton
                  Array.from({ length: 5 }).map((_, i) => (
                    <div key={i} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg animate-pulse">
                      <div className="space-y-2">
                        <div className="h-4 w-48 bg-gray-200 rounded"></div>
                        <div className="h-3 w-32 bg-gray-200 rounded"></div>
                      </div>
                      <div className="h-6 w-20 bg-gray-200 rounded"></div>
                    </div>
                  ))
                ) : emergencyRequests.length > 0 ? (
                  emergencyRequests.map((request) => (
                    <div key={request.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <p className="font-medium">{request.patientName}</p>
                          {getPriorityBadge(request.priority)}
                        </div>
                        <p className="text-sm text-gray-500">Location: {formatLocation(request.location)}</p>
                        <p className="text-xs text-gray-400">{formatDate(request.createdAt)}</p>
                      </div>
                      <div className="flex flex-col items-end gap-2">
                        <Badge className={getStatusColor(request.status)}>
                          {request.status.charAt(0).toUpperCase() + request.status.slice(1)}
                        </Badge>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-center py-6 text-gray-500">
                    No emergency requests found
                  </div>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Driver Status Overview</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Online Drivers</span>
                <Badge className="bg-green-100 text-green-800">
                  {stats.onlineDrivers}/{stats.totalDrivers}
                </Badge>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div 
                  className="bg-green-500 h-2 rounded-full" 
                  style={{ width: `${(stats.onlineDrivers / stats.totalDrivers) * 100}%` }}
                ></div>
              </div>
              <div className="flex justify-between text-sm text-gray-500">
                <span>Offline: {stats.totalDrivers - stats.onlineDrivers}</span>
                <span>Available: {Math.floor(stats.onlineDrivers * 0.7)}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
