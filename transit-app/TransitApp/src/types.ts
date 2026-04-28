export type ConnectionStatus = 'will_make' | 'tight' | 'will_miss';

export interface Departure {
  id: string;
  time: string;
  destination: string;
  platform: string;
  line: string;
  cars: number;
  minutesAway: number; // -1 = NOW
}

export interface Station {
  id: string;
  name: string;
  lines: string[];
  group: string;
  departures: Departure[];
}

export interface TrackStop {
  name: string;
  scheduledTime: string;
  status: 'past' | 'current' | 'upcoming';
}

export interface Connection {
  id: string;
  station: string;
  service: string;
  platform: string;
  status: ConnectionStatus;
  marginMinutes: number;
  nextServiceTime?: string;
  nextServiceWaitMinutes?: number;
}

export interface ActiveJourney {
  trainService: string;
  line: string;
  departedStation: string;
  departedMinutesAgo: number;
  stops: TrackStop[];
  connections: Connection[];
}
