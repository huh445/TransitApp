import React from 'react';
import { View, StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// Ensure these imports match your file names exactly
import DeparturesScreen from './src/screens/DeparturesScreen';
import JourneyScreen from './src/screens/JourneyScreen';
import StationsList from './src/screens/StationsList';   // Your Favorites List
import StationsScreen from './src/screens/StationsScreen'; // Your Search Screen
import { colors } from './src/theme';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

// ── Stack Navigator (CRITICAL: Added 'return') ──────────────────────────
function StationsStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {/* This name is what the Tab shows by default */}
      <Stack.Screen name="StationsMain" component={StationsList} />
      {/* This name MUST match your navigation.navigate('StationSearch') call */}
      <Stack.Screen name="StationSearch" component={StationsScreen} />
    </Stack.Navigator>
  );
}

// --- Icons ----------------------------------------------------------------
function WidgetsIcon({ color }: { color: string }) {
  const s = { width: 5, height: 5, borderRadius: 1, borderWidth: 1.5, borderColor: color };
  return (
    <View style={{ width: 22, height: 22, flexDirection: 'row', flexWrap: 'wrap', gap: 2, alignContent: 'space-between', justifyContent: 'space-between', padding: 2 }}>
      <View style={s} /><View style={s} /><View style={s} /><View style={s} />
    </View>
  );
}

function JourneyIcon({ color }: { color: string }) {
  return (
    <View style={{ width: 22, height: 22, alignItems: 'center', justifyContent: 'center' }}>
      <View style={{ width: 18, height: 18, borderRadius: 9, borderWidth: 1.6, borderColor: color, alignItems: 'center', justifyContent: 'center' }}>
        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: color }} />
      </View>
    </View>
  );
}

function StationsIcon({ color }: { color: string }) {
  return (
    <View style={{ width: 22, height: 22, alignItems: 'center', justifyContent: 'center' }}>
      <View style={{ width: 0, height: 0, borderLeftWidth: 6, borderRightWidth: 6, borderBottomWidth: 10, borderLeftColor: 'transparent', borderRightColor: 'transparent', borderBottomColor: color }} />
      <View style={{ width: 10, height: 8, borderWidth: 1.6, borderColor: color, borderTopWidth: 0, marginTop: -1 }} />
    </View>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" backgroundColor={colors.bg} />
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={{
            headerShown: false,
            tabBarStyle: {
              backgroundColor: colors.tabBar,
              borderTopColor: colors.tabBorder,
              borderTopWidth: 0.5,
              height: 68,
              paddingBottom: 10,
            },
            tabBarActiveTintColor: colors.orange,
            tabBarInactiveTintColor: 'rgba(255,255,255,0.28)',
          }}>
          <Tab.Screen
            name="Widgets"
            component={DeparturesScreen}
            options={{ tabBarIcon: ({ color }) => <WidgetsIcon color={color} /> }}
          />
          <Tab.Screen
            name="Journey"
            component={JourneyScreen}
            options={{ tabBarIcon: ({ color }) => <JourneyIcon color={color} /> }}
          />
          <Tab.Screen
            name="StationsTab" // Unique name for the Tab itself
            component={StationsStack} // Points to our function above
            options={{
              title: 'Stations',
              tabBarIcon: ({ color }) => <StationsIcon color={color} />,
            }}
          />
        </Tab.Navigator>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}