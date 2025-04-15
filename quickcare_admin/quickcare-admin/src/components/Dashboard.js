import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { db } from '../firebase';
import { collection, query, onSnapshot, doc, updateDoc } from 'firebase/firestore';
import DriverList from './DriverList';

function Dashboard() {
  const [drivers, setDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const { currentUser, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    // Fetch drivers from Firestore
    const q = query(collection(db, "driver_profiles"));
    
    const unsubscribe = onSnapshot(q, (querySnapshot) => {
      const driversArray = [];
      querySnapshot.forEach((doc) => {
        driversArray.push({ id: doc.id, ...doc.data() });
      });
      setDrivers(driversArray);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  async function handleApproveDriver(driverId) {
    const driverRef = doc(db, "driver_profiles", driverId);
    await updateDoc(driverRef, {
      status: "approved"
    });
  }

  async function handleRejectDriver(driverId) {
    const driverRef = doc(db, "driver_profiles", driverId);
    await updateDoc(driverRef, {
      status: "rejected"
    });
  }

  async function handleLogout() {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error("Failed to log out", error);
    }
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8 flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gray-900">Smart Ambulance Admin Dashboard</h1>
          <div className="flex items-center space-x-4">
            <span className="text-gray-600">{currentUser?.email}</span>
            <button 
              onClick={handleLogout}
              className="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
        {loading ? (
          <div className="text-center py-10">Loading...</div>
        ) : (
          <>
            <h2 className="text-2xl font-semibold mb-6">Driver Management</h2>
            <DriverList 
              drivers={drivers} 
              onApprove={handleApproveDriver} 
              onReject={handleRejectDriver} 
            />
          </>
        )}
      </main>
    </div>
  );
}

export default Dashboard;