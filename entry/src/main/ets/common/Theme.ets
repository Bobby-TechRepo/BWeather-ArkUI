import { AqiLevel, UvLevel } from '../model/Models';

/** The Flutter app's Material 3 colour scheme (lib/utils/theme.dart), light and dark. */
export interface Palette {
  dark: boolean;
  primary: string;
  onPrimary: string;
  primaryContainer: string;
  secondary: string;
  secondaryContainer: string;
  onSecondaryContainer: string;
  tertiary: string;
  error: string;
  onError: string;
  surface: string;
  onSurface: string;
  onSurfaceVariant: string;
  outline: string;
  outlineVariant: string;
  surfaceLowest: string;
  surfaceLow: string;
  surfaceContainer: string;
  surfaceHigh: string;
  surfaceHighest: string;
  /** Selected tab / segment background (primary container at 25%). */
  indicator: string;
}

export const LIGHT: Palette = {
  dark: false,
  primary: '#00538A',
  onPrimary: '#FFFFFF',
  primaryContainer: '#2678BC',
  secondary: '#AD3306',
  secondaryContainer: '#FF825B',
  onSecondaryContainer: '#390A00',
  tertiary: '#526070',
  error: '#BA1A1A',
  onError: '#FFFFFF',
  surface: '#F8F9FF',
  onSurface: '#191C20',
  onSurfaceVariant: '#414750',
  outline: '#717881',
  outlineVariant: '#C0C7D2',
  surfaceLowest: '#FFFFFF',
  surfaceLow: '#F2F3FA',
  surfaceContainer: '#ECEEF4',
  surfaceHigh: '#E6E8EE',
  surfaceHighest: '#E0E2E8',
  indicator: '#402678BC'
};

export const DARK: Palette = {
  dark: true,
  primary: '#9CCAFF',
  onPrimary: '#003256',
  primaryContainer: '#2376BA',
  secondary: '#CB491E',
  secondaryContainer: '#F6683A',
  onSecondaryContainer: '#000000',
  tertiary: '#BAC8DB',
  error: '#F44336',
  onError: '#690005',
  surface: '#101418',
  onSurface: '#E0E2E8',
  onSurfaceVariant: '#C0C7D2',
  outline: '#8A919B',
  outlineVariant: '#414750',
  surfaceLowest: '#0B0E13',
  surfaceLow: '#191C20',
  surfaceContainer: '#1D2024',
  surfaceHigh: '#272A2F',
  surfaceHighest: '#32353A',
  indicator: '#402376BA'
};

export class Colors {
  /** "#RRGGBB" + opacity -> "#AARRGGBB" for ArkUI components. */
  static alpha(hex: string, opacity: number): string {
    const a = Math.round(Math.max(0, Math.min(1, opacity)) * 255).toString(16).toUpperCase();
    const rgb = hex.length === 9 ? hex.substring(3) : hex.substring(1);
    return `#${a.length === 1 ? '0' + a : a}${rgb}`;
  }

  /** "#RRGGBB" + opacity -> "rgba(r,g,b,a)" for canvas drawing. */
  static rgba(hex: string, opacity: number): string {
    const rgb = hex.length === 9 ? hex.substring(3) : hex.substring(1);
    const r = parseInt(rgb.substring(0, 2), 16);
    const g = parseInt(rgb.substring(2, 4), 16);
    const b = parseInt(rgb.substring(4, 6), 16);
    return `rgba(${r},${g},${b},${Math.max(0, Math.min(1, opacity))})`;
  }

  static aqi(level: AqiLevel): string {
    switch (level) {
      case AqiLevel.Good:
        return '#2E9E44';
      case AqiLevel.Moderate:
        return '#D9A400';
      case AqiLevel.Sensitive:
        return '#E8710A';
      case AqiLevel.Unhealthy:
        return '#D32F2F';
      case AqiLevel.VeryUnhealthy:
        return '#8E24AA';
      default:
        return '#7B1F1F';
    }
  }

  static uv(level: UvLevel): string {
    switch (level) {
      case UvLevel.Low:
        return '#2E9E44';
      case UvLevel.Moderate:
        return '#D9A400';
      case UvLevel.High:
        return '#E8710A';
      case UvLevel.VeryHigh:
        return '#D32F2F';
      default:
        return '#8E24AA';
    }
  }
}

/** Icon tile colours for the settings list, readable on light and dark surfaces. */
export class SettingsColors {
  static readonly BLUE: string = '#2F7BD8';
  static readonly INDIGO: string = '#5B5BD6';
  static readonly TEAL: string = '#14958A';
  static readonly GREEN: string = '#2E9D57';
  static readonly ORANGE: string = '#E07B1F';
  static readonly RED: string = '#D9443B';
  static readonly PINK: string = '#D14B8F';
  static readonly GREY: string = '#6B7684';
}
