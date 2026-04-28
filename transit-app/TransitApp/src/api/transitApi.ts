import axios from 'axios';
import { Station } from './types';

// Replace with your actual local IP address
const API_BASE_URL = 'http://192.168.0.242:5241/api'; 

export const fetchStops = async (): Promise<Station[]> => {
  try {
    const response = await axios.get(`${API_BASE_URL}/stops`);
    return response.data;
  } catch (error) {
    console.error("Failed to fetch stops:", error);
    throw error;
  }
};