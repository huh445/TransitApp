import client from './client';
import { Station } from '../types';

export interface Favorite {
  id?: number;
  userDeviceId: string;
  stationId: string;
  stationName: string;
  destinationStationId: string;
}

export const fetchStops = async (): Promise<Station[]> => {
  const response = await client.get('/api/stops');
  return response.data;
};

export const searchStops = async (query: string): Promise<Station[]> => {
  const response = await client.get(`/api/stops/search?q=${query}`);
  return response.data;
};

export const fetchFavoriteDepartures = async (deviceId: string) => {
  const response = await client.get(`/api/departures/favorites/${deviceId}`);
  return response.data;
};

// Database interactions for favorites
export const getFavorites = async (deviceId: string): Promise<Favorite[]> => {
  const response = await client.get(`/api/favorites/${deviceId}`);
  return response.data;
};

export const addFavorite = async (favorite: Favorite): Promise<Favorite> => {
  const response = await client.post('/api/favorites', favorite);
  return response.data;
};