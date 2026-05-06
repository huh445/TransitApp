import React from 'react';
import { View, StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

// Screen Imports
import DeparturesScreen from './src/screens/DeparturesScreen';
import JourneyScreen from './src/screens/JourneyScreen';
import StationsList from './src/screens/StationsList';
import StationsScreen from './src/screens/StationsScreen';
import ServiceDetailScreen from './src/screens/ServiceDetailScreen';
import { colors } from './src/theme';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

// ── STACK NAVIGATORS ────────────────────────────────────────────────────────

function WidgetsStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="DeparturesMain" component={DeparturesScreen} />
      <Stack.Screen 
        name="ServiceDetail" 
        component={ServiceDetailScreen} 
        options={{ 
          headerShown: true, 
          headerTitle: 'Service Details',
          headerStyle: { backgroundColor: colors.bg },
          headerTintColor: colors.orange,
          headerTitleStyle: { fontWeight: 'bold' },
          headerBackTitleVisible: false
        }} 
      />
    </Stack.Navigator>
  );
}

function StationsStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="StationsMain" component={StationsList} />
      <Stack.Screen name="StationSearch" component={StationsScreen} />
    </Stack.Navigator>
  );
}

// ── CUSTOM ICONS ───────────────────────────────────────────────────────────

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

// ── MAIN APP ───────────────────────────────────────────────────────────────

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" backgroundColor={colors.bg} />
      <View style={{ flex: 1, backgroundColor: colors.bg }}>
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
              component={WidgetsStack}
              options={{ tabBarIcon: ({ color }) => <WidgetsIcon color={color} /> }}
            />

            <Tab.Screen
              name="Journey"
              component={JourneyScreen}
              options={{ tabBarIcon: ({ color }) => <JourneyIcon color={color} /> }}
            />

            <Tab.Screen
              name="StationsTab"
              component={StationsStack}
              options={{
                title: 'Stations',
                tabBarIcon: ({ color }) => <StationsIcon color={color} />,
              }}
            />
          </Tab.Navigator>
        </NavigationContainer>
      </View>
    </SafeAreaProvider>
  );
}