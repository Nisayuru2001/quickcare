import React, { useState } from 'react';

function DriverList({ drivers, onApprove, onReject }) {
  const [filter, setFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  
  const filteredDrivers = drivers.filter(driver => {
    // Apply status filter
    if (filter !== 'all' && driver.status !== filter) return false;
    
    // Apply search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      return (
        (driver.fullName && driver.fullName.toLowerCase().includes(searchLower)) ||
        (driver.email && driver.email.toLowerCase().includes(searchLower)) ||
        (driver.phoneNumber && driver.phoneNumber.toLowerCase().includes(searchLower))
      );
    }
    
    return true;
  });

  // Get driver name from fullName field
  const getDriverName = (driver) => {
    return driver.fullName || 'N/A';
  };
  
  // Get driver phone from phoneNumber field
  const getDriverPhone = (driver) => {
    return driver.phoneNumber || 'N/A';
  };
  
  // Get driver email
  const getDriverEmail = (driver) => {
    return driver.email || 'N/A';
  };
  
  // Get initial for avatar
  const getInitial = (driver) => {
    return driver.fullName ? driver.fullName.charAt(0).toUpperCase() : 'N';
  };

  return (
    <div className="w-full">
      {/* Filter and Search */}
      <div className="p-6 border-b border-white/10">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
          <div className="flex flex-wrap gap-2">
            <button 
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === 'all' 
                  ? 'bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] text-white shadow-md' 
                  : 'bg-white/5 text-[#94A3B8] hover:bg-white/10 border border-white/10'
              }`}
              onClick={() => setFilter('all')}
            >
              All Drivers
            </button>
            <button 
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === 'pending' 
                  ? 'bg-[#D97706] text-white shadow-md' 
                  : 'bg-white/5 text-[#94A3B8] hover:bg-white/10 border border-white/10'
              }`}
              onClick={() => setFilter('pending')}
            >
              Pending
            </button>
            <button 
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === 'approved' 
                  ? 'bg-[#0D9488] text-white shadow-md' 
                  : 'bg-white/5 text-[#94A3B8] hover:bg-white/10 border border-white/10'
              }`}
              onClick={() => setFilter('approved')}
            >
              Approved
            </button>
            <button 
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === 'rejected' 
                  ? 'bg-[#DC2626] text-white shadow-md' 
                  : 'bg-white/5 text-[#94A3B8] hover:bg-white/10 border border-white/10'
              }`}
              onClick={() => setFilter('rejected')}
            >
              Rejected
            </button>
          </div>
          
          <div className="relative">
            <input
              type="text"
              placeholder="Search drivers..."
              className="pl-10 pr-4 py-2 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#3B82F6] focus:border-transparent text-white placeholder-[#94A3B8] w-full md:w-auto"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="h-5 w-5 text-[#94A3B8]" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      {filteredDrivers.length === 0 ? (
        <div className="text-center py-12 px-6">
          <div className="flex items-center justify-center w-16 h-16 mx-auto mb-3 rounded-full bg-white/5 border border-white/10 text-[#94A3B8]">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
            </svg>
          </div>
          <p className="text-white text-lg mb-1">No drivers found</p>
          <p className="text-[#94A3B8] text-sm">Try adjusting your search or filter to find what you're looking for.</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-white/10">
            <thead className="bg-white/5">
              <tr>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Name</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Email</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Phone</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Status</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {filteredDrivers.map((driver) => (
                <tr key={driver.id} className="hover:bg-white/5 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10 rounded-full bg-gradient-to-br from-[#3B82F6]/30 to-[#4F46E5]/30 border border-white/10 flex items-center justify-center">
                        <span className="text-white font-medium text-sm">
                          {getInitial(driver)}
                        </span>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-white">{getDriverName(driver)}</div>
                        <div className="text-sm text-[#94A3B8]">
                          {driver.licenseNumber ? `License: ${driver.licenseNumber}` : `ID: ${driver.id.substring(0, 8)}`}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-white">{getDriverEmail(driver)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-white">{getDriverPhone(driver)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      driver.status === 'approved' ? 'bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30' : 
                      driver.status === 'pending' ? 'bg-[#D97706]/20 text-[#D97706] border border-[#D97706]/30' : 
                      'bg-[#DC2626]/20 text-[#DC2626] border border-[#DC2626]/30'
                    }`}>
                      {driver.status === 'approved' && (
                        <svg className="mr-1.5 h-2 w-2 text-[#0D9488]" fill="currentColor" viewBox="0 0 8 8">
                          <circle cx="4" cy="4" r="3" />
                        </svg>
                      )}
                      {driver.status === 'pending' && (
                        <svg className="mr-1.5 h-2 w-2 text-[#D97706]" fill="currentColor" viewBox="0 0 8 8">
                          <circle cx="4" cy="4" r="3" />
                        </svg>
                      )}
                      {driver.status === 'rejected' && (
                        <svg className="mr-1.5 h-2 w-2 text-[#DC2626]" fill="currentColor" viewBox="0 0 8 8">
                          <circle cx="4" cy="4" r="3" />
                        </svg>
                      )}
                      {driver.status || 'pending'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {driver.status === 'pending' && (
                      <div className="flex space-x-2">
                        <button
                          onClick={() => onApprove(driver.id)}
                          className="bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30 hover:bg-[#0D9488]/30 px-3 py-1 rounded-lg text-sm font-medium transition-colors flex items-center"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                          Approve
                        </button>
                        <button
                          onClick={() => onReject(driver.id)}
                          className="bg-[#DC2626]/20 text-[#DC2626] border border-[#DC2626]/30 hover:bg-[#DC2626]/30 px-3 py-1 rounded-lg text-sm font-medium transition-colors flex items-center"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                          </svg>
                          Reject
                        </button>
                      </div>
                    )}
                    {driver.status === 'rejected' && (
                      <button
                        onClick={() => onApprove(driver.id)}
                        className="bg-[#0D9488]/20 text-[#0D9488] border border-[#0D9488]/30 hover:bg-[#0D9488]/30 px-3 py-1 rounded-lg text-sm font-medium transition-colors flex items-center"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        Approve
                      </button>
                    )}
                    {driver.status === 'approved' && (
                      <button
                        onClick={() => onReject(driver.id)}
                        className="bg-[#DC2626]/20 text-[#DC2626] border border-[#DC2626]/30 hover:bg-[#DC2626]/30 px-3 py-1 rounded-lg text-sm font-medium transition-colors flex items-center"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                        Reject
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      
      {/* Pagination */}
      <div className="px-4 py-3 flex items-center justify-between border-t border-white/10 sm:px-6">
        <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
          <div>
            <p className="text-sm text-[#94A3B8]">
              Showing <span className="font-medium text-white">1</span> to <span className="font-medium text-white">{filteredDrivers.length}</span> of{' '}
              <span className="font-medium text-white">{filteredDrivers.length}</span> results
            </p>
          </div>
          <div>
            <nav className="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
              <button
                className="relative inline-flex items-center px-2 py-2 rounded-l-md border border-white/10 bg-white/5 text-sm font-medium text-[#94A3B8] hover:bg-white/10"
              >
                <span className="sr-only">Previous</span>
                <svg className="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
              </button>
              <button
                aria-current="page"
                className="relative inline-flex items-center px-4 py-2 border border-[#3B82F6] bg-[#3B82F6]/20 text-sm font-medium text-[#3B82F6]"
              >
                1
              </button>
              <button
                className="relative inline-flex items-center px-2 py-2 rounded-r-md border border-white/10 bg-white/5 text-sm font-medium text-[#94A3B8] hover:bg-white/10"
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
    </div>
  );
}

export default DriverList;