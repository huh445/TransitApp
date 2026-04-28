export const colors = {
  bg: '#0c0c12',
  card: '#131320',
  border: 'rgba(255,255,255,0.07)',
  borderGreen: 'rgba(99,153,34,0.25)',
  text: 'rgba(255,255,255,0.95)',
  textSub: 'rgba(255,255,255,0.38)',
  textMid: 'rgba(255,255,255,0.65)',
  orange: '#EF9F27',
  orangeBg: 'rgba(239,159,39,0.08)',
  orangeBorder: 'rgba(239,159,39,0.2)',
  green: '#97C459',
  greenBg: 'rgba(99,153,34,0.15)',
  red: '#E24B4A',
  redBg: 'rgba(226,75,74,0.1)',
  redBorder: 'rgba(226,75,74,0.2)',
  tabBar: 'rgba(10,10,18,0.97)',
  tabBorder: 'rgba(255,255,255,0.08)',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
};

export const radius = {
  sm: 6,
  md: 10,
  lg: 14,
  xl: 18,
};

export const font = {
  bold: '700' as const,
  semibold: '600' as const,
  regular: '400' as const,
};

// Export the unified theme object to prevent undefined errors in your screens
export const theme = {
  colors,
  spacing,
  radius,
  font,
};