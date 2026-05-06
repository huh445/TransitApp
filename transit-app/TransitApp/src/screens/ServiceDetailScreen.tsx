import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, spacing, radius, font } from '../theme';

// ── Mock Data for Testing ──────────────────────────────────────────────────
const MOCK_SERVICE = {
  tripId: "742.T2.2-PKM-mjp-1.1.H",
  destination: "Frankston",
  line: "Frankston",
  cars: 7,
  isExpress: false,
  stops: [
    { name: "Pakenham Station", time: "1:45 PM", status: "passed" },
    { name: "Berwick Station", time: "1:58 PM", status: "passed" },
    { name: "Dandenong Station", time: "2:12 PM", status: "now" },
    { name: "Clayton Station", time: "2:25 PM", status: "next" },
    { name: "Caulfield Station", time: "2:38 PM", status: "upcoming" },
    { name: "Richmond Station", time: "2:48 PM", status: "upcoming" },
    { name: "Flinders Street Station", time: "2:55 PM", status: "upcoming" },
  ]
};

// ── Timeline Item Component ────────────────────────────────────────────────

function TimelineStop({ stop, isLast }: { stop: any, isLast: boolean }) {
  const isPassed = stop.status === 'passed';
  const isNow = stop.status === 'now';

  return (
    <View style={styles.stopRow}>
      <View style={styles.timelineLeft}>
        <Text style={[styles.stopTime, isPassed && styles.textDim]}>{stop.time}</Text>
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
  // In the real app, you'll use route.params.tripId to fetch data
  const { tripId } = route.params.tripId || { tripId: MOCK_SERVICE.tripId };

  return (
    <View style={[styles.container, { paddingBottom: insets.bottom }]}>
      {/* Header Section: Trip Metadata */}
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <Text style={styles.lineName}>{MOCK_SERVICE.line} Line</Text>
          {MOCK_SERVICE.isExpress && (
            <View style={styles.expressBadge}>
              <Text style={styles.expressText}>LIMITED EXPRESS</Text>
            </View>
          )}
        </View>
        
        <Text style={styles.destinationText}>{MOCK_SERVICE.destination}</Text>
        
        <View style={styles.metaRow}>
          <View style={styles.metaPill}>
            <Text style={styles.metaPillText}>{MOCK_SERVICE.cars} CARS</Text>
          </View>
          <Text style={styles.tripIdText}>ID: {tripId}</Text>
        </View>
      </View>

      {/* Timeline Section */}
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.sectionTitle}>Stopping Pattern</Text>
        {MOCK_SERVICE.stops.map((stop, index) => (
          <TimelineStop 
            key={index} 
            stop={stop} 
            isLast={index === MOCK_SERVICE.stops.length - 1} 
          />
        ))}
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