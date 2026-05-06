import { Station, ActiveJourney } from '../types';

export const mockStations: Station[] = [
  {
    id: 'flagstaff',
    name: 'Flagstaff',
    lines: ['Belgrave', 'Lilydale', 'Glen Waverley', 'Alamein'],
    group: 'City Loop',
    departures: [
      { id: 'd1', time: '16:38', destination: 'Belgrave', platform: '3', line: 'Belgrave Line', cars: 6, minutesAway: -1 },
      { id: 'd2', time: '16:44', destination: 'Lilydale', platform: '1', line: 'Lilydale Line', cars: 3, minutesAway: 6 },
      { id: 'd3', time: '16:51', destination: 'Belgrave', platform: '3', line: 'Belgrave Line', cars: 6, minutesAway: 13 },
    ],
  },
  {
    id: 'flinders',
    name: 'Flinders Street',
    lines: ['Frankston', 'Cranbourne'],
    group: 'City Loop',
    departures: [
      { id: 'd4', time: '16:42', destination: 'Frankston', platform: '9', line: 'Frankston Line', cars: 6, minutesAway: 4 },
      { id: 'd5', time: '16:48', destination: 'Cranbourne', platform: '10', line: 'Cranbourne Line', cars: 6, minutesAway: 10 },
      { id: 'd6', time: '16:55', destination: 'Frankston', platform: '9', line: 'Frankston Line', cars: 6, minutesAway: 17 },
    ],
  },
];

export const mockJourney: ActiveJourney = {
  trainService: '16:32 Belgrave',
  line: 'Belgrave Line',
  departedStation: 'Flagstaff',
  departedMinutesAgo: 6,
  stops: [
    { name: 'Flagstaff', scheduledTime: '16:32', status: 'past' },
    { name: 'Melbourne Central', scheduledTime: '16:33', status: 'past' },
    { name: 'Flagstaff Loop Exit', scheduledTime: '16:34', status: 'past' },
    { name: 'Flinders Street', scheduledTime: '16:35', status: 'current' },
    { name: 'Richmond', scheduledTime: '16:37', status: 'upcoming' },
    { name: 'Burnley', scheduledTime: '16:40', status: 'upcoming' },
    { name: 'East Richmond', scheduledTime: '16:42', status: 'upcoming' },
  ],
  connections: [
    {
      id: 'c1',
      station: 'Flinders Street',
      service: '16:42 Frankston',
      platform: '9',
      status: 'will_make',
      marginMinutes: 5,
    },
    {
      id: 'c2',
      station: 'Richmond',
      service: '16:38 Glen Waverley',
      platform: '2',
      status: 'tight',
      marginMinutes: 1,
    },
    {
      id: 'c3',
      station: 'Burnley',
      service: '16:39 Alamein',
      platform: '1',
      status: 'will_miss',
      marginMinutes: 0,
      nextServiceTime: '16:54',
      nextServiceWaitMinutes: 15,
    },
  ],
};
