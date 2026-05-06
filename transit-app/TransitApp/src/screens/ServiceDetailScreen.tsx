import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, spacing, radius, font } from '../theme';
import client from '../api/client';

// ── Timeline Item Component ────────────────────────────────────────────────

function TimelineStop({ stop, isLast }: { stop: any, isLast: boolean }) {
  const isPassed = stop.status === 'passed';
  const isNow = stop.status === 'now';

  return (
    <View style={styles.stopRow}>
      <View style={styles.timelineLeft}>
        <Text style={[styles.stopTime, isPassed && styles.textDim]}>
          {stop.time.substring(0, 5)} {/* Clean HH:mm:ss to HH:mm */}
        </Text>
      </View>
      
      <View style={styles.timelineCenter}>
        <View style={[styles.dot, isNow && styles.dotNow, isPassed && styles.dotPassed]} />
        {!isLast && <View style={[styles.line, isPassed && styles.linePassed]} />}
      </View>

      <View style={styles.timelineRight}>
        <Text style={[styles.stopName, isNow && styles.textHighlight, isPassed && styles.textDim]}>
          {stop.name}
        </Text>
      </View>
    </View>
  );
}

// ── Main Screen ─────────────────────────────────────────────────────────────

export default function ServiceDetailScreen({ route }: any) {
  const insets = useSafeAreaInsets();
  const { tripId } = route.params; // Get the real ID from navigation
  
  const [stops, setStops] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStoppingPattern();
  }, [tripId]);

  const fetchStoppingPattern = async () => {
    try {
      const response = await client.get(`/api/trips/${tripId}/pattern`);
      
      // Determine status based on current time
      const now = new Date();
      const currentTimeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:00`;

      const mappedStops = response.data.map((s: any, index: number, arr: any[]) => {
        let status = 'upcoming';
        
        // Simple logic: if arrival time is before current time, it's passed
        // You can get fancier later with real-time positioning
        if (s.arrivalTime < currentTimeStr) {
          status = 'passed';
        } else if (index > 0 && arr[index - 1].arrivalTime < currentTimeStr) {
          status = 'now';
        }

        return {
          name: s.stationName,
          time: s.arrivalTime,
          status: status
        };
      });

      setStops(mappedStops);
    } catch (error) {
      console.error("Failed to fetch pattern:", error);
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
    <View style={[styles.container, { paddingBottom: insets.bottom }]}>
      {/* Header Section */}
      <View style={styles.header}>
        <Text style={styles.lineName}>Service Info</Text>
        <Text style={styles.destinationText}>
          {stops.length > 0 ? stops[stops.length - 1].name : 'Loading...'}
        </Text>
        
        <View style={styles.metaRow}>
          <View style={styles.metaPill}>
            <Text style={styles.metaPillText}>SCHEDULED</Text>
          </View>
          <Text style={styles.tripIdText}>ID: {tripId}</Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.sectionTitle}>Stopping Pattern</Text>
        {stops.length === 0 ? (
          <Text style={{ color: colors.textSub, textAlign: 'center' }}>No stops found for this trip.</Text>
        ) : (
          stops.map((stop, index) => (
            <TimelineStop 
              key={index} 
              stop={stop} 
              isLast={index === stops.length - 1} 
            />
          ))
        )}
      </ScrollView>
    </View>
  );
}

// ── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  header: {
    padding: spacing.lg,
    backgroundColor: colors.card,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    paddingTop: spacing.xl,
  },
  headerTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.xs },
  lineName: { color: colors.orange, fontWeight: font.bold, fontSize: 12, letterSpacing: 1, textTransform: 'uppercase' },
  expressBadge: { backgroundColor: colors.redBg, paddingHorizontal: 8, paddingVertical: 2, borderRadius: 4 },
  expressText: { color: colors.red, fontSize: 10, fontWeight: '900' },
  destinationText: { fontSize: 32, fontWeight: font.bold, color: colors.text, marginBottom: spacing.md },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  metaPill: { backgroundColor: 'rgba(255,255,255,0.1)', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 6 },
  metaPillText: { color: colors.text, fontSize: 11, fontWeight: font.bold },
  tripIdText: { color: colors.textSub, fontSize: 11, fontFamily: 'monospace' },

  scrollContent: { padding: spacing.lg },
  sectionTitle: { color: colors.textSub, fontSize: 12, fontWeight: font.bold, marginBottom: spacing.xl, textTransform: 'uppercase', letterSpacing: 1 },

  stopRow: { flexDirection: 'row', height: 70 },
  timelineLeft: { width: 70, alignItems: 'flex-end', paddingRight: spacing.md },
  stopTime: { color: colors.text, fontSize: 14, fontWeight: font.semibold },
  
  timelineCenter: { width: 20, alignItems: 'center' },
  dot: { width: 12, height: 12, borderRadius: 6, backgroundColor: colors.border, zIndex: 2, marginTop: 4 },
  dotNow: { backgroundColor: colors.orange, borderWidth: 3, borderColor: 'rgba(239,159,39,0.3)' },
  dotPassed: { backgroundColor: 'rgba(255,255,255,0.1)' },
  line: { position: 'absolute', top: 16, bottom: -4, width: 2, backgroundColor: colors.border, zIndex: 1 },
  linePassed: { backgroundColor: 'rgba(255,255,255,0.1)' },

  timelineRight: { flex: 1, paddingLeft: spacing.md },
  stopName: { fontSize: 16, fontWeight: font.semibold, color: colors.text },
  textHighlight: { color: colors.orange },
  textDim: { color: 'rgba(255,255,255,0.2)' },
});