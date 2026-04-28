import axios from 'axios';

// Android emulator uses 10.0.2.2 to reach localhost on your PC
// Change to your real server IP/domain when deploying
const BASE_URL = __DEV__
  ? 'http://10.0.2.2:5001'
  : 'https://your-production-api.com';

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
});

export default client;