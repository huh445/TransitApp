import React, { useEffect, useRef } from 'react';
import { View, Text, ScrollView, StyleSheet, Animated } from 'react-native';
import { colors, spacing, radius, font } from '../theme';
import { Connection, TrackStop, ConnectionStatus } from '../types';
import { mockJourney } from '../data/mockData';

// ── Connection card ──────────────────────────────────────────────────────────

const connectionConfig: Record<ConnectionStatus, { label: string; bg: string; text: string }> = {
  will_make: { label: 'Will make', bg: colors.greenBg, text: colors.green },
  tight:     { label: 'Tight',     bg: 'rgba(239,159,39,0.12)', text: colors.orange },
  will_miss: { label: 'Will miss', bg: colors.redBg, text: colors.red },
};

function ConnectionCard({ conn }: { conn: Connection }) {
  const cfg = connectionConfig[conn.status];
  return (
    <View style={[styles.connCard, conn.status === 'will_make' && styles.connCardGreen]}>
      <View style={styles.connHeader}>
        <Text style={styles.connStation}>{conn.station}</Text>
        <View style={[styles.connBadge, { backgroundColor: cfg.bg }]}>
          <Text style={[styles.connBadgeText, { color: cfg.text }]}>{cfg.label}</Text>
        </View>
      </View>
      <Text style={styles.connService}>
        {conn.service} · Platform {conn.platform}
      </Text>
      {conn.status === 'will_miss' ? (
        <Text style={styles.connMeta}>
          Next service: {conn.nextServiceTime} · {conn.nextServiceWaitMinutes} min wait
        </Text>
      ) : (
        <Text style={styles.connMeta}>
          {conn.marginMinutes} min margin
        </Text>
      )}
    </View>
  );
}

// ── Track stop row ───────────────────────────────────────────────────────────

function TrackStopRow({ stop, isLast }: { stop: TrackStop; isLast: boolean }) {
  const isPast = stop.status === 'past';
  const isCurrent = stop.status === 'current';

  return (
    <View style={styles.stopRow}>
      <View style={styles.stopLineCol}>
        <View style={[
          styles.stopDot,
          isPast && styles.stopDotPast,
          isCurrent && styles.stopDotCurrent,
        ]} />
        {!isLast && <View style={[styles.stopLine, isPast && styles.stopLinePast]} />}
      </View>
      <View style={styles.stopInfo}>
        <Text style={[
          styles.stopName,
          isPast && styles.stopNamePast,
          isCurrent && styles.stopNameCurrent,
        ]}>
          {stop.name}
        </Text>
      </View>
      <Text style={styles.stopTime}>{stop.scheduledTime}</Text>
    </View>
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

export default function JourneyScreen() {
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

  const journey = mockJourney;

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        <Text style={styles.screenLabel}>Live Tracking</Text>
        <Text style={styles.screenTitle}>On journey</Text>

        {/* Journey card */}
        <View style={styles.journeyCard}>
          <View style={styles.gpsRow}>
            <Animated.View style={[styles.gpsDot, { opacity: blink }]} />
            <Text style={styles.gpsText}>GPS LOCK · TRACKING ACTIVE</Text>
          </View>
          <Text style={styles.trainService}>{journey.trainService}</Text>
          <Text style={styles.trainSub}>
            {journey.line} · Departed {journey.departedStation}{' '}
            {journey.departedMinutesAgo} min ago
          </Text>

          {/* Track */}
          <View style={styles.track}>
            {journey.stops.map((stop, i) => (
              <TrackStopRow
                key={stop.name}
                stop={stop}
                isLast={i === journey.stops.length - 1}
              />
            ))}
          </View>
        </View>

        {/* Connections */}
        <Text style={styles.sectionLabel}>Connection predictions</Text>
        {journey.connections.map(conn => (
          <ConnectionCard key={conn.id} conn={conn} />
        ))}
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

  journeyCard: {
    backgroundColor: colors.card,
    borderWidth: 0.5,
    borderColor: colors.borderGreen,
    borderRadius: radius.xl,
    padding: spacing.lg,
    marginBottom: spacing.md,
  },

  gpsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    marginBottom: spacing.md,
  },
  gpsDot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: colors.green,
  },
  gpsText: {
    fontSize: 10,
    fontWeight: '800',
    color: colors.green,
    letterSpacing: 0.8,
  },

  trainService: {
    fontSize: 22,
    fontWeight: '800',
    color: colors.text,
    letterSpacing: -0.4,
    marginBottom: 3,
  },
  trainSub: {
    fontSize: 12,
    color: colors.textSub,
    marginBottom: spacing.lg,
  },

  track: { paddingTop: 4 },

  stopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    minHeight: 36,
  },
  stopLineCol: {
    width: 24,
    alignItems: 'center',
    marginRight: spacing.md,
  },
  stopDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 1.5,
    borderColor: 'rgba(255,255,255,0.15)',
    marginTop: 4,
    zIndex: 1,
  },
  stopDotPast: {
    backgroundColor: colors.green,
    borderColor: colors.green,
  },
  stopDotCurrent: {
    backgroundColor: colors.orange,
    borderColor: colors.orange,
  },
  stopLine: {
    width: 2,
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
    marginTop: 2,
  },
  stopLinePast: {
    backgroundColor: colors.green,
  },
  stopInfo: { flex: 1, paddingTop: 2 },
  stopName: { fontSize: 13, color: colors.textSub, paddingBottom: 12 },
  stopNamePast: { color: colors.textMid },
  stopNameCurrent: { color: colors.text, fontWeight: font.bold },
  stopTime: {
    fontFamily: 'monospace',
    fontSize: 11,
    color: colors.textSub,
    paddingTop: 2,
  },

  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.25)',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
    marginTop: spacing.sm,
  },

  connCard: {
    backgroundColor: colors.card,
    borderWidth: 0.5,
    borderColor: colors.border,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  connCardGreen: {
    borderColor: 'rgba(99,153,34,0.2)',
  },
  connHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  connStation: { fontSize: 11, color: colors.textSub, fontWeight: font.semibold },
  connBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 20,
  },
  connBadgeText: { fontSize: 10, fontWeight: '800', letterSpacing: 0.3 },
  connService: {
    fontSize: 15,
    fontWeight: font.bold,
    color: 'rgba(255,255,255,0.9)',
  },
  connMeta: { fontSize: 11, color: colors.textSub, marginTop: 3 },
});
