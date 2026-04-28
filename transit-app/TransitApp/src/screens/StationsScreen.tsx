import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Switch,
} from 'react-native';
import { colors, spacing, radius, font } from '../theme';
import { Station } from '../types';
import { mockStations } from '../data/mockData';

// ── Train icon (SVG-free) ────────────────────────────────────────────────────

function TrainIcon() {
  return (
    <View style={styles.trainIconOuter}>
      <View style={styles.trainIconBody}>
        <View style={styles.trainIconWindows}>
          <View style={styles.trainIconWindow} />
          <View style={styles.trainIconWindow} />
        </View>
        <View style={styles.trainIconDivider} />
        <View style={styles.trainIconWheelRow}>
          <View style={styles.trainIconWheel} />
          <View style={styles.trainIconWheel} />
        </View>
      </View>
    </View>
  );
}

// ── Station item ─────────────────────────────────────────────────────────────

function StationItem({
  station,
  onRemove,
}: {
  station: Station;
  onRemove: (id: string) => void;
}) {
  return (
    <View style={styles.stationItem}>
      <View style={styles.stationIcon}>
        <TrainIcon />
      </View>
      <View style={styles.stationInfo}>
        <Text style={styles.stationName}>{station.name}</Text>
        <Text style={styles.stationLines}>
          {station.group} · {station.lines.join(', ')}
        </Text>
      </View>
      <TouchableOpacity
        style={styles.removeBtn}
        onPress={() => onRemove(station.id)}
        accessibilityLabel={`Remove ${station.name}`}>
        <Text style={styles.removeBtnText}>✕</Text>
      </TouchableOpacity>
    </View>
  );
}

// ── Toggle row ───────────────────────────────────────────────────────────────

function SettingToggle({
  label,
  sub,
  value,
  onChange,
}: {
  label: string;
  sub: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <View style={styles.settingCard}>
      <View style={styles.settingText}>
        <Text style={styles.settingLabel}>{label}</Text>
        <Text style={styles.settingSub}>{sub}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={onChange}
        trackColor={{ false: 'rgba(255,255,255,0.08)', true: colors.greenBg }}
        thumbColor={value ? colors.green : 'rgba(255,255,255,0.4)'}
      />
    </View>
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

export default function StationsScreen() {
  const [stations, setStations] = useState<Station[]>(mockStations);
  const [widgetEnabled, setWidgetEnabled] = useState(true);
  const [autoDetect, setAutoDetect] = useState(true);

  const removeStation = (id: string) => {
    setStations(prev => prev.filter(s => s.id !== id));
  };

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}>
        <Text style={styles.screenLabel}>My Places</Text>
        <Text style={styles.screenTitle}>Stations</Text>

        <Text style={styles.sectionLabel}>Saved stations</Text>
        {stations.map(station => (
          <StationItem
            key={station.id}
            station={station}
            onRemove={removeStation}
          />
        ))}

        <TouchableOpacity style={styles.addBtn} activeOpacity={0.7}>
          <Text style={styles.addBtnText}>+ Add station</Text>
        </TouchableOpacity>

        <Text style={[styles.sectionLabel, { marginTop: spacing.xl }]}>
          Widget settings
        </Text>
        <SettingToggle
          label="Show on home screen"
          sub="Android widget · 4×2 grid size"
          value={widgetEnabled}
          onChange={setWidgetEnabled}
        />
        <SettingToggle
          label="Auto-detect journey"
          sub="Uses GPS + timetable data"
          value={autoDetect}
          onChange={setAutoDetect}
        />
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
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.25)',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
  },

  stationItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.card,
    borderWidth: 0.5,
    borderColor: colors.border,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
    gap: spacing.md,
  },
  stationIcon: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: 'rgba(239,159,39,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  stationInfo: { flex: 1 },
  stationName: { fontSize: 15, fontWeight: font.bold, color: 'rgba(255,255,255,0.9)' },
  stationLines: { fontSize: 11, color: colors.textSub, marginTop: 2 },
  removeBtn: {
    width: 28,
    height: 28,
    backgroundColor: colors.redBg,
    borderWidth: 0.5,
    borderColor: colors.redBorder,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeBtnText: { color: colors.red, fontSize: 13 },

  // Minimal train icon using Views
  trainIconOuter: { alignItems: 'center', justifyContent: 'center' },
  trainIconBody: { width: 18, height: 16 },
  trainIconWindows: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 2,
  },
  trainIconWindow: {
    width: 5,
    height: 5,
    borderRadius: 1,
    borderWidth: 1.2,
    borderColor: colors.orange,
  },
  trainIconDivider: {
    height: 1,
    backgroundColor: colors.orange,
    marginBottom: 2,
    opacity: 0.5,
  },
  trainIconWheelRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  trainIconWheel: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.orange,
  },

  addBtn: {
    width: '100%',
    padding: spacing.lg,
    backgroundColor: colors.orangeBg,
    borderWidth: 0.5,
    borderColor: colors.orangeBorder,
    borderRadius: radius.md,
    alignItems: 'center',
    marginTop: 4,
  },
  addBtnText: {
    color: colors.orange,
    fontSize: 13,
    fontWeight: font.bold,
    letterSpacing: 0.2,
  },

  settingCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.card,
    borderWidth: 0.5,
    borderColor: colors.border,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  settingText: { flex: 1, marginRight: spacing.md },
  settingLabel: { fontSize: 14, fontWeight: font.semibold, color: 'rgba(255,255,255,0.85)' },
  settingSub: { fontSize: 11, color: colors.textSub, marginTop: 2 },
});
