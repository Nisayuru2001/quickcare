import React, { useState, useEffect } from 'react';
import { collection, query, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from '../firebase';
import TripDetails from './TripDetails';

function TripHistoryManagement() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentTrip, setCurrentTrip] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('all');
  const [timeFrame, setTimeFrame] = useState('all');
  
  useEffect(() => {
    fetchTrips();
  }, []);
  
  async function fetchTrips() {
    setLoading(true);
    setError('');
    
    try {
      console.log("Fetching trips from Firestore...");
      
      // Base query for emergency_requests collection
      let tripsQuery = query(
        collection(db, "emergency_requests"),
        orderBy("createdAt", "desc"),
        limit(100)
      );
      
      const querySnapshot = await getDocs(tripsQuery);
      
      console.log(`Retrieved ${querySnapshot.size} documents`);
      
      if (querySnapshot.empty) {
        console.log("No trips found in the database");
        setTrips([]);
        setLoading(false);
        return;
      }
      
      const tripsData = [];
      
      // Process each document
      querySnapshot.forEach(doc => {
        const data = doc.data();
        
        // Add some validation/logging to understand the data structure
        console.log(`Processing trip document ${doc.id}:`, data);
        
        // Create a consistent trip object with fallback values for missing fields
        const trip = {
          id: doc.id,
          status: data.status || 'unknown',
          userName: data.userName || 'Unknown User',
          driverName: data.driverName || 'Unassigned',
          driverId: data.driverId || null,
          userId: data.userId || null,
          locationDescription: data.locationDescription || 'Unknown location',
          location: data.location || null,
          createdAt: data.createdAt || null,
          acceptedAt: data.acceptedAt || null,
          completedAt: data.completedAt || null,
          cancellationReason: data.cancellationReason || null,
          ...data // Include all other fields
        };
        
        tripsData.push(trip);
      });
      
      console.log("Processed trips data:", tripsData);
      setTrips(tripsData);
    } catch (err) {
      console.error("Error fetching trips:", err);
      setError("Failed to load trip data: " + err.message);
    } finally {
      setLoading(false);
    }
  }
  
  // Filter trips based on user selections and search term
  const filteredTrips = trips.filter(trip => {
    // Apply status filter
    if (filter !== 'all' && trip.status !== filter) {
      // Map 'in_progress' filter button value to 'accepted' status in database
      if (filter === 'in_progress' && trip.status === 'accepted') {
        return true;
      }
      return false;
    }
    
    // Apply time frame filter
    if (timeFrame !== 'all' && trip.createdAt) {
      const now = new Date();
      let tripDate;
      
      // Handle Firestore timestamp
      if (trip.createdAt.seconds) {
        tripDate = new Date(trip.createdAt.seconds * 1000);
      } 
      // Handle string date
      else if (typeof trip.createdAt === 'string') {
        tripDate = new Date(trip.createdAt);
      }
      // Handle Date object
      else if (trip.createdAt instanceof Date) {
        tripDate = trip.createdAt;
      } else {
        return true; // If we can't parse the date, include it in results
      }
      
      if (!tripDate) return true;
      
      const dayDiff = (now - tripDate) / (1000 * 60 * 60 * 24);
      
      if (timeFrame === 'today' && dayDiff >= 1) return false;
      if (timeFrame === 'week' && dayDiff >= 7) return false;
      if (timeFrame === 'month' && dayDiff >= 30) return false;
    }
    
    // Apply search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      return (
        (trip.userName && trip.userName.toLowerCase().includes(searchLower)) ||
        (trip.driverName && trip.driverName.toLowerCase().includes(searchLower)) ||
        (trip.locationDescription && trip.locationDescription.toLowerCase().includes(searchLower)) ||
        (trip.id.toLowerCase().includes(searchLower))
      );
    }
    
    return true;
  });
  
  // Format date for display with better error handling
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
      return 'Invalid date';
    }
  };
  
  // Get status badge with appropriate styling
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
  
  // View trip details
  const viewTripDetails = (tripId) => {
    setCurrentTrip(tripId);
  };
  
  // Back to trip list
  const backToList = () => {
    setCurrentTrip(null);
  };
  
  if (currentTrip) {
    return <TripDetails tripId={currentTrip} onBack={backToList} />;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Trip History</h2>
        <button 
          onClick={fetchTrips}
          className="bg-white border border-gray-300 text-gray-700 py-2 px-4 rounded-md hover:bg-gray-50 flex items-center text-sm font-medium"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>
      
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        {/* Filter and Search */}
        <div className="p-6 border-b border-gray-100">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
            <div className="flex flex-wrap gap-2">
              <button 
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === 'all' 
                    ? 'bg-indigo-600 text-white' 
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
                onClick={() => setFilter('all')}
              >
                All Trips
              </button>
              <button 
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === 'pending' 
                    ? 'bg-yellow-500 text-white' 
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
                onClick={() => setFilter('pending')}
              >
                Pending
              </button>
              <button 
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === 'in_progress' 
                    ? 'bg-blue-500 text-white' 
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
                onClick={() => setFilter('in_progress')}
              >
                In Progress
              </button>
              <button 
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === 'completed' 
                    ? 'bg-green-500 text-white' 
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
                onClick={() => setFilter('completed')}
              >
                Completed
              </button>
              <button 
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === 'cancelled' 
                    ? 'bg-red-500 text-white' 
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
                onClick={() => setFilter('cancelled')}
              >
                Cancelled
              </button>
            </div>
            
            <div className="flex space-x-2 items-center">
              <select
                className="pl-3 pr-10 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500 text-sm"
                value={timeFrame}
                onChange={(e) => setTimeFrame(e.target.value)}
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">Past Week</option>
                <option value="month">Past Month</option>
              </select>
              
              <div className="relative">
                <input
                  type="text"
                  placeholder="Search trips..."
                  className="pl-10 pr-4 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg className="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Table */}
        {loading ? (
          <div className="bg-white p-8 text-center">
            <svg className="animate-spin h-10 w-10 text-indigo-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p className="text-gray-500">Loading trip data...</p>
          </div>
        ) : error ? (
          <div className="bg-red-50 p-8 text-center">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-red-500 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p className="text-red-800 mb-2 text-lg font-semibold">Error Loading Trips</p>
            <p className="text-red-600">{error}</p>
            <button
              onClick={fetchTrips}
              className="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
            >
              Try Again
            </button>
          </div>
        ) : filteredTrips.length === 0 ? (
          <div className="text-center py-12 px-6">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12 text-gray-400 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <p className="text-gray-500 text-lg mb-1">No trips found</p>
            <p className="text-gray-400 text-sm">Try adjusting your search or filter criteria.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Trip ID</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date & Time</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Patient</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Driver</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
                  <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredTrips.map((trip) => (
                  <tr key={trip.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm text-gray-900 font-mono">{trip.id.substring(0, 8)}</span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{formatDate(trip.createdAt)}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{trip.userName || 'Unknown'}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{trip.driverName || (trip.driverId ? trip.driverId.substring(0, 8) : 'Unassigned')}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getStatusBadge(trip.status)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900 max-w-xs truncate">{trip.locationDescription || (trip.location ? `${trip.location.latitude.toFixed(4)}, ${trip.location.longitude.toFixed(4)}` : 'Unknown')}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        onClick={() => viewTripDetails(trip.id)}
                        className="bg-indigo-50 text-indigo-700 hover:bg-indigo-100 px-3 py-1 rounded-md text-sm font-medium transition-colors flex items-center"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        </svg>
                        View Details
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        
        {/* Pagination */}
        {filteredTrips.length > 0 && (
          <div className="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
            <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
              <div>
                <p className="text-sm text-gray-700">
                  Showing <span className="font-medium">1</span> to <span className="font-medium">{filteredTrips.length}</span> of{' '}
                  <span className="font-medium">{filteredTrips.length}</span> results
                </p>
              </div>
              <div>
                <nav className="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
                  <button
                    className="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                  >
                    <span className="sr-only">Previous</span>
                    <svg className="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  </button>
                  <button
                    aria-current="page"
                    className="relative inline-flex items-center px-4 py-2 border border-indigo-500 bg-indigo-50 text-sm font-medium text-indigo-600"
                  >
                    1
                  </button>
                  <button
                    className="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                  >
                    <span className="sr-only">Next</span>
                    <svg className="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" />
                    </svg>
                  </button>
                </nav>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default TripHistoryManagement;