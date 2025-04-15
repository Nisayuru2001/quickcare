import React, { useState } from 'react';

function DriverList({ drivers, onApprove, onReject }) {
  const [filter, setFilter] = useState('all'); // 'all', 'pending', 'approved', 'rejected'

  const filteredDrivers = drivers.filter(driver => {
    if (filter === 'all') return true;
    return driver.status === filter;
  });

  return (
    <div className="bg-white shadow-md rounded-lg p-6">
      <div className="mb-6 flex flex-wrap gap-2">
        <button 
          className={`px-4 py-2 rounded ${filter === 'all' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
          onClick={() => setFilter('all')}
        >
          All Drivers
        </button>
        <button 
          className={`px-4 py-2 rounded ${filter === 'pending' ? 'bg-yellow-500 text-white' : 'bg-gray-200'}`}
          onClick={() => setFilter('pending')}
        >
          Pending
        </button>
        <button 
          className={`px-4 py-2 rounded ${filter === 'approved' ? 'bg-green-500 text-white' : 'bg-gray-200'}`}
          onClick={() => setFilter('approved')}
        >
          Approved
        </button>
        <button 
          className={`px-4 py-2 rounded ${filter === 'rejected' ? 'bg-red-500 text-white' : 'bg-gray-200'}`}
          onClick={() => setFilter('rejected')}
        >
          Rejected
        </button>
      </div>

      {filteredDrivers.length === 0 ? (
        <div className="text-center py-10 text-gray-500">No drivers found</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full bg-white">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredDrivers.map((driver) => (
                <tr key={driver.id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {driver.name || 'N/A'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {driver.email || 'N/A'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {driver.phone || 'N/A'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      driver.status === 'approved' ? 'bg-green-100 text-green-800' : 
                      driver.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 
                      'bg-red-100 text-red-800'
                    }`}>
                      {driver.status || 'pending'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {driver.status === 'pending' && (
                      <>
                        <button
                          onClick={() => onApprove(driver.id)}
                          className="text-green-600 hover:text-green-900 mr-4"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => onReject(driver.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          Reject
                        </button>
                      </>
                    )}
                    {driver.status === 'rejected' && (
                      <button
                        onClick={() => onApprove(driver.id)}
                        className="text-green-600 hover:text-green-900"
                      >
                        Approve
                      </button>
                    )}
                    {driver.status === 'approved' && (
                      <button
                        onClick={() => onReject(driver.id)}
                        className="text-red-600 hover:text-red-900"
                      >
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
    </div>
  );
}

export default DriverList;