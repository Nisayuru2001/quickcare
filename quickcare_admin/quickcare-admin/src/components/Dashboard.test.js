import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import Dashboard from './Dashboard';
import { BrowserRouter } from 'react-router-dom';

// Mock Firebase
jest.mock('../firebase', () => ({
  db: {
    collection: jest.fn()
  },
  auth: {
    onAuthStateChanged: jest.fn()
  }
}));

// Mock Firestore functions
jest.mock('firebase/firestore', () => ({
  collection: jest.fn(),
  query: jest.fn(),
  onSnapshot: jest.fn((query, callback) => {
    callback({
      forEach: (fn) => {
        const mockDrivers = [
          { id: '1', status: 'pending', name: 'Driver 1', email: 'driver1@example.com' },
          { id: '2', status: 'approved', name: 'Driver 2', email: 'driver2@example.com' }
        ];
        mockDrivers.forEach(driver => fn({ id: driver.id, data: () => driver }));
      },
      size: 2
    });
    return jest.fn(); // unsubscribe function
  }),
  getDocs: jest.fn(() => Promise.resolve({
    empty: false,
    size: 2,
    docs: [
      { 
        id: '1', 
        data: () => ({ 
          fullName: 'User 1', 
          email: 'user1@example.com',
          phoneNumber: '1234567890',
          isActive: true 
        })
      },
      { 
        id: '2', 
        data: () => ({ 
          fullName: 'User 2', 
          email: 'user2@example.com',
          phoneNumber: '0987654321',
          isActive: true 
        })
      }
    ]
  })),
  doc: jest.fn(),
  updateDoc: jest.fn()
}));

// Mock useAuth hook
jest.mock('../contexts/AuthContext', () => ({
  useAuth: () => ({
    currentUser: { email: 'admin@example.com' },
    logout: jest.fn().mockImplementation(() => Promise.resolve())
  })
}));

// Mock useNavigate
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => jest.fn()
}));

describe('Dashboard Component', () => {
  test('renders dashboard with tabs', async () => {
    render(
      <BrowserRouter>
        <Dashboard />
      </BrowserRouter>
    );
    
    // Header elements
    expect(screen.getByText('Smart Ambulance')).toBeInTheDocument();
    expect(screen.getByText('Administrator')).toBeInTheDocument();
    expect(screen.getByText('admin@example.com')).toBeInTheDocument();
    
    // Tab buttons
    expect(screen.getByText(/Driver Management/i)).toBeInTheDocument();
    expect(screen.getByText(/Driver Tracking/i)).toBeInTheDocument();
    expect(screen.getByText(/User Management/i)).toBeInTheDocument();
  });
  
  test('switches tabs when clicked', () => {
    render(
      <BrowserRouter>
        <Dashboard />
      </BrowserRouter>
    );
    
    // Default tab is 'drivers'
    expect(screen.getByText('Driver Management')).toBeInTheDocument();
    
    // Click on driver tracking tab
    fireEvent.click(screen.getByText(/Driver Tracking/i));
    expect(screen.getByText('Live Ambulance Tracking')).toBeInTheDocument();
    
    // Click on user management tab
    fireEvent.click(screen.getByText(/User Management/i));
    expect(screen.getByText('User Management')).toBeInTheDocument();
  });
  
  test('displays driver statistics', () => {
    render(
      <BrowserRouter>
        <Dashboard />
      </BrowserRouter>
    );
    
    // Stats from mock data
    expect(screen.getByText('2')).toBeInTheDocument(); // Total
    expect(screen.getByText('1')).toBeInTheDocument(); // Pending
    expect(screen.getByText('1')).toBeInTheDocument(); // Approved
    
    // Driver entries
    expect(screen.getByText('Driver 1')).toBeInTheDocument();
    expect(screen.getByText('Driver 2')).toBeInTheDocument();
  });
}); 