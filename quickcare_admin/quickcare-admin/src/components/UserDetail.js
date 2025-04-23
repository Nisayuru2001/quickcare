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
    let color = '';
    let displayText = status && status.charAt(0).toUpperCase() + status.slice(1);
    
    switch (status) {
      case 'pending':
        color = 'bg-yellow-100 text-yellow-800';
        break;
      case 'accepted':
        color = 'bg-blue-100 text-blue-800';
        displayText = 'In Progress';
        break;
      case 'completed':
        color = 'bg-green-100 text-green-800';
        break;
      case 'cancelled':
        color = 'bg-red-100 text-red-800';
        break;
      default:
        color = 'bg-gray-100 text-gray-800';
    }
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${color}`}>
        {displayText || 'Unknown'}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 text-center py-12">
        <svg className="animate-spin h-10 w-10 text-indigo-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p className="text-gray-500">Loading user data...</p>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="bg-red-50 rounded-xl shadow-sm border border-red-100 p-6">
        <div className="flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-red-600 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="text-lg font-medium text-red-800">Error</h3>
        </div>
        <div className="mt-2 text-red-700">
          <p>{error}</p>
        </div>
        <div className="mt-4">
          <button
            type="button"
            onClick={onBack}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Back to User List
          </button>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 text-center py-12">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-gray-400 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
        </svg>
        <p className="text-gray-500 text-lg mb-1">User not found</p>
        <button
          onClick={onBack}
          className="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Back to User List
        </button>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      {/* Header */}
      <div className="p-6 border-b border-gray-100 flex justify-between items-center">
        <div className="flex items-center">
          <button
            onClick={onBack}
            className="p-2 mr-4 text-gray-500 hover:text-indigo-600 rounded-full hover:bg-indigo-50 transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </button>
          <h3 className="text-lg font-semibold text-gray-800">User Details</h3>
        </div>
        <div className="text-sm text-gray-500">User ID: {userId}</div>
      </div>
      
      {/* Tabs */}
      <div className="p-6 border-b border-gray-100">
        <div className="sm:hidden">
          <select
            id="tabs"
            name="tabs"
            className="block w-full focus:ring-indigo-500 focus:border-indigo-500 border-gray-300 rounded-md"
            value={activeTab}
            onChange={(e) => setActiveTab(e.target.value)}
          >
            <option value="profile">Profile</option>
            <option value="medical">Medical Info</option>
            <option value="trips">Trip History</option>
          </select>
        </div>
        <div className="hidden sm:block">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8" aria-label="Tabs">
              <button
                onClick={() => setActiveTab('profile')}
                className={`${
                  activeTab === 'profile'
                    ? 'border-indigo-500 text-indigo-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm`}
              >
                Profile
              </button>
              <button
                onClick={() => setActiveTab('medical')}
                className={`${
                  activeTab === 'medical'
                    ? 'border-indigo-500 text-indigo-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm`}
              >
                Medical Info
              </button>
              <button
                onClick={() => setActiveTab('trips')}
                className={`${
                  activeTab === 'trips'
                    ? 'border-indigo-500 text-indigo-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm`}
              >
                Trip History
              </button>
            </nav>
          </div>
        </div>
      </div>
      
      {/* Content */}
      <div className="p-6">
        {activeTab === 'profile' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-gray-50 p-6 rounded-lg">
              <div className="flex items-center mb-6">
                <div className="h-16 w-16 rounded-full bg-indigo-100 flex items-center justify-center text-2xl font-semibold text-indigo-800">
                  {user.fullName ? user.fullName.charAt(0).toUpperCase() : 'U'}
                </div>
                <div className="ml-4">
                  <h4 className="text-xl font-semibold text-gray-900">{user.fullName || 'No Name'}</h4>
                  <p className="text-gray-600">{user.email || 'No Email'}</p>
                </div>
              </div>
              
              <div className="space-y-3">
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Phone:</span>
                  <span className="text-gray-900 font-medium">{user.phoneNumber || 'Not provided'}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Emergency Contact:</span>
                  <span className="text-gray-900 font-medium">{user.emergencyContact || 'Not provided'}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Registered On:</span>
                  <span className="text-gray-900 font-medium">{formatDate(user.createdAt)}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Last Updated:</span>
                  <span className="text-gray-900 font-medium">{formatDate(user.updatedAt)}</span>
                </div>
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Status:</span>
                  <span className="text-gray-900 font-medium">{user.isActive !== false ? 'Active' : 'Inactive'}</span>
                </div>
              </div>
            </div>
            
            <div className="bg-gray-50 p-6 rounded-lg">
              <h4 className="text-lg font-semibold text-gray-900 mb-4">Account Activity</h4>
              
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-500">Total Emergency Trips:</span>
                  <span className="text-gray-900 font-medium">{trips.length}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Completed Trips:</span>
                  <span className="text-gray-900 font-medium">
                    {trips.filter(trip => trip.status === 'completed').length}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Cancelled Trips:</span>
                  <span className="text-gray-900 font-medium">
                    {trips.filter(trip => trip.status === 'cancelled').length}
                  </span>
                </div>
                {trips.length > 0 && (
                  <>
                    <div className="flex justify-between">
                      <span className="text-gray-500">Last Trip Date:</span>
                      <span className="text-gray-900 font-medium">
                        {formatDate(trips.sort((a, b) => 
                          (b.timestamp?.seconds || 0) - (a.timestamp?.seconds || 0)
                        )[0]?.timestamp || trips[0]?.createdAt)}
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>
        )}
        
        {activeTab === 'medical' && (
          <div>
            {/* Check both medicalInfo state and direct fields on user */}
            {(medicalInfo || user.bloodType || user.allergies) ? (
              <div className="bg-gray-50 p-6 rounded-lg">
                <h4 className="text-lg font-semibold text-gray-900 mb-4">Medical Information</h4>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-3">
                    <div className="flex">
                      <span className="w-32 flex-shrink-0 text-gray-500">Blood Type:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.bloodType) || user.bloodType || 'Not specified'}
                      </span>
                    </div>
                    <div className="flex">
                      <span className="w-32 flex-shrink-0 text-gray-500">Allergies:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.allergies) || user.allergies || 'None'}
                      </span>
                    </div>
                    <div className="flex">
                      <span className="w-32 flex-shrink-0 text-gray-500">Medications:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.medications) || user.medications || 'None'}
                      </span>
                    </div>
                  </div>
                  
                  <div className="space-y-3">
                    <div className="flex">
                      <span className="w-40 flex-shrink-0 text-gray-500">Medical Conditions:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.medicalConditions) || user.medicalConditions || 'None'}
                      </span>
                    </div>
                    <div className="flex">
                      <span className="w-40 flex-shrink-0 text-gray-500">Past Surgeries:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.pastSurgeries) || user.pastSurgeries || 'None'}
                      </span>
                    </div>
                    <div className="flex">
                      <span className="w-40 flex-shrink-0 text-gray-500">Additional Notes:</span>
                      <span className="text-gray-900 font-medium">
                        {(medicalInfo && medicalInfo.additionalNotes) || user.additionalNotes || 'None'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-gray-50 p-6 rounded-lg text-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-gray-400 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p className="text-gray-500 text-lg mb-1">No Medical Information Available</p>
                <p className="text-gray-400 text-sm">This user has not provided any medical information yet.</p>
              </div>
            )}
          </div>
        )}
        
        {activeTab === 'trips' && (
          <div>
            {trips.length > 0 ? (
              <div className="overflow-x-auto bg-gray-50 rounded-lg">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-100">
                    <tr>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Driver</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Duration</th>
                    </tr>
                  </thead>
                  <tbody className="bg-gray-50 divide-y divide-gray-200">
                    {trips.map((trip) => (
                      <tr key={trip.id} className="hover:bg-gray-100 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {formatDate(trip.timestamp || trip.createdAt)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {trip.driverName || (trip.driverId ? trip.driverId.substring(0, 8) : 'N/A')}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {getStatusBadge(trip.status)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {trip.locationDescription || 
                           (trip.location ? 
                             `[${typeof trip.location.latitude === 'number' ? trip.location.latitude.toFixed(6) : trip.location.latitude}, ${typeof trip.location.longitude === 'number' ? trip.location.longitude.toFixed(6) : trip.location.longitude}]` : 
                             'Unknown location')}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {trip.completedAt && trip.acceptedAt ? 
                            `${Math.round((trip.completedAt.seconds - trip.acceptedAt.seconds) / 60)} mins` : 
                            'N/A'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="bg-gray-50 p-6 rounded-lg text-center">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-gray-400 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p className="text-gray-500 text-lg mb-1">No Trip History Found</p>
                <p className="text-gray-400 text-sm">This user has not requested any ambulance trips yet.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default UserDetail;