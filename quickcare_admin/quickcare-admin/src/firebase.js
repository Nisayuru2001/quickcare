import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getAnalytics } from "firebase/analytics";

const firebaseConfig = {
  apiKey: "AIzaSyAhtwJ7yeM1fwwwRK-pK1UyOGqC8wFKd9M",
  authDomain: "quick-6d8a0.firebaseapp.com",
  projectId: "quick-6d8a0",
  storageBucket: "quick-6d8a0.firebasestorage.app",
  messagingSenderId: "116881192893",
  appId: "1:116881192893:web:ca5682e0859e99390b44d4",
  measurementId: "G-JPK2J2PW3Y"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const analytics = getAnalytics(app);

export { app, auth, db, analytics };