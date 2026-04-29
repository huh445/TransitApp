import axios from 'axios';

// Charlie, this is your new live backend URL
const PRODUCTION_URL = 'https://transitapp-production-8a77.up.railway.app';

const BASE_URL = __DEV__
  ? 'http://192.168.0.242:5241' // Use your Mac's IP for local testing
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