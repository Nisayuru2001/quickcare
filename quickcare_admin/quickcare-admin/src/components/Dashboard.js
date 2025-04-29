import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { db } from '../firebase';
import { collection, query, onSnapshot, doc, updateDoc, getDocs } from 'firebase/firestore';
import DriverList from './DriverList';
import DriverTrackingPage from './DriverTrackingPage';
import UserList from './UserList';
import UserDetail from './UserDetail';
import TripHistoryManagement from './TripHistoryManagement';

function Dashboard() {
  const [drivers, setDrivers] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('drivers');
  const [stats, setStats] = useState({
    total: 0,
    pending: 0,
    approved: 0,
    rejected: 0
  });
  const [currentUserId, setCurrentUserId] = useState(null);
  const { currentUser, logout } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    // Fetch drivers from Firestore
    const fetchDrivers = () => {
      const q = query(collection(db, "driver_profiles"));
      
      const unsubscribe = onSnapshot(q, (querySnapshot) => {
        console.log(`Retrieved ${querySnapshot.size} driver documents`);
        
        const driversArray = [];
        let pendingCount = 0;
        let approvedCount = 0;
        let rejectedCount = 0;
        
        querySnapshot.forEach((doc) => {
          const driver = { id: doc.id, ...doc.data() };
          driversArray.push(driver);
          
          if (driver.status === 'pending') pendingCount++;
          else if (driver.status === 'approved') approvedCount++;
          else if (driver.status === 'rejected') rejectedCount++;
        });
        
        console.log('Processed driver data:', driversArray);
        
        setDrivers(driversArray);
        setStats({
          total: driversArray.length,
          pending: pendingCount,
          approved: approvedCount,
          rejected: rejectedCount
        });
        setLoading(false);
      }, (error) => {
        console.error("Error fetching drivers:", error);
        setLoading(false);
      });
      
      return unsubscribe;
    };

    // Fetch users from user_profiles collection
    const fetchUsers = async () => {
      try {
        console.log("Fetching users from user_profiles collection");
        
        const usersQuery = query(collection(db, "user_profiles"));
        const querySnapshot = await getDocs(usersQuery);
        
        console.log(`Retrieved ${querySnapshot.size} user documents`);
        
        if (querySnapshot.empty) {
          console.log("No users found in the database");
          return;
        }
        
        const usersArray = querySnapshot.docs.map(doc => {
          const data = doc.data();
          console.log(`Processing user ${doc.id}:`, data);
          
          return {
            id: doc.id,
            fullName: data.fullName || null,
            email: data.email || null,
            phoneNumber: data.phoneNumber || null,
            emergencyContact: data.emergencyContact || null,
            createdAt: data.createdAt || null,
            lastLogin: data.lastLogin || null,
            isActive: data.isActive,
            medicalInfo: data.medicalInfo || null,
            ...data
          };
        });
        
        console.log('Processed user data:', usersArray);
        setUsers(usersArray);
      } catch (error) {
        console.error("Error fetching users:", error);
      }
    };

    const driversUnsubscribe = fetchDrivers();
    fetchUsers();

    return () => {
      driversUnsubscribe();
    };
  }, []);

  async function handleApproveDriver(driverId) {
    try {
      const driverRef = doc(db, "driver_profiles", driverId);
      await updateDoc(driverRef, {
        status: "approved"
      });
      console.log(`Driver ${driverId} approved successfully`);
    } catch (error) {
      console.error("Error approving driver:", error);
    }
  }

  async function handleRejectDriver(driverId) {
    try {
      const driverRef = doc(db, "driver_profiles", driverId);
      await updateDoc(driverRef, {
        status: "rejected"
      });
      console.log(`Driver ${driverId} rejected successfully`);
    } catch (error) {
      console.error("Error rejecting driver:", error);
    }
  }

  async function handleLogout() {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error("Failed to log out", error);
    }
  }

  const handleViewUserDetails = (userId) => {
    console.log(`Viewing details for user ${userId}`);
    setCurrentUserId(userId);
    setActiveTab('userDetails');
  };

  const handleBackToUserList = () => {
    setCurrentUserId(null);
    setActiveTab('users');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0F172A] to-[#1E293B] relative overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden opacity-10 pointer-events-none">
        <div className="absolute w-96 h-96 bg-[#3B82F6] rounded-full -top-20 -left-20 blur-3xl animate-pulse"></div>
        <div className="absolute w-96 h-96 bg-[#0D9488] rounded-full bottom-0 right-0 blur-3xl animate-pulse" style={{animationDelay: '2s'}}></div>
        <div className="absolute w-64 h-64 bg-[#4F46E5] rounded-full top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 blur-3xl animate-pulse" style={{animationDelay: '4s'}}></div>
      </div>
      
      {/* Animated pattern grid */}
      <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxwYXRoIGQ9Ik0zNiAxOGMwLTkuOTQtOC4wNi0xOC0xOC0xOHY2YzYuNjI3IDAgMTIgNS4zNzMgMTIgMTJoNnptLTYgNmMwLTYuNjI3LTUuMzczLTEyLTEyLTEydjZjMy4zMTQgMCA2IDIuNjg2IDYgNmg2eiIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjA1KSIvPjwvZz48L3N2Zz4=')] opacity-10"></div>
      
      {/* Header */}
      <header className="relative z-10 backdrop-blur-sm bg-[#0F172A]/70 shadow-lg border-b border-white/10">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8 flex justify-between items-center">
          <div className="flex items-center">
            <div className="flex items-center justify-center w-10 h-10 rounded-full bg-gradient-to-tr from-[#0D9488] to-[#3B82F6] shadow-lg">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-white" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M3 5a2 2 0 012-2h10a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2V5zm11 1H6v8l4-2 4 2V6z" clipRule="evenodd" />
              </svg>
            </div>
            <h1 className="ml-3 text-2xl font-bold text-white tracking-tight">Smart Ambulance</h1>
          </div>
          <div className="flex items-center space-x-4">
            <div className="hidden md:block text-sm text-[#94A3B8] bg-white/5 py-2 px-3 rounded-lg border border-white/10">
              <span className="block text-white">{currentUser?.email}</span>
              <span className="block text-xs opacity-75">Administrator</span>
            </div>
            <button 
              onClick={handleLogout}
              className="bg-white/5 hover:bg-white/10 border border-white/10 text-white text-sm font-medium py-2 px-3 rounded-lg flex items-center transition-colors shadow-lg"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="relative z-10 max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
        {/* Tabs */}
        <div className="backdrop-blur-sm bg-white/5 rounded-xl px-4 py-1 border border-white/10 shadow-lg mb-8">
          <nav className="flex justify-between overflow-x-auto">
            <button
              onClick={() => setActiveTab('drivers')}
              className={`relative py-3 px-4 rounded-lg font-medium text-sm transition-colors ${
                activeTab === 'drivers'
                  ? 'text-white bg-white/10'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              }`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                Driver Management
              </div>
              {activeTab === 'drivers' && <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-12 h-1 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] rounded-t-lg"></div>}
            </button>
            <button
              onClick={() => setActiveTab('tracking')}
              className={`relative py-3 px-4 rounded-lg font-medium text-sm transition-colors ${
                activeTab === 'tracking'
                  ? 'text-white bg-white/10'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              }`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                </svg>
                Driver Tracking
              </div>
              {activeTab === 'tracking' && <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-12 h-1 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] rounded-t-lg"></div>}
            </button>
            <button
              onClick={() => {
                setActiveTab('users');
                setCurrentUserId(null);
              }}
              className={`relative py-3 px-4 rounded-lg font-medium text-sm transition-colors ${
                activeTab === 'users' || activeTab === 'userDetails'
                  ? 'text-white bg-white/10'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              }`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                User Management
              </div>
              {(activeTab === 'users' || activeTab === 'userDetails') && <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-12 h-1 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] rounded-t-lg"></div>}
            </button>
            <button
              onClick={() => setActiveTab('trips')}
              className={`relative py-3 px-4 rounded-lg font-medium text-sm transition-colors ${
                activeTab === 'trips'
                  ? 'text-white bg-white/10'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              }`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                </svg>
                Trip History
              </div>
              {activeTab === 'trips' && <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-12 h-1 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] rounded-t-lg"></div>}
            </button>
          </nav>
        </div>

        {activeTab === 'drivers' && (
          <>
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-white flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-7 w-7 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                Driver Management
              </h2>
              <button className="bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] text-white text-sm font-medium py-2 px-4 rounded-lg flex items-center transition-colors shadow-lg">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
                Add New Driver
              </button>
            </div>
            
            {/* Stats Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
              <div className="backdrop-blur-sm bg-white/5 rounded-xl p-6 border border-white/10 shadow-lg">
                <div className="flex items-center">
                  <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-[#3B82F6]/20 border border-[#3B82F6]/30 text-[#3B82F6]">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                  <div className="ml-5">
                    <p className="text-[#94A3B8] text-sm">Total Drivers</p>
                    <h3 className="text-2xl font-bold text-white">{stats.total}</h3>
                  </div>
                </div>
              </div>
              
              <div className="backdrop-blur-sm bg-white/5 rounded-xl p-6 border border-white/10 shadow-lg">
                <div className="flex items-center">
                  <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-[#D97706]/20 border border-[#D97706]/30 text-[#D97706]">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div className="ml-5">
                    <p className="text-[#94A3B8] text-sm">Pending</p>
                    <h3 className="text-2xl font-bold text-white">{stats.pending}</h3>
                  </div>
                </div>
              </div>
              
              <div className="backdrop-blur-sm bg-white/5 rounded-xl p-6 border border-white/10 shadow-lg">
                <div className="flex items-center">
                  <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-[#0D9488]/20 border border-[#0D9488]/30 text-[#0D9488]">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div className="ml-5">
                    <p className="text-[#94A3B8] text-sm">Approved</p>
                    <h3 className="text-2xl font-bold text-white">{stats.approved}</h3>
                  </div>
                </div>
              </div>
              
              <div className="backdrop-blur-sm bg-white/5 rounded-xl p-6 border border-white/10 shadow-lg">
                <div className="flex items-center">
                  <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-[#DC2626]/20 border border-[#DC2626]/30 text-[#DC2626]">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div className="ml-5">
                    <p className="text-[#94A3B8] text-sm">Rejected</p>
                    <h3 className="text-2xl font-bold text-white">{stats.rejected}</h3>
                  </div>
                </div>
              </div>
            </div>
            
            {loading ? (
              <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg p-6 text-center py-12">
                <svg className="animate-spin h-10 w-10 text-[#3B82F6] mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <p className="text-[#94A3B8]">Loading driver data...</p>
              </div>
            ) : (
              <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg overflow-hidden">
                <DriverList 
                  drivers={drivers} 
                  onApprove={handleApproveDriver} 
                  onReject={handleRejectDriver} 
                />
              </div>
            )}
          </>
        )}

        {activeTab === 'tracking' && (
          <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg overflow-hidden">
            <DriverTrackingPage />
          </div>
        )}

        {activeTab === 'users' && (
          <>
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-white flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-7 w-7 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                User Management
              </h2>
              <div className="text-sm py-1 px-3 rounded-lg bg-white/5 border border-white/10 text-[#94A3B8]">
                Total Users: <span className="text-white font-medium">{users.length}</span>
              </div>
            </div>
            
            <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg overflow-hidden">
              <UserList 
                users={users} 
                onViewDetails={handleViewUserDetails} 
              />
            </div>
          </>
        )}

        {activeTab === 'userDetails' && currentUserId && (
          <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg overflow-hidden">
            <UserDetail 
              userId={currentUserId} 
              onBack={handleBackToUserList} 
            />
          </div>
        )}

        {activeTab === 'trips' && (
          <div className="backdrop-blur-sm bg-white/5 rounded-xl border border-white/10 shadow-lg overflow-hidden">
            <TripHistoryManagement />
          </div>
        )}
      </main>
    </div>
  );
}

export default Dashboard;