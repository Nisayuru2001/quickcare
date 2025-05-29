
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyAhtwJ7yeM1fwwwRK-pK1UyOGqC8wFKd9M",
  authDomain: "quick-6d8a0.firebaseapp.com",
  projectId: "quick-6d8a0",
  storageBucket: "quick-6d8a0.firebasestorage.app",
  messagingSenderId: "116881192893",
  appId: "1:116881192893:web:ca5682e0859e99390b44d4",
  measurementId: "G-JPK2J2PW3Y"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
export default app;
