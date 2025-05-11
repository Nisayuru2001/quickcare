import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import PrivateRoute from './PrivateRoute';
import { MemoryRouter, Routes, Route } from 'react-router-dom';

// Mock useAuth with different authentication states
jest.mock('../contexts/AuthContext', () => ({
  useAuth: jest.fn()
}));

// Import actual module to control its mock implementation
import { useAuth } from '../contexts/AuthContext';

describe('PrivateRoute Component', () => {
  test('renders children when user is authenticated', () => {
    // Mock authenticated user
    useAuth.mockReturnValue({
      currentUser: { uid: '123', email: 'test@example.com' },
      loading: false
    });
    
    render(
      <MemoryRouter>
        <PrivateRoute>
          <div data-testid="protected-content">Protected Content</div>
        </PrivateRoute>
      </MemoryRouter>
    );
    
    expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    expect(screen.getByText('Protected Content')).toBeInTheDocument();
  });
  
  test('redirects to login when user is not authenticated', () => {
    // Mock unauthenticated user
    useAuth.mockReturnValue({
      currentUser: null,
      loading: false
    });
    
    render(
      <MemoryRouter initialEntries={['/dashboard']}>
        <Routes>
          <Route path="/login" element={<div data-testid="login-page">Login Page</div>} />
          <Route 
            path="/dashboard" 
            element={
              <PrivateRoute>
                <div>Protected Content</div>
              </PrivateRoute>
            } 
          />
        </Routes>
      </MemoryRouter>
    );
    
    // Should redirect to login
    expect(screen.getByTestId('login-page')).toBeInTheDocument();
    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument();
  });
  
  test('shows loading spinner when authentication state is loading', () => {
    // Mock loading state
    useAuth.mockReturnValue({
      currentUser: null,
      loading: true
    });
    
    render(
      <MemoryRouter>
        <PrivateRoute>
          <div>Protected Content</div>
        </PrivateRoute>
      </MemoryRouter>
    );
    
    // Should show loading indicator and not the protected content
    expect(screen.queryByText('Protected Content')).not.toBeInTheDocument();
    
    // Look for SVG element that represents the loading spinner
    const spinnerElement = document.querySelector('.animate-spin');
    expect(spinnerElement).toBeInTheDocument();
  });
}); 