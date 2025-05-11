import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import Login from './Login';
import { AuthProvider } from '../contexts/AuthContext';
import { BrowserRouter } from 'react-router-dom';

// Mock useNavigate
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => jest.fn()
}));

// Mock useAuth hook
jest.mock('../contexts/AuthContext', () => ({
  useAuth: () => ({
    login: jest.fn().mockImplementation((email, password) => {
      if (email === 'test@example.com' && password === 'password123') {
        return Promise.resolve();
      } else {
        return Promise.reject({ message: 'Invalid credentials' });
      }
    })
  }),
  AuthProvider: ({ children }) => <div>{children}</div>
}));

describe('Login Component', () => {
  test('renders login form correctly', () => {
    render(
      <BrowserRouter>
        <Login />
      </BrowserRouter>
    );
    
    expect(screen.getByText(/Sign in/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Email address/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Sign in/i })).toBeInTheDocument();
    expect(screen.getByText(/Forgot password/i)).toBeInTheDocument();
  });

  test('shows error with incorrect credentials', async () => {
    render(
      <BrowserRouter>
        <Login />
      </BrowserRouter>
    );
    
    fireEvent.change(screen.getByLabelText(/Email address/i), {
      target: { value: 'wrong@example.com' }
    });
    
    fireEvent.change(screen.getByLabelText(/Password/i), {
      target: { value: 'wrongpassword' }
    });
    
    fireEvent.click(screen.getByRole('button', { name: /Sign in/i }));
    
    await waitFor(() => {
      expect(screen.getByText(/Failed to log in/i)).toBeInTheDocument();
    });
  });

  test('successful login attempt', async () => {
    render(
      <BrowserRouter>
        <Login />
      </BrowserRouter>
    );
    
    fireEvent.change(screen.getByLabelText(/Email address/i), {
      target: { value: 'test@example.com' }
    });
    
    fireEvent.change(screen.getByLabelText(/Password/i), {
      target: { value: 'password123' }
    });
    
    fireEvent.click(screen.getByRole('button', { name: /Sign in/i }));
    
    // Check loading state
    await waitFor(() => {
      expect(screen.queryByText(/Failed to log in/i)).not.toBeInTheDocument();
    });
  });
}); 