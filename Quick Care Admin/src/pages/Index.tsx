import { useState, useEffect } from "react";
import { AdminSidebar } from "@/components/AdminSidebar";
import { Dashboard } from "@/components/Dashboard";
import { EmergencyRequests } from "@/components/EmergencyRequests";
import { DriverManagement } from "@/components/DriverManagement";
import { AmbulanceBookings } from "@/components/AmbulanceBookings";
import { UserManagement } from "@/components/UserManagement";
import ReportsPage from "@/pages/ReportsPage";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";

const Index = () => {
  const [activeSection, setActiveSection] = useState("dashboard");
  const [stats, setStats] = useState({
    totalEmergencies: 0,
    activeBookings: 0,
    totalDrivers: 0,
    onlineDrivers: 0,
    totalUsers: 0,
    totalAdmins: 0,
  });

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      const [emergencies, bookings, drivers, users, admins] = await Promise.all([
        getDocs(collection(db, "emergency_requests")),
        getDocs(collection(db, "ambulance_bookings")),
        getDocs(collection(db, "driver_profiles")),
        getDocs(collection(db, "user_profiles")),
        getDocs(collection(db, "admins")),
      ]);

      const emergencyData = emergencies.docs.map(doc => doc.data());
      const bookingData = bookings.docs.map(doc => doc.data());
      const driverData = drivers.docs.map(doc => doc.data());

      setStats({
        totalEmergencies: emergencies.size,
        activeBookings: bookingData.filter(b => b.status === "active" || b.status === "pending").length,
        totalDrivers: drivers.size,
        onlineDrivers: driverData.filter(d => d.isOnline).length,
        totalUsers: users.size,
        totalAdmins: admins.size,
      });
    } catch (error) {
      console.error("Error fetching stats:", error);
    }
  };

  const renderContent = () => {
    switch (activeSection) {
      case "dashboard":
        return <Dashboard stats={stats} />;
      case "emergency":
        return <EmergencyRequests />;
      case "drivers":
        return <DriverManagement />;
      case "ambulance":
        return <AmbulanceBookings />;
      case "users":
        return <UserManagement />;

      case "reports":
        return <ReportsPage />;
      default:
        return <Dashboard stats={stats} />;
    }
  };

  return (
    <div className="flex h-screen bg-gray-50">
      <AdminSidebar 
        activeSection={activeSection} 
        onSectionChange={setActiveSection} 
      />
      <main className="flex-1 overflow-auto">
        <div className="p-6">
          {renderContent()}
        </div>
      </main>
    </div>
  );
};

export default Index;
