import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  Animated,
  ActivityIndicator
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useIsFocused } from '@react-navigation/native';
import { colors, spacing, radius, font } from '../theme';
import { Station, Departure } from '../types';
import client from '../api/client';

const DEVICE_ID = 'charlie-pixel-10';

// ── Departure row ────────────────────────────────────────────────────────────

function DepartureRow({ dep }: { dep: Departure }) {
  const blink = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (dep.minutesAway !== -1) return;
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(blink, { toValue: 0.4, duration: 700, useNativeDriver: true }),
        Animated.timing(blink, { toValue: 1, duration: 700, useNativeDriver: true }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [dep.minutesAway, blink]);

  const isNow = dep.minutesAway === -1;
  const isSoon = dep.minutesAway >= 0 && dep.minutesAway <= 8;

  const pillStyle = isNow
    ? styles.pillNow
    : isSoon
    ? styles.pillSoon
    : styles.pillOk;

  const pillText = isNow ? 'NOW' : `${dep.minutesAway} min`;

  return (
    <View style={styles.depRow}>
      <Text style={styles.depTime}>{dep.time}</Text>
      <View style={styles.depMid}>
        <View style={styles.depDestRow}>
          <Text style={styles.depDest}>{dep.destination}</Text>
          <View style={styles.platBadge}>
            <Text style={styles.platText}>PLT {dep.platform}</Text>
          </View>
        </View>
        <Text style={styles.depMeta}>
          {dep.line} · {dep.cars} cars
        </Text>
      </View>
      <Animated.View style={[styles.pill, pillStyle, isNow && { opacity: blink }]}>
        <Text style={[styles.pillText, isNow ? styles.pillTextNow : isSoon ? styles.pillTextSoon : styles.pillTextOk]}>
          {pillText}
        </Text>
      </Animated.View>
    </View>
  );
}

// ── Station widget ───────────────────────────────────────────────────────────

function StationWidget({ station }: { station: Station }) {
  const blink = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(blink, { toValue: 0.4, duration: 700, useNativeDriver: true }),
        Animated.timing(blink, { toValue: 1, duration: 700, useNativeDriver: true }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [blink]);

  return (
    <View style={styles.widget}>
      <View style={styles.liveBadge}>
        <Animated.View style={[styles.liveDot, { opacity: blink }]} />
        <Text style={styles.liveText}>LIVE</Text>
      </View>
      <Text style={styles.stationName}>{station.name}</Text>
      <Text style={styles.stationSub}>
        {station.group} · {station.lines.join(' / ')}
      </Text>
      {station.departures.map((dep, i) => (
        <DepartureRow key={dep.id} dep={dep} />
      ))}
    </View>
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

export default function DeparturesScreen() {
  const insets = useSafeAreaInsets();
  const isFocused = useIsFocused();
  const [stations, setStations] = useState<Station[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (isFocused) {
      loadLiveDepartures();
    }
  }, [isFocused]);

  const loadLiveDepartures = async () => {
    try {
      const response = await client.get(`/api/departures/favorites/${DEVICE_ID}`);
      
      // Adapt the C# backend data to match your TypeScript interfaces
      const mappedStations: Station[] = response.data.map((fav: any) => ({
        id: fav.stationId,
        name: fav.stationName,
        group: 'Metro Trains', 
        lines: Array.from(new Set(fav.departures.map((d: any) => d.line))), // Extract unique lines
        departures: fav.departures.map((dep: any, index: number) => {
          // Convert the backend UTC time to minutes away
          const msAway = new Date(dep.scheduledTime).getTime() - Date.now();
          const mins = Math.max(-1, Math.round(msAway / 60000));
          
          return {
            id: `${fav.stationId}-${index}`,
            minutesAway: mins,
            time: new Date(dep.scheduledTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            destination: dep.destination,
            platform: dep.platform || '1', // Fallback until backend provides it
            line: dep.line,
            cars: dep.cars || 6 // Fallback until backend provides it
          };
        })
      }));

      setStations(mappedStations);
    } catch (error) {
      console.error("Failed to fetch live departures:", error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={[styles.container, { justifyContent: 'center' }]}>
        <ActivityIndicator size="large" color={colors.orange} />
      </View>
    );
  }

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        <Text style={styles.screenLabel}>Melbourne Transit</Text>
        <Text style={styles.screenTitle}>Departures</Text>
        
        {stations.length === 0 ? (
          <Text style={{ color: colors.textSub, textAlign: 'center', marginTop: 40 }}>
            No favorite stations added yet. Head to the Stations tab to add some!
          </Text>
        ) : (
          stations.map(station => (
            <StationWidget key={station.id} station={station} />
          ))
        )}
      </ScrollView>
    </View>
  );
}

// ── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  scroll: { flex: 1 },
  scrollContent: { padding: spacing.lg, paddingBottom: 90 },

  screenLabel: {
    fontSize: 10,
    fontWeight: font.bold,
    color: colors.textSub,
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginTop: spacing.xl,
    marginBottom: spacing.sm,
  },
  screenTitle: {
    fontSize: 28,
    fontWeight: font.bold,
    color: colors.text,
    letterSpacing: -0.5,
    marginBottom: spacing.xl,
  },

  widget: {
    backgroundColor: colors.card,
    borderRadius: radius.xl,
    borderWidth: 0.5,
    borderColor: colors.border,
    padding: spacing.lg,
    marginBottom: spacing.md,
  },

  liveBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: 'rgba(239,159,39,0.1)',
    borderWidth: 0.5,
    borderColor: 'rgba(239,159,39,0.2)',
    borderRadius: radius.sm,
    paddingVertical: 3,
    paddingHorizontal: 8,
    alignSelf: 'flex-start',
    marginBottom: spacing.sm,
  },
  liveDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: colors.orange,
  },
  liveText: {
    fontSize: 10,
    fontWeight: font.bold,
    color: colors.orange,
    letterSpacing: 0.6,
  },

  stationName: {
    fontSize: 16,
    fontWeight: font.bold,
    color: colors.text,
    marginBottom: 2,
  },
  stationSub: {
    fontSize: 11,
    color: colors.textSub,
    marginBottom: spacing.md,
  },

  depRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 9,
    borderTopWidth: 0.5,
    borderTopColor: 'rgba(255,255,255,0.055)',
  },
  depTime: {
    fontFamily: 'monospace',
    fontSize: 20,
    fontWeight: font.bold,
    color: colors.orange,
    minWidth: 64,
    letterSpacing: -0.5,
  },
  depMid: { flex: 1, paddingHorizontal: 10 },
  depDestRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  depDest: { fontSize: 13, fontWeight: font.semibold, color: 'rgba(255,255,255,0.88)' },
  platBadge: {
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 4,
    paddingHorizontal: 5,
    paddingVertical: 2,
  },
  platText: { fontSize: 9, fontWeight: '800', color: 'rgba(255,255,255,0.45)' },
  depMeta: { fontSize: 11, color: colors.textSub, marginTop: 1 },

  pill: {
    paddingHorizontal: 9,
    paddingVertical: 3,
    borderRadius: 20,
  },
  pillNow: { backgroundColor: colors.greenBg },
  pillSoon: { backgroundColor: 'rgba(239,159,39,0.12)' },
  pillOk: { backgroundColor: 'rgba(255,255,255,0.06)' },
  pillText: { fontFamily: 'monospace', fontSize: 11, fontWeight: font.bold },
  pillTextNow: { color: colors.green },
  pillTextSoon: { color: colors.orange },
  pillTextOk: { color: 'rgba(255,255,255,0.4)' },
});