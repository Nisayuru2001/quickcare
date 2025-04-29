import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import { collection, query, onSnapshot, where } from 'firebase/firestore';
import { db } from '../firebase';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix for default marker icons in React Leaflet
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Custom marker icons
const activeIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const inactiveIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-grey.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const busyIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

function DriverLocationMap() {
  const [driverLocations, setDriverLocations] = useState([]);
  const [activeTrips, setActiveTrips] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [mapCenter, setMapCenter] = useState([37.7749, -122.4194]); 
  const [zoom, setZoom] = useState(12);
  
  useEffect(() => {
    // First, fetch active trips
    const tripsQuery = query(
      collection(db, "emergency_requests"),
      where("status", "==", "accepted")
    );
    
    const tripsUnsubscribe = onSnapshot(tripsQuery, (snapshot) => {
      const activeTripsMap = {};
      snapshot.forEach((doc) => {
        const tripData = doc.data();
        if (tripData.driverId) {
          activeTripsMap[tripData.driverId] = {
            tripId: doc.id,
            patientName: tripData.userName || 'Unknown patient',
            patientLocation: tripData.location || null,
            acceptedAt: tripData.acceptedAt || null
          };
        }
      });
      setActiveTrips(activeTripsMap);
    }, (err) => {
      console.error("Error fetching active trips:", err);
      setError("Failed to load active trips data");
    });

    // Fetch driver locations with real-time updates
    const locationsUnsubscribe = onSnapshot(
      collection(db, "driver_locations"),
      (snapshot) => {
        console.log("Driver locations snapshot received:", snapshot.size, "documents");
        const locations = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          console.log("Driver location data:", data);
          
          // Only include drivers with valid location data
          if (data.location && data.location.latitude && data.location.longitude) {
            locations.push({
              id: doc.id,
              driverId: data.driverId || doc.id,
              location: {
                lat: data.location.latitude,
                lng: data.location.longitude
              },
              timestamp: data.timestamp,
              isOnline: data.isOnline || false,
              speed: data.speed || 0,
              heading: data.heading || 0,
              driverName: data.driverName || 'Unknown Driver',
              phoneNumber: data.phoneNumber || 'N/A',
              status: data.status || 'unknown'
            });
          } else {
            console.warn("Driver location missing valid coordinates:", doc.id);
          }
        });
        
        console.log("Processed driver locations:", locations);
        setDriverLocations(locations);
        setLoading(false);
        
        // Update map center if we have locations
        if (locations.length > 0) {
          updateMapCenter(locations);
        }
      },
      (err) => {
        console.error("Error fetching driver locations:", err);
        setError("Failed to load location data");
        setLoading(false);
      }
    );

    // Fetch driver profiles for additional info
    const profilesQuery = query(collection(db, "driver_profiles"));
    const profilesUnsubscribe = onSnapshot(profilesQuery, (snapshot) => {
      const profileData = {};
      snapshot.forEach((doc) => {
        profileData[doc.id] = doc.data();
      });
      
      // Update driver locations with profile data
      setDriverLocations(prevLocations => {
        const updatedLocations = prevLocations.map(loc => {
          const profile = profileData[loc.driverId];
          if (profile) {
            return {
              ...loc,
              driverName: profile.fullName || loc.driverName,
              phoneNumber: profile.phoneNumber || loc.phoneNumber,
              status: profile.status || loc.status
            };
          }
          return loc;
        });
        return updatedLocations;
      });
    }, (err) => {
      console.error("Error fetching driver profiles:", err);
    });

    return () => {
      tripsUnsubscribe();
      locationsUnsubscribe();
      profilesUnsubscribe();
    };
  }, []);

  // Calculate map center based on driver locations
  const updateMapCenter = (locations) => {
    if (locations.length === 0) return;
    
    // Calculate the average lat/lng of all drivers
    const sum = locations.reduce(
      (acc, loc) => {
        return {
          lat: acc.lat + loc.location.lat,
          lng: acc.lng + loc.location.lng
        };
      },
      { lat: 0, lng: 0 }
    );
    
    setMapCenter([
      sum.lat / locations.length,
      sum.lng / locations.length
    ]);
  };

  const getDriverIcon = (driverId, isOnline) => {
    // Driver is on an active trip
    if (activeTrips[driverId]) {
      return busyIcon;
    }
    
    // Driver is online but not on a trip
    if (isOnline) {
      return activeIcon;
    }
    
    // Driver is offline
    return inactiveIcon;
  };

  const getDriverStatus = (driverId, isOnline) => {
    if (activeTrips[driverId]) {
      return 'On Trip with Patient';
    }
    
    if (isOnline) {
      return 'Available';
    }
    
    return 'Offline';
  };

  const refreshMap = () => {
    setLoading(true);
    setTimeout(() => setLoading(false), 500);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96 backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-6">
        <svg className="animate-spin h-10 w-10 text-[#3B82F6]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span className="ml-3 text-[#94A3B8]">Loading driver locations...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-[#DC2626]/10 backdrop-blur-sm p-6 rounded-xl shadow-lg border border-[#DC2626]/30 text-white">
        <h3 className="text-lg font-semibold mb-2 flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 text-[#DC2626]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          Error Loading Map
        </h3>
        <p className="text-[#94A3B8] mb-4">{error}</p>
        <button 
          onClick={refreshMap}
          className="mt-2 px-4 py-2 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] text-white rounded-lg transition-colors shadow-lg flex items-center"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Retry
        </button>
      </div>
    );
  }

  if (driverLocations.length === 0) {
    return (
      <div className="backdrop-blur-sm bg-white/5 rounded-xl shadow-lg border border-white/10 p-8 text-center">
        <div className="flex items-center justify-center w-20 h-20 mx-auto mb-4 rounded-full bg-white/5 border border-white/10">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 text-[#94A3B8]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
          </svg>
        </div>
        <h3 className="text-xl font-semibold text-white mb-2">No Driver Locations Available</h3>
        <p className="text-[#94A3B8] mb-6">There are currently no active drivers with location data to display.</p>
        <button 
          onClick={refreshMap}
          className="px-4 py-2 bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] text-white rounded-lg transition-colors shadow-lg flex items-center mx-auto"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh Map
        </button>
      </div>
    );
  }

  // Custom popup styles - Leaflet popups need custom styling
  const customPopupStyle = `
    .leaflet-popup-content-wrapper {
      background: rgba(15, 23, 42, 0.8);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 12px;
      color: white;
    }
    .leaflet-popup-tip {
      background: rgba(15, 23, 42, 0.8);
      border: 1px solid rgba(255, 255, 255, 0.1);
    }
  `;

  return (
    <div className="w-full">
      <style>{customPopupStyle}</style>
      
      <div className="p-4 border-b border-white/10 flex items-center justify-between">
        <h2 className="text-lg font-semibold text-white flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          Driver Locations
        </h2>
        <div className="flex items-center space-x-4">
          <div className="flex items-center">
            <div className="w-3 h-3 rounded-full bg-[#0D9488] mr-2"></div>
            <span className="text-sm text-[#94A3B8]">Available</span>
          </div>
          <div className="flex items-center">
            <div className="w-3 h-3 rounded-full bg-[#DC2626] mr-2"></div>
            <span className="text-sm text-[#94A3B8]">On Trip</span>
          </div>
          <div className="flex items-center">
            <div className="w-3 h-3 rounded-full bg-[#64748B] mr-2"></div>
            <span className="text-sm text-[#94A3B8]">Offline</span>
          </div>
          <button 
            onClick={refreshMap}
            className="ml-4 p-2 bg-[#3B82F6]/20 text-[#3B82F6] rounded-full hover:bg-[#3B82F6]/30 transition-colors border border-[#3B82F6]/30"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
      </div>
      
      <div className="h-[600px] z-0 relative bg-[#0F172A]/30 backdrop-blur-sm rounded-b-xl overflow-hidden">
        <MapContainer 
          key={driverLocations.length > 0 ? driverLocations[0].id : 'map'} // Force re-render when data changes
          center={mapCenter} 
          zoom={zoom} 
          style={{ height: '100%', width: '100%' }}
          className="z-0"
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          
          {driverLocations.map((driver) => (
            <Marker
              key={driver.id}
              position={[driver.location.lat, driver.location.lng]}
              icon={getDriverIcon(driver.driverId, driver.isOnline)}
            >
              <Popup className="custom-popup">
                <div className="p-2">
                  <h3 className="font-bold text-lg text-white">{driver.driverName || `Driver ID: ${driver.driverId.substring(0, 8)}`}</h3>
                  <div className="space-y-1 mt-2">
                    <p className="text-[#E2E8F0] flex items-center">
                      <span className="inline-block w-24 font-semibold">Status:</span> 
                      <span className={`px-2 py-0.5 rounded-full text-xs ${
                        activeTrips[driver.driverId] 
                          ? 'bg-[#DC2626]/20 text-[#DC2626] border border-[#DC2626]/30' 
                          : driver.isOnline 
                            ? 'bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30' 
                            : 'bg-[#64748B]/20 text-[#64748B] border border-[#64748B]/30'
                      }`}>
                        {getDriverStatus(driver.driverId, driver.isOnline)}
                      </span>
                    </p>
                    
                    {activeTrips[driver.driverId] && (
                      <p className="text-[#E2E8F0] flex items-center">
                        <span className="inline-block w-24 font-semibold">Patient:</span> 
                        <span>{activeTrips[driver.driverId].patientName}</span>
                      </p>
                    )}
                    
                    <p className="text-[#E2E8F0] flex items-center">
                      <span className="inline-block w-24 font-semibold">Phone:</span> 
                      <span>{driver.phoneNumber || 'N/A'}</span>
                    </p>
                    
                    <p className="text-[#E2E8F0] flex items-center">
                      <span className="inline-block w-24 font-semibold">Speed:</span> 
                      <span>{Math.round(driver.speed * 3.6)} km/h</span>
                    </p>
                  </div>
                  
                  <p className="text-xs text-[#94A3B8] mt-3 pt-2 border-t border-white/10">
                    Last updated: {driver.timestamp ? new Date(driver.timestamp.seconds * 1000).toLocaleString() : 'Unknown'}
                  </p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}

export default DriverLocationMap;