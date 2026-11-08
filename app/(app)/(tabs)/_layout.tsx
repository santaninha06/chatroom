import { Ionicons } from '@expo/vector-icons';
import { Tabs } from 'expo-router';
import type { ColorValue } from 'react-native';
import { colors } from '@/theme';
import type { IconName } from '@/utils/icons';

function tabIcon(name: IconName) {
  return ({
    color,
    size,
  }: {
    focused: boolean;
    color: ColorValue | null;
    size: number;
  }) => (
    <Ionicons
      name={name}
      size={size}
      color={typeof color === 'number' ? String(color) : (color ?? colors.muted)}
    />
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: 'Salas', tabBarIcon: tabIcon('chatbubbles') }}
      />
      <Tabs.Screen
        name="profile"
        options={{ title: 'Perfil', tabBarIcon: tabIcon('person') }}
      />
    </Tabs>
  );
}
