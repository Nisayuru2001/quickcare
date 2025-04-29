import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';

function UserDetail({ userId, onBack }) {
  const [user, setUser] = useState(null);
  const [trips, setTrips] = useState([]);
  const [medicalInfo, setMedicalInfo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState('profile');

  useEffect(() => {
    async function fetchUserData() {
      setLoading(true);
      setError('');
      
      try {
        console.log(`Fetching details for user ${userId}`);
        
        // Fetch user profile from user_profiles collection
        const userDocRef = doc(db, "user_profiles", userId);
        const userDoc = await getDoc(userDocRef);
        
        if (userDoc.exists()) {
          const userData = { id: userDoc.id, ...userDoc.data() };
          console.log("Retrieved user data:", userData);
          setUser(userData);
          
          // First check if medical info fields are directly on the user document
          if (userData.bloodType || userData.allergies || userData.medications || userData.medicalConditions) {
            console.log("Medical info fields found directly on user document");
            setMedicalInfo({
              bloodType: userData.bloodType || '',
              allergies: userData.allergies || '',
              medications: userData.medications || '',
              medicalConditions: userData.medicalConditions || '',
              additionalNotes: userData.additionalNotes || '',
              pastSurgeries: userData.pastSurgeries || ''
            });
          }
          // Then try medicalInfo object if it exists
          else if (userData.medicalInfo) {
            console.log("Medical info found in medicalInfo object:", userData.medicalInfo);
            setMedicalInfo(userData.medicalInfo);
          } 
          // Finally try medicalInfoId if it exists
          else if (userData.medicalInfoId) {
            console.log(`Fetching medical info with ID: ${userData.medicalInfoId}`);
            try {
              const medicalDoc = await getDoc(doc(db, "medical_info", userData.medicalInfoId));
              if (medicalDoc.exists()) {
                console.log("Retrieved medical info:", medicalDoc.data());
                setMedicalInfo(medicalDoc.data());
              }
            } catch (medicalError) {
              console.error("Error fetching medical info:", medicalError);
            }
          }
          
          // Fetch user's emergency trips - try multiple query approaches
          try {
            console.log(`Fetching trips for user ${userId}`);
            
            // Get all trips and filter client-side to ensure we catch all
            const tripsQuery = query(collection(db, "emergency_requests"));
            const tripsSnapshot = await getDocs(tripsQuery);
            
            console.log(`Retrieved ${tripsSnapshot.size} total trips`);
            
            const tripsData = [];
            
            tripsSnapshot.forEach(doc => {
              const tripData = doc.data();
              
              // Match by userId
              if (tripData.userId === userId) {
                tripsData.push({ id: doc.id, ...tripData });
              }
              // Match by userName if it matches user's fullName
              else if (userData.fullName && tripData.userName === userData.fullName) {
                tripsData.push({ id: doc.id, ...tripData });
              }
              // Match by userID in any other relevant fields
              else if (tripData.user === userId) {
                tripsData.push({ id: doc.id, ...tripData });
              }
            });
            
            // Sort trips by date (newest first)
            tripsData.sort((a, b) => {
              const dateA = a.createdAt ? a.createdAt.seconds : 0;
              const dateB = b.createdAt ? b.createdAt.seconds : 0;
              return dateB - dateA;
            });
            
            console.log(`Found ${tripsData.length} trips for this user`);
            setTrips(tripsData);
          } catch (tripsError) {
            console.error("Error fetching trips:", tripsError);
          }
        } else {
          setError("User not found");
        }
      } catch (err) {
        console.error("Error fetching user data:", err);
        setError("Failed to load user data: " + err.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchUserData();
  }, [userId]);

  // Format date for display with improved error handling
  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    
    try {
      // Handle Firestore timestamp
      if (timestamp.seconds) {
        const date = new Date(timestamp.seconds * 1000);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
      } 
      // Handle string date
      else if (typeof timestamp === 'string') {
        const date = new Date(timestamp);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
      }
      // Handle Date object 
      else if (timestamp instanceof Date) {
        return timestamp.toLocaleDateString() + ' ' + timestamp.toLocaleTimeString();
      }
      
      return 'Invalid date';
    } catch (error) {
      console.error("Error formatting date:", error, timestamp);
      return 'N/A';
    }
  };
  
  // Format status for display with badge color
  const getStatusBadge = (status) => {
    let colorClass = '';
    let displayText = status && status.charAt(0).toUpperCase() + status.slice(1);
    
    switch (status) {
      case 'pending':
        colorClass = 'bg-[#D97706]/20 text-[#D97706] border border-[#D97706]/30';
        break;
      case 'accepted':
        colorClass = 'bg-[#3B82F6]/20 text-[#3B82F6] border border-[#3B82F6]/30';
        displayText = 'In Progress';
        break;
      case 'completed':
        colorClass = 'bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30';
        break;
      case 'cancelled':
        colorClass = 'bg-[#DC2626]/20 text-[#DC2626] border border-[#DC2626]/30';
        break;
      default:
        colorClass = 'bg-[#64748B]/20 text-[#94A3B8] border border-[#64748B]/30';
    }
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colorClass}`}>
        {displayText || 'Unknown'}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96 backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6">
        <svg className="animate-spin h-10 w-10 text-[#3B82F6]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span className="ml-3 text-[#94A3B8]">Loading user data...</span>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="bg-[#DC2626]/10 backdrop-blur-sm p-6 rounded-xl shadow-lg border border-[#DC2626]/30">
        <div className="flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-[#DC2626] mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="text-lg font-medium text-white">Error</h3>
        </div>
        <div className="mt-2 text-[#94A3B8]">
          <p>{error}</p>
        </div>
        <div className="mt-4">
          <button
            type="button"
            onClick={onBack}
            className="inline-flex items-center px-4 py-2 rounded-lg shadow-lg text-white bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] transition-colors"
          >
            Back to User List
          </button>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6 text-center py-12">
        <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 rounded-full bg-white/5 border border-white/10">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-[#94A3B8]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
          </svg>
        </div>
        <p className="text-white text-lg mb-1">User not found</p>
        <button
          onClick={onBack}
          className="mt-4 inline-flex items-center px-4 py-2 rounded-lg shadow-lg text-white bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] transition-colors"
        >
          Back to User List
        </button>
      </div>
    );
  }

  return (
    <div className="w-full">
      {/* Header */}
      <div className="p-6 border-b border-white/10 flex justify-between items-center">
        <div className="flex items-center">
          <button
            onClick={onBack}
            className="p-2 mr-4 text-[#94A3B8] hover:text-[#3B82F6] rounded-full hover:bg-white/5 transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </button>
          <h3 className="text-lg font-semibold text-white">User Details</h3>
        </div>
        <div className="text-sm bg-white/5 py-1 px-2 rounded-lg border border-white/10 text-[#94A3B8]">User ID: {userId}</div>
      </div>
      
      {/* Tabs */}
      <div className="p-4 border-b border-white/10">
        <div className="sm:hidden">
          <select
            id="tabs"
            name="tabs"
            className="block w-full bg-white/5 border border-white/10 rounded-lg text-white focus:ring-[#3B82F6] focus:border-[#3B82F6] p-2"
            value={activeTab}
            onChange={(e) => setActiveTab(e.target.value)}
          >
            <option value="profile">Profile</option>
            <option value="medical">Medical Info</option>
            <option value="trips">Trip History</option>
          </select>
        </div>
        <div className="hidden sm:block">
          <nav className="flex space-x-4" aria-label="Tabs">
            <button
              onClick={() => setActiveTab('profile')}
              className={`${
                activeTab === 'profile'
                  ? 'bg-white/10 text-white'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              } px-3 py-2 rounded-lg text-sm font-medium transition-colors`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                Profile
              </div>
            </button>
            <button
              onClick={() => setActiveTab('medical')}
              className={`${
                activeTab === 'medical'
                  ? 'bg-white/10 text-white'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              } px-3 py-2 rounded-lg text-sm font-medium transition-colors`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
                Medical Info
              </div>
            </button>
            <button
              onClick={() => setActiveTab('trips')}
              className={`${
                activeTab === 'trips'
                  ? 'bg-white/10 text-white'
                  : 'text-[#94A3B8] hover:text-white hover:bg-white/5'
              } px-3 py-2 rounded-lg text-sm font-medium transition-colors`}
            >
              <div className="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                Trip History
              </div>
            </button>
          </nav>
        </div>
      </div>
      
      {/* Content */}
      <div className="p-6">
        {activeTab === 'profile' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6">
              <div className="flex items-center mb-6">
                <div className="h-16 w-16 rounded-full bg-gradient-to-br from-[#3B82F6]/30 to-[#4F46E5]/30 border border-white/10 flex items-center justify-center text-2xl font-semibold text-white">
                  {user.fullName ? user.fullName.charAt(0).toUpperCase() : 'U'}
                </div>
                <div className="ml-4">
                  <h4 className="text-xl font-semibold text-white">{user.fullName || 'No Name'}</h4>
                  <p className="text-[#94A3B8]">{user.email || 'No Email'}</p>
                </div>
              </div>
              
              <div className="space-y-4">
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-[#94A3B8]">Phone:</span>
                  <span className="text-white font-medium">{user.phoneNumber || 'Not provided'}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-[#94A3B8]">Emergency Contact:</span>
                  <span className="text-white font-medium">{user.emergencyContact || 'Not provided'}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-[#94A3B8]">Registered On:</span>
                  <span className="text-white font-medium">{formatDate(user.createdAt)}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-[#94A3B8]">Last Updated:</span>
                  <span className="text-white font-medium">{formatDate(user.updatedAt)}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-[#94A3B8]">Status:</span>
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                    user.isActive !== false 
                      ? 'bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30' 
                      : 'bg-[#64748B]/20 text-[#94A3B8] border border-[#64748B]/30'
                  }`}>
                    {user.isActive !== false ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>
            </div>
            
            <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6">
              <h4 className="text-lg font-semibold text-white mb-4 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                Account Activity
              </h4>
              
              <div className="space-y-4">
                <div className="flex justify-between items-center p-3 bg-white/5 rounded-lg border border-white/10">
                  <span className="text-[#94A3B8]">Total Emergency Trips:</span>
                  <span className="text-white font-medium px-3 py-1 bg-[#3B82F6]/20 rounded-lg border border-[#3B82F6]/30">
                    {trips.length}
                  </span>
                </div>
                <div className="flex justify-between items-center p-3 bg-white/5 rounded-lg border border-white/10">
                  <span className="text-[#94A3B8]">Completed Trips:</span>
                  <span className="text-white font-medium px-3 py-1 bg-[#0D9488]/20 rounded-lg border border-[#0D9488]/30">
                    {trips.filter(trip => trip.status === 'completed').length}
                  </span>
                </div>
                <div className="flex justify-between items-center p-3 bg-white/5 rounded-lg border border-white/10">
                  <span className="text-[#94A3B8]">Cancelled Trips:</span>
                  <span className="text-white font-medium px-3 py-1 bg-[#DC2626]/20 rounded-lg border border-[#DC2626]/30">
                    {trips.filter(trip => trip.status === 'cancelled').length}
                  </span>
                </div>
                {trips.length > 0 && (
                  <div className="flex justify-between items-center p-3 bg-white/5 rounded-lg border border-white/10">
                    <span className="text-[#94A3B8]">Last Trip Date:</span>
                    <span className="text-white font-medium">
                      {formatDate(trips.sort((a, b) => 
                        (b.timestamp?.seconds || 0) - (a.timestamp?.seconds || 0)
                      )[0]?.timestamp || trips[0]?.createdAt)}
                    </span>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
        
        {activeTab === 'medical' && (
          <div>
            {/* Check both medicalInfo state and direct fields on user */}
            {(medicalInfo || user.bloodType || user.allergies) ? (
              <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6">
                <h4 className="text-lg font-semibold text-white mb-4 flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                  Medical Information
                </h4>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Blood Type</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.bloodType) || user.bloodType || 'Not specified'}
                      </span>
                    </div>
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Allergies</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.allergies) || user.allergies || 'None'}
                      </span>
                    </div>
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Medications</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.medications) || user.medications || 'None'}
                      </span>
                    </div>
                  </div>
                  
                  <div className="space-y-4">
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Medical Conditions</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.medicalConditions) || user.medicalConditions || 'None'}
                      </span>
                    </div>
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Past Surgeries</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.pastSurgeries) || user.pastSurgeries || 'None'}
                      </span>
                    </div>
                    <div className="p-3 bg-white/5 rounded-lg border border-white/10">
                      <span className="block text-[#94A3B8] text-sm">Additional Notes</span>
                      <span className="text-white font-medium">
                        {(medicalInfo && medicalInfo.additionalNotes) || user.additionalNotes || 'None'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-8 text-center">
                <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 rounded-full bg-white/5 border border-white/10">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-[#94A3B8]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <p className="text-white text-lg mb-1">No Medical Information Available</p>
                <p className="text-[#94A3B8] text-sm">This user has not provided any medical information yet.</p>
              </div>
            )}
          </div>
        )}
        
        {activeTab === 'trips' && (
          <div>
            {trips.length > 0 ? (
              <div className="overflow-x-auto backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10">
                <table className="min-w-full divide-y divide-white/10">
                  <thead>
                    <tr className="bg-white/5">
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Date</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Driver</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Status</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Location</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Duration</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/10">
                    {trips.map((trip) => (
                      <tr key={trip.id} className="hover:bg-white/5 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                          {formatDate(trip.timestamp || trip.createdAt)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                          {trip.driverName || (trip.driverId ? trip.driverId.substring(0, 8) : 'N/A')}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {getStatusBadge(trip.status)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                          {trip.pickupLocation || trip.pickupAddress || 'Unknown'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                          {trip.duration ? `${trip.duration} min` : 'N/A'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-8 text-center">
                <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 rounded-full bg-white/5 border border-white/10">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-[#94A3B8]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                  </svg>
                </div>
                <p className="text-white text-lg mb-1">No Trip History</p>
                <p className="text-[#94A3B8] text-sm">This user has not taken any emergency trips yet.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default UserDetail;