import React, { useEffect, useState } from 'react';
import { View, FlatList, ActivityIndicator, Text, StyleSheet, TextInput } from 'react-native';
import client from '../api/client';
import { theme } from '../theme';
import { Station } from '../types';

const StationsScreen = () => {
  const [stations, setStations] = useState<Station[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
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

    fetchInitialStations();
  }, []);

  const handleSearch = async (text: string) => {
    setSearchQuery(text);
    try {
      // Calls the search endpoint configured in your .NET backend
      const response = await client.get(`/api/stops/search?q=${text}`);
      setStations(response.data);
    } catch (error) {
      console.error("Search failed:", error);
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
          <View style={styles.stationCard}>
            <Text style={styles.stationName}>{item.name}</Text>
          </View>
        )}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.bg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: theme.colors.bg,
  },
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
  },
  stationName: {
    color: theme.colors.text,
    fontSize: 18,
    fontWeight: theme.font.semibold,
  },
});

export default StationsScreen;