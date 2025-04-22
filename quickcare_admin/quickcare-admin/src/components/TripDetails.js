import React, { useState, useEffect } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';

function TripDetails({ tripId, onBack }) {
  const [trip, setTrip] = useState(null);
  const [driver, setDriver] = useState(null);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function fetchTripData() {
      setLoading(true);
      try {
        // Fetch trip data
        const tripDoc = await getDoc(doc(db, "emergency_requests", tripId));
        
        if (tripDoc.exists()) {
          const tripData = { id: tripDoc.id, ...tripDoc.data() };
          setTrip(tripData);
          
          // Fetch driver data if available
          if (tripData.driverId) {
            const driverDoc = await getDoc(doc(db, "driver_profiles", tripData.driverId));
            if (driverDoc.exists()) {
              setDriver({ id: driverDoc.id, ...driverDoc.data() });
            }
          }
          
          // Fetch user data if available
          if (tripData.userId) {
            const userDoc = await getDoc(doc(db, "users", tripData.userId));
            if (userDoc.exists()) {
              setUser({ id: userDoc.id, ...userDoc.data() });
            }
          }
        } else {
          setError("Trip not found");
        }
      } catch (err) {
        console.error("Error fetching trip data:", err);
        setError("Failed to load trip data: " + err.message);
      } finally {
        setLoading(false);
      }
    }
    
    fetchTripData();
  }, [tripId]);

  // Format date for display
  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    
    try {
      const date = new Date(timestamp.seconds * 1000);
      return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    } catch (error) {
      return 'Invalid date';
    }
  };
  
  // Get trip duration in minutes
  const getTripDuration = () => {
    if (!trip || !trip.acceptedAt || !trip.completedAt) return 'N/A';
    
    try {
      const durationInSeconds = trip.completedAt.seconds - trip.acceptedAt.seconds;
      const minutes = Math.floor(durationInSeconds / 60);
      const seconds = durationInSeconds % 60;
      
      if (minutes < 1) {
        return `${seconds} seconds`;
      }
      
      return `${minutes} min ${seconds} sec`;
    } catch (error) {
      return 'Error calculating duration';
    }
  };
  
  // Get status badge with appropriate color
  const getStatusBadge = (status) => {
    let color = '';
    
    switch (status) {
      case 'pending':
        color = 'bg-yellow-100 text-yellow-800';
        break;
      case 'accepted':
        color = 'bg-blue-100 text-blue-800';
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
      <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${color}`}>
        {status && status.charAt(0).toUpperCase() + status.slice(1)}
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
        <p className="text-gray-500">Loading trip details...</p>
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
            Back
          </button>
        </div>
      </div>
    );
  }

  if (!trip) {
    return (
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 text-center py-12">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-gray-400 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p className="text-gray-500 text-lg mb-1">Trip not found</p>
        <button
          onClick={onBack}
          className="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Back
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
          <h3 className="text-lg font-semibold text-gray-800">Trip Details</h3>
        </div>
        <div className="text-sm text-gray-500">Trip ID: {tripId}</div>
      </div>
      
      {/* Content */}
      <div className="p-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Trip Information Panel */}
        <div className="bg-gray-50 rounded-lg p-6">
          <h4 className="text-lg font-semibold text-gray-800 mb-4">Trip Information</h4>
          
          <div className="space-y-4">
            <div className="flex items-center">
              <span className="w-32 flex-shrink-0 text-gray-500">Status:</span>
              <span>{getStatusBadge(trip.status)}</span>
            </div>
            
            <div className="flex">
              <span className="w-32 flex-shrink-0 text-gray-500">Requested:</span>
              <span className="text-gray-900 font-medium">{formatDate(trip.createdAt)}</span>
            </div>
            
            <div className="flex">
              <span className="w-32 flex-shrink-0 text-gray-500">Accepted:</span>
              <span className="text-gray-900 font-medium">{formatDate(trip.acceptedAt)}</span>
            </div>
            
            <div className="flex">
              <span className="w-32 flex-shrink-0 text-gray-500">Completed:</span>
              <span className="text-gray-900 font-medium">{formatDate(trip.completedAt)}</span>
            </div>
            
            <div className="flex">
              <span className="w-32 flex-shrink-0 text-gray-500">Duration:</span>
              <span className="text-gray-900 font-medium">{getTripDuration()}</span>
            </div>
            
            {trip.cancellationReason && (
              <div className="flex">
                <span className="w-32 flex-shrink-0 text-gray-500">Cancelled:</span>
                <span className="text-red-600 font-medium">{trip.cancellationReason}</span>
              </div>
            )}
            
            <div className="flex">
              <span className="w-32 flex-shrink-0 text-gray-500">Location:</span>
              <span className="text-gray-900 font-medium">{trip.locationDescription || 'Unknown location'}</span>
            </div>
            
            {trip.location && (
              <div className="mt-4">
                <span className="text-gray-500 block mb-2">Coordinates:</span>
                <div className="bg-gray-100 rounded-md p-3 text-sm font-mono">
                  Lat: {trip.location.latitude}, Lng: {trip.location.longitude}
                </div>
                <a 
                  href={`https://www.google.com/maps/search/?api=1&query=${trip.location.latitude},${trip.location.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-2 inline-flex items-center text-sm text-indigo-600 hover:text-indigo-800"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                  View on Google Maps
                </a>
              </div>
            )}
          </div>
        </div>
        
        {/* User and Driver Information Panels */}
        <div className="space-y-6">
          {/* User Information */}
          <div className="bg-gray-50 rounded-lg p-6">
            <h4 className="text-lg font-semibold text-gray-800 mb-4">Patient Information</h4>
            
            {user ? (
              <div className="space-y-4">
                <div className="flex items-center">
                  <div className="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center text-lg font-semibold text-blue-700 mr-3">
                    {user.fullName ? user.fullName.charAt(0).toUpperCase() : 'U'}
                  </div>
                  <div>
                    <h5 className="text-gray-900 font-medium">{user.fullName || 'Unknown Patient'}</h5>
                    <p className="text-gray-500 text-sm">{user.email || 'No email'}</p>
                  </div>
                </div>
                
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Phone:</span>
                  <span className="text-gray-900 font-medium">{user.phoneNumber || 'Not provided'}</span>
                </div>
                
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Emergency Contact:</span>
                  <span className="text-gray-900 font-medium">{user.emergencyContact || trip.emergencyContact || 'Not provided'}</span>
                </div>
                
                {/* Medical info from trip */}
                {trip.medicalInfo && (
                  <>
                    <div className="border-t border-gray-200 pt-4 mt-4">
                      <h5 className="font-medium text-gray-700 mb-2">Medical Information</h5>
                      
                      <div className="text-sm grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-2">
                        <div className="flex">
                          <span className="w-24 flex-shrink-0 text-gray-500">Blood Type:</span>
                          <span className="text-gray-900">{trip.medicalInfo.bloodType || 'Not specified'}</span>
                        </div>
                        
                        <div className="flex">
                          <span className="w-24 flex-shrink-0 text-gray-500">Allergies:</span>
                          <span className="text-gray-900">{trip.medicalInfo.allergies || 'None'}</span>
                        </div>
                        
                        <div className="flex">
                          <span className="w-24 flex-shrink-0 text-gray-500">Conditions:</span>
                          <span className="text-gray-900">{trip.medicalInfo.medicalConditions || 'None'}</span>
                        </div>
                        
                        <div className="flex">
                          <span className="w-24 flex-shrink-0 text-gray-500">Medications:</span>
                          <span className="text-gray-900">{trip.medicalInfo.medications || 'None'}</span>
                        </div>
                      </div>
                    </div>
                  </>
                )}
              </div>
            ) : (
              <div className="text-center py-4">
                <p className="text-gray-500">Patient information not available</p>
              </div>
            )}
          </div>
          
          {/* Driver Information */}
          <div className="bg-gray-50 rounded-lg p-6">
            <h4 className="text-lg font-semibold text-gray-800 mb-4">Driver Information</h4>
            
            {driver ? (
              <div className="space-y-4">
                <div className="flex items-center">
                  <div className="h-10 w-10 rounded-full bg-green-100 flex items-center justify-center text-lg font-semibold text-green-700 mr-3">
                    {driver.fullName ? driver.fullName.charAt(0).toUpperCase() : 'D'}
                  </div>
                  <div>
                    <h5 className="text-gray-900 font-medium">{driver.fullName || 'Unknown Driver'}</h5>
                    <p className="text-gray-500 text-sm">{driver.email || 'No email'}</p>
                  </div>
                </div>
                
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Phone:</span>
                  <span className="text-gray-900 font-medium">{driver.phoneNumber || 'Not provided'}</span>
                </div>
                
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">License Number:</span>
                  <span className="text-gray-900 font-medium">{driver.licenseNumber || 'Not provided'}</span>
                </div>
                
                <div className="flex">
                  <span className="w-32 flex-shrink-0 text-gray-500">Status:</span>
                  <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${
                    driver.status === 'approved' ? 'bg-green-100 text-green-800' : 
                    driver.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 
                    'bg-gray-100 text-gray-800'
                  }`}>
                    {driver.status || 'Unknown'}
                  </span>
                </div>
              </div>
            ) : (
              <div className="text-center py-4">
                <p className="text-gray-500">Driver information not available</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default TripDetails;