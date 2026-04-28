import axios from 'axios';

// Charlie, use the exact IP you verified in Chrome
const BASE_URL = __DEV__
  ? 'http://192.168.0.242:5241'
  : 'https://your-production-api.com';

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 15000, // Increased timeout for Wi-Fi latency
  headers: { 
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  },
});

export default client;