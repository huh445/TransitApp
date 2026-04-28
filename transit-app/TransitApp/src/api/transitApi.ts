import client from './client';
import { Station, ActiveJourney } from '../types';

export const transitApi = {
  getDepartures: (stationIds: string[]) =>
    client.get<Station[]>('/api/departures', {
      params: { stations: stationIds.join(',') },
    }),

  getJourney: (lat: number, lng: number) =>
    client.get<ActiveJourney>('/api/journey', {
      params: { lat, lng },
    }),

  getStations: () =>
    client.get<Station[]>('/api/stations'),
};