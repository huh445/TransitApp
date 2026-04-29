import React, { useEffect, useState } from 'react';
import { View, FlatList, ActivityIndicator, Text, StyleSheet, TextInput, TouchableOpacity, Alert } from 'react-native';
import client from '../api/client';
import { theme } from '../theme';
import { Station } from '../types';
import { useNavigation } from '@react-navigation/native';

const StationsScreen = () => {
  const navigation = useNavigation();
  const [stations, setStations] = useState<Station[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    fetchInitialStations();
  }, []);

  const fetchInitialStations = async () => {
    try {
      const response = await client.get('/api/stops');
      setStations(response.data);
    } catch (error) {
      console.error("Failed to fetch stops:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (text: string) => {
    setSearchQuery(text);
    try {
      const response = await client.get(`/api/stops/search?q=${text}`);
      setStations(response.data);
    } catch (error) {
      console.error("Search failed:", error);
    }
  };

  const saveAsFavorite = async (station: Station) => {
    try {
      await client.post('/api/favorites', {
        userDeviceId: 'charlie-pixel-10', // Consistent ID
        stationId: station.id,
        stationName: station.name,
        destinationStationId: "none" // You can implement destination selection later
      });
      Alert.alert("Success", `${station.name} added to favorites!`);
      navigation.goBack(); // Return to main screen to see the update
    } catch (error) {
      console.error("Save failed:", error);
      Alert.alert("Error", "Could not save favorite.");
    }
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={theme.colors.orange} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <TextInput
        placeholder="Search stations..."
        placeholderTextColor={theme.colors.textSub}
        value={searchQuery}
        onChangeText={handleSearch}
        style={styles.searchInput}
      />
      <FlatList
        data={stations}
        keyExtractor={(item) => item.id.toString()}
        renderItem={({ item }) => (
          <TouchableOpacity 
            style={styles.stationCard} 
            onPress={() => saveAsFavorite(item)}
          >
            <Text style={styles.stationName}>{item.name}</Text>
            <Text style={{color: theme.colors.orange, fontSize: 12}}>Tap to save</Text>
          </TouchableOpacity>
        )}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: theme.colors.bg },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: theme.colors.bg },
  searchInput: {
    backgroundColor: theme.colors.card,
    color: theme.colors.text,
    padding: theme.spacing.md,
    margin: theme.spacing.md,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    borderColor: theme.colors.border,
    fontSize: 16,
  },
  stationCard: {
    padding: theme.spacing.lg,
    marginHorizontal: theme.spacing.md,
    marginBottom: theme.spacing.sm,
    backgroundColor: theme.colors.card,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    borderColor: theme.colors.border,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  stationName: { color: theme.colors.text, fontSize: 18, fontWeight: theme.font.semibold },
});

export default StationsScreen;