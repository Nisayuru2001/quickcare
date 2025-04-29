import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();

    try {
      setError('');
      setLoading(true);
      await login(email, password);
      navigate('/dashboard');
    } catch (error) {
      setError('Failed to log in: ' + error.message);
    }

    setLoading(false);
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-[#0F172A] to-[#1E293B] relative overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden opacity-20">
        <div className="absolute w-96 h-96 bg-[#3B82F6] rounded-full -top-20 -left-20 blur-3xl animate-pulse"></div>
        <div className="absolute w-96 h-96 bg-[#0D9488] rounded-full bottom-0 right-0 blur-3xl animate-pulse" style={{animationDelay: '2s'}}></div>
        <div className="absolute w-64 h-64 bg-[#4F46E5] rounded-full top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 blur-3xl animate-pulse" style={{animationDelay: '4s'}}></div>
      </div>
      
      {/* Animated pattern grid */}
      <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxwYXRoIGQ9Ik0zNiAxOGMwLTkuOTQtOC4wNi0xOC0xOC0xOHY2YzYuNjI3IDAgMTIgNS4zNzMgMTIgMTJoNnptLTYgNmMwLTYuNjI3LTUuMzczLTEyLTEyLTEydjZjMy4zMTQgMCA2IDIuNjg2IDYgNmg2eiIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjA1KSIvPjwvZz48L3N2Zz4=')] opacity-10"></div>
      
      <div className="max-w-md w-full z-10">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gradient-to-tr from-[#0D9488] to-[#3B82F6] mb-4 shadow-lg">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-white" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M3 5a2 2 0 012-2h10a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2V5zm11 1H6v8l4-2 4 2V6z" clipRule="evenodd" />
            </svg>
          </div>
          <h1 className="text-4xl font-extrabold text-white mb-1 tracking-tight">Smart Ambulance</h1>
          <p className="text-[#94A3B8]">Admin Dashboard</p>
        </div>
        
        <div className="backdrop-blur-lg bg-white/10 rounded-2xl shadow-2xl overflow-hidden border border-white/20 p-8">
          <h2 className="text-2xl font-bold text-white mb-6 flex items-center">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" />
            </svg>
            Sign in
          </h2>
          
          {error && (
            <div className="bg-[#DC2626]/10 border-l-4 border-[#DC2626] text-white p-4 mb-6 rounded" role="alert">
              <p>{error}</p>
            </div>
          )}
          
          <form onSubmit={handleSubmit}>
            <div className="mb-6">
              <label className="block text-white text-sm font-medium mb-2" htmlFor="email">
                Email address
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-[#64748B]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
                  </svg>
                </div>
                <input
                  id="email"
                  type="email"
                  className="w-full pl-10 pr-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#3B82F6] focus:border-transparent text-white placeholder-[#94A3B8]"
                  placeholder="admin@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
            </div>
            
            <div className="mb-6">
              <div className="flex items-center justify-between mb-2">
                <label className="block text-white text-sm font-medium" htmlFor="password">
                  Password
                </label>
                <button 
                  type="button"
                  onClick={() => navigate('/reset-password')}
                  className="text-sm text-[#3B82F6] hover:text-[#60A5FA] focus:outline-none transition-colors"
                >
                  Forgot password?
                </button>
              </div>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-[#64748B]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <input
                  id="password"
                  type="password"
                  className="w-full pl-10 pr-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#3B82F6] focus:border-transparent text-white placeholder-[#94A3B8]"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
            </div>
            
            <div className="mb-4">
              <button
                type="submit"
                className="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-base font-medium text-white bg-gradient-to-r from-[#3B82F6] to-[#4F46E5] hover:from-[#60A5FA] hover:to-[#6366F1] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#3B82F6] transition-colors"
                disabled={loading}
              >
                {loading ? (
                  <span className="flex items-center">
                    <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Signing in...
                  </span>
                ) : (
                  'Sign in'
                )}
              </button>
            </div>
          </form>
          
          <div className="flex items-center justify-center mt-6">
            <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-white/5 mr-2">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3 text-[#3B82F6]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </span>
            <span className="text-sm text-[#94A3B8]">Secure, encrypted connection</span>
          </div>
        </div>
        
        <p className="text-center text-[#94A3B8] text-sm mt-8">
          &copy; {new Date().getFullYear()} Smart Ambulance. All rights reserved.
        </p>
      </div>
    </div>
  );
}

export default Login;