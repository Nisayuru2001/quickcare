import React, { useState, useEffect } from 'react';
import { collection, getDocs, addDoc } from "firebase/firestore";
import { createUserWithEmailAndPassword, signInWithEmailAndPassword } from "firebase/auth";
import { db, auth } from '../firebase';

function AdminSetup() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const [adminsExist, setAdminsExist] = useState(false);
  const [checking, setChecking] = useState(true);

  // Check if any admins exist already
  useEffect(() => {
    async function checkAdmins() {
      try {
        const adminsRef = collection(db, "admins");
        const snapshot = await getDocs(adminsRef);
        setAdminsExist(!snapshot.empty);
        setChecking(false);
      } catch (error) {
        console.error("Error checking admins:", error);
        setError("Error checking if admins exist: " + error.message);
        setChecking(false);
      }
    }

    checkAdmins();
  }, []);

  async function createDefaultAdmin(email, password) {
    try {
      // Check if admin collection exists and has any documents
      const adminsRef = collection(db, "admins");
      const adminQuery = adminsRef;
      const querySnapshot = await getDocs(adminQuery);
      
      if (!querySnapshot.empty) {
        console.log("Admin users already exist in the database.");
        return {
          success: false,
          message: "Admin users already exist in the database."
        };
      }
      
      try {
        // Create the user in Firebase Auth
        const userCredential = await createUserWithEmailAndPassword(auth, email, password);
        const user = userCredential.user;
        
        // Add the user to the admins collection
        await addDoc(collection(db, "admins"), {
          email: email,
          uid: user.uid,
          createdAt: new Date()
        });
        
        return {
          success: true,
          message: "Default admin created successfully!",
          uid: user.uid
        };
      } catch (error) {
        // If the user already exists, try to sign in and then add them to admins collection
        if (error.code === 'auth/email-already-in-use') {
          try {
            // Sign in with the provided credentials
            const userCredential = await signInWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;
            
            // Add the user to the admins collection (we already checked it's empty)
            await addDoc(collection(db, "admins"), {
              email: email,
              uid: user.uid,
              createdAt: new Date()
            });
            
            return {
              success: true,
              message: "User already existed and was added as admin.",
              uid: user.uid
            };
          } catch (signInError) {
            return {
              success: false,
              message: "Error signing in with existing user: " + signInError.message,
              error: signInError
            };
          }
        }
        
        return {
          success: false,
          message: "Error creating admin: " + error.message,
          error: error
        };
      }
    } catch (error) {
      return {
        success: false,
        message: "Error checking admin collection: " + error.message,
        error: error
      };
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    
    if (password !== confirmPassword) {
      setError("Passwords don't match");
      return;
    }

    if (password.length < 6) {
      setError("Password must be at least 6 characters");
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const result = await createDefaultAdmin(email, password);
      
      if (result.success) {
        setSuccess(result.message + " Please refresh the page and log in.");
        setAdminsExist(true);
      } else {
        setError(result.message);
      }
    } catch (error) {
      setError("Error creating admin: " + error.message);
    }

    setLoading(false);
  }

  if (checking) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="bg-white p-8 rounded shadow-md w-96 text-center">
          <p>Checking admin status...</p>
        </div>
      </div>
    );
  }

  if (adminsExist) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="bg-white p-8 rounded shadow-md w-96 text-center">
          <h2 className="text-2xl font-bold mb-6">Admin Already Exists</h2>
          <p className="mb-4">An admin user has already been set up for this application.</p>
          {success && <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">{success}</div>}
          <a href="/login" className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded inline-block">Go to Login</a>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <div className="bg-white p-8 rounded shadow-md w-96">
        <h2 className="text-2xl font-bold mb-6 text-center">Initial Admin Setup</h2>
        <p className="mb-4 text-gray-600">Create your first admin account to manage the Smart Ambulance system.</p>
        
        {error && <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">{error}</div>}
        {success && <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">{success}</div>}
        
        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="email">
              Admin Email
            </label>
            <input
              id="email"
              type="email"
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          
          <div className="mb-6">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="confirm-password">
              Confirm Password
            </label>
            <input
              id="confirm-password"
              type="password"
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
            />
          </div>
          
          <div className="flex items-center justify-center">
            <button
              type="submit"
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline w-full"
              disabled={loading}
            >
              {loading ? 'Creating Admin...' : 'Create Admin Account'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default AdminSetup;