import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, Switch, ActivityIndicator } from 'react-native';
import { colors, spacing, radius, font, theme } from '../theme';
import client from '../api/client';
import { useNavigation, useIsFocused } from '@react-navigation/native';
import StationsScreen from './StationsScreen.tsx';

const DEVICE_ID = 'charlie-pixel-10';

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

function SettingToggle({ label, sub, value, onChange }: any) {
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

export default function StationsList() {
  const navigation = useNavigation<any>();
  const isFocused = useIsFocused(); // To refresh data when coming back from search
  const [favorites, setFavorites] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [widgetEnabled, setWidgetEnabled] = useState(true);
  const [autoDetect, setAutoDetect] = useState(true);

  useEffect(() => {
    if (isFocused) {
      fetchFavorites();
    }
  }, [isFocused]);

  const fetchFavorites = async () => {
    try {
      const response = await client.get(`/api/favorites/${DEVICE_ID}`);
      setFavorites(response.data);
    } catch (error) {
      console.error("Load failed", error);
    } finally {
      setLoading(false);
    }
  };

  const removeFavorite = async (id: number) => {
    try {
      await client.delete(`/api/favorites/${id}`);
      setFavorites(prev => prev.filter(f => f.id !== id));
    } catch (error) {
      console.error("Delete failed", error);
    }
  };

  if (loading) {
    return (
      <View style={[styles.container, {justifyContent: 'center'}]}>
        <ActivityIndicator size="large" color={colors.orange} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
        <Text style={styles.screenLabel}>My Places</Text>
        <Text style={styles.screenTitle}>Stations</Text>

        <Text style={styles.sectionLabel}>Saved stations</Text>
        {favorites.map(fav => (
          <View key={fav.id} style={styles.stationItem}>
            <View style={styles.stationIcon}><TrainIcon /></View>
            <View style={styles.stationInfo}>
              <Text style={styles.stationName}>{fav.stationName}</Text>
              <Text style={styles.stationLines}>Station ID: {fav.stationId}</Text>
            </View>
            <TouchableOpacity style={styles.removeBtn} onPress={() => removeFavorite(fav.id)}>
              <Text style={styles.removeBtnText}>✕</Text>
            </TouchableOpacity>
          </View>
        ))}


        {/* Navigate to StationsScreen.tsx */}
        <TouchableOpacity 
          style={styles.addBtn} 
          onPress={() => navigation.navigate('StationSearch')} // Matches Stack.Screen name
        >
          <Text style={styles.addBtnText}>+ Add station</Text>
        </TouchableOpacity>

        <Text style={[styles.sectionLabel, { marginTop: spacing.xl }]}>Widget settings</Text>
        <SettingToggle label="Show on home screen" sub="Android widget · 4×2 grid size" value={widgetEnabled} onChange={setWidgetEnabled} />
        <SettingToggle label="Auto-detect journey" sub="Uses GPS + timetable data" value={autoDetect} onChange={setAutoDetect} />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  scroll: { flex: 1 },
  scrollContent: { padding: spacing.lg, paddingBottom: 90 },
  screenLabel: { fontSize: 10, fontWeight: font.bold, color: colors.textSub, letterSpacing: 1, textTransform: 'uppercase', marginTop: spacing.xl, marginBottom: spacing.sm },
  screenTitle: { fontSize: 28, fontWeight: font.bold, color: colors.text, letterSpacing: -0.5, marginBottom: spacing.xl },
  sectionLabel: { fontSize: 10, fontWeight: '700', color: 'rgba(255,255,255,0.25)', letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: spacing.sm },
  stationItem: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderWidth: 0.5, borderColor: colors.border, borderRadius: radius.lg, padding: spacing.md, marginBottom: spacing.sm, gap: spacing.md },
  stationIcon: { width: 36, height: 36, borderRadius: 10, backgroundColor: 'rgba(239,159,39,0.1)', alignItems: 'center', justifyContent: 'center' },
  stationInfo: { flex: 1 },
  stationName: { fontSize: 15, fontWeight: font.bold, color: 'rgba(255,255,255,0.9)' },
  stationLines: { fontSize: 11, color: colors.textSub, marginTop: 2 },
  removeBtn: { width: 28, height: 28, backgroundColor: colors.redBg, borderWidth: 0.5, borderColor: colors.redBorder, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  removeBtnText: { color: colors.red, fontSize: 13 },
  trainIconOuter: { alignItems: 'center', justifyContent: 'center' },
  trainIconBody: { width: 18, height: 16 },
  trainIconWindows: { flexDirection: 'row', justifyContent: 'space-around', marginBottom: 2 },
  trainIconWindow: { width: 5, height: 5, borderRadius: 1, borderWidth: 1.2, borderColor: colors.orange },
  trainIconDivider: { height: 1, backgroundColor: colors.orange, marginBottom: 2, opacity: 0.5 },
  trainIconWheelRow: { flexDirection: 'row', justifyContent: 'space-around' },
  trainIconWheel: { width: 4, height: 4, borderRadius: 2, backgroundColor: colors.orange },
  addBtn: { width: '100%', padding: spacing.lg, backgroundColor: colors.orangeBg, borderWidth: 0.5, borderColor: colors.orangeBorder, borderRadius: radius.md, alignItems: 'center', marginTop: 4 },
  addBtnText: { color: colors.orange, fontSize: 13, fontWeight: font.bold, letterSpacing: 0.2 },
  settingCard: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: colors.card, borderWidth: 0.5, borderColor: colors.border, borderRadius: radius.lg, padding: spacing.md, marginBottom: spacing.sm },
  settingText: { flex: 1, marginRight: spacing.md },
  settingLabel: { fontSize: 14, fontWeight: font.semibold, color: 'rgba(255,255,255,0.85)' },
  settingSub: { fontSize: 11, color: colors.textSub, marginTop: 2 },
});

export default StationsList;