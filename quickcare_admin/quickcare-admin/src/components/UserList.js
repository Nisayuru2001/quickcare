import React, { useState } from 'react';

function UserList({ users, onViewDetails }) {
  const [searchTerm, setSearchTerm] = useState('');
  
  const filteredUsers = users.filter(user => {
    // Apply search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      return (
        (user.fullName && user.fullName.toLowerCase().includes(searchLower)) ||
        (user.email && user.email.toLowerCase().includes(searchLower)) ||
        (user.phoneNumber && user.phoneNumber.toLowerCase().includes(searchLower)) ||
        (user.emergencyContact && user.emergencyContact.toLowerCase().includes(searchLower))
      );
    }
    return true;
  });

  // Get user name from fullName field with fallback
  const getUserName = (user) => {
    return user.fullName || 'Unnamed User';
  };
  
  // Get user phone from phoneNumber field with fallback
  const getUserPhone = (user) => {
    return user.phoneNumber || 'N/A';
  };
  
  // Get user email with fallback
  const getUserEmail = (user) => {
    return user.email || 'N/A';
  };
  
  // Get initial for avatar
  const getInitial = (user) => {
    return user.fullName ? user.fullName.charAt(0).toUpperCase() : 'U';
  };
  
  // Format date with better error handling
  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    
    try {
      // Handle both Firestore timestamp and regular Date objects
      if (timestamp.seconds) {
        const date = new Date(timestamp.seconds * 1000);
        return date.toLocaleDateString();
      } else if (timestamp instanceof Date) {
        return timestamp.toLocaleDateString();
      } else if (typeof timestamp === 'string') {
        return new Date(timestamp).toLocaleDateString();
      }
      return 'N/A';
    } catch (error) {
      console.error("Error formatting date:", error);
      return 'N/A';
    }
  };

  return (
    <div className="w-full">
      {/* Search */}
      <div className="p-6 border-b border-white/10">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
          <h3 className="text-lg font-semibold text-white flex items-center">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            User Management
          </h3>
          
          <div className="relative">
            <input
              type="text"
              placeholder="Search users..."
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
      {filteredUsers.length === 0 ? (
        <div className="text-center py-12 px-6">
          <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 rounded-full bg-white/5 border border-white/10">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-[#94A3B8]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
          </div>
          <p className="text-white text-lg mb-1">No users found</p>
          <p className="text-[#94A3B8] text-sm">Try adjusting your search to find what you're looking for.</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-white/10">
            <thead className="bg-white/5">
              <tr>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">User</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Email</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Phone</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Registered</th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-[#94A3B8] uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/10">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-white/5 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10 rounded-full bg-gradient-to-br from-[#3B82F6]/30 to-[#4F46E5]/30 border border-white/10 flex items-center justify-center">
                        <span className="text-white font-medium text-sm">
                          {getInitial(user)}
                        </span>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-white">{getUserName(user)}</div>
                        <div className="text-sm text-[#94A3B8]">
                          {user.emergencyContact ? `Emergency: ${user.emergencyContact}` : `ID: ${user.id.substring(0, 8)}`}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-white">{getUserEmail(user)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-white">{getUserPhone(user)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-white">{formatDate(user.createdAt)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      onClick={() => onViewDetails(user.id)}
                      className="bg-[#3B82F6]/20 text-[#3B82F6] border border-[#3B82F6]/30 hover:bg-[#3B82F6]/30 px-3 py-1 rounded-lg text-sm font-medium transition-colors flex items-center"
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
      <div className="px-4 py-3 flex items-center justify-between border-t border-white/10 sm:px-6">
        <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
          <div>
            <p className="text-sm text-[#94A3B8]">
              Showing <span className="font-medium text-white">1</span> to <span className="font-medium text-white">{filteredUsers.length}</span> of{' '}
              <span className="font-medium text-white">{filteredUsers.length}</span> results
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

export default UserList;