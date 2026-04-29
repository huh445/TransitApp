import axios from 'axios';

// Bypass the local network entirely and use the working Railway backend
const PRODUCTION_URL = 'https://transitapp-production-8a77.up.railway.app';

const client = axios.create({
  baseURL: PRODUCTION_URL,
  timeout: 15000,
  headers: { 
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  },
});

export default client;