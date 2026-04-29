import axios from 'axios';

// Charlie, replace the URL below with your actual Railway URL
const PRODUCTION_URL = 'https://transitapp-production-8a77.up.railway.app';

const BASE_URL = __DEV__
  ? 'http://10.0.2.2:5241' // This stays for emulator/local testing
  : PRODUCTION_URL;

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 15000,
  headers: { 
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  },
});

export default client;