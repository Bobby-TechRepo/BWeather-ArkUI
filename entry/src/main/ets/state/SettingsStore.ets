import { ConfigurationConstant, Want } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { Format, SUPPORTED_LANGUAGES } from '../common/Format';
import { Storage } from '../common/Storage';
import { PrecipitationUnit, TempUnit, WindSpeedUnit } from '../common/Units';
import { AlertPrefs, AlertPrefsUtil } from '../model/Alerts';
import { SettingsState, States, ThemeMode } from './StateTypes';

interface SettingsPatch {
  temp?: TempUnit;
  wind?: WindSpeedUnit;
  precipitation?: PrecipitationUnit;
  theme?: ThemeMode;
  language?: string;
  minuteRain?: boolean;
  animatedBackground?: boolean;
  alerts?: AlertPrefs;
}

/** What may be in the saved file; every field is checked before use. */
interface SavedSettings {
  temp?: string;
  wind?: string;
  precipitation?: string;
  theme?: string;
  language?: string;
  minuteRain?: boolean;
  animatedBackground?: boolean;
  alerts?: Object;
}

export type SettingsListener = (settings: SettingsState, previous: SettingsState) => void;

/** User preferences (lib/states/settings_cubit.dart). Other stores react through [listen]. */
@ObservedV2
export class SettingsStore {
  static readonly FILE: string = 'settings';

  @Trace state: SettingsState = States.defaultSettings();

  private listeners: SettingsListener[] = [];

  load(): void {
    const text = Storage.read(SettingsStore.FILE);
    const defaults = States.defaultSettings();
    if (text === undefined) {
      this.state = defaults;
    } else {
      try {
        const saved = JSON.parse(text) as SavedSettings;
        const settings: SettingsState = {
          temp: saved.temp === TempUnit.Fahrenheit ? TempUnit.Fahrenheit : TempUnit.Celsius,
          wind: SettingsStore.windUnit(saved.wind),
          precipitation: saved.precipitation === PrecipitationUnit.Inch ? PrecipitationUnit.Inch : PrecipitationUnit.Mm,
          theme: saved.theme === ThemeMode.Light ? ThemeMode.Light : (saved.theme === ThemeMode.Dark ? ThemeMode.Dark : ThemeMode.Auto),
          language: saved.language !== undefined && SUPPORTED_LANGUAGES.includes(saved.language) ? saved.language : '',
          minuteRain: saved.minuteRain === true,
          animatedBackground: saved.animatedBackground !== false,
          alerts: AlertPrefsUtil.read(saved.alerts)
        };
        this.state = settings;
      } catch (error) {
        hilog.warn(0x0000, 'Settings', 'Saved settings unreadable; using defaults');
        this.state = defaults;
      }
    }
    Format.appLanguage = this.state.language;
  }

  listen(listener: SettingsListener): void {
    this.listeners.push(listener);
  }

  setTemp(unit: TempUnit): void {
    this.update({ temp: unit });
  }

  setWind(unit: WindSpeedUnit): void {
    this.update({ wind: unit });
  }

  setPrecipitation(unit: PrecipitationUnit): void {
    this.update({ precipitation: unit });
  }

  setMinuteRain(enabled: boolean): void {
    this.update({ minuteRain: enabled });
  }

  setAnimatedBackground(enabled: boolean): void {
    this.update({ animatedBackground: enabled });
  }

  setAlerts(alerts: AlertPrefs): void {
    this.update({ alerts: alerts });
  }

  setTheme(mode: ThemeMode): void {
    this.update({ theme: mode });
  }

  /** Switches the app language and restarts the app so every screen picks it up. */
  setLanguage(code: string): void {
    if (code === this.state.language) {
      return;
    }
    this.update({ language: code });
    Format.appLanguage = code;
    try {
      i18n.System.setAppPreferredLanguage(code.length === 0 ? 'default' : code);
    } catch (error) {
      hilog.warn(0x0000, 'Settings', 'Language not accepted by the system: %{public}s', code);
    }
    const context = AppContext.ability;
    if (context !== undefined) {
      const want: Want = { bundleName: context.applicationInfo.name, abilityName: 'EntryAbility' };
      try {
        context.getApplicationContext().restartApp(want);
      } catch (error) {
        hilog.warn(0x0000, 'Settings', 'Restart failed: %{public}s', JSON.stringify(error));
      }
    }
  }

  private update(patch: SettingsPatch): void {
    const previous = this.state;
    const next: SettingsState = {
      temp: patch.temp ?? previous.temp,
      wind: patch.wind ?? previous.wind,
      precipitation: patch.precipitation ?? previous.precipitation,
      theme: patch.theme ?? previous.theme,
      language: patch.language ?? previous.language,
      minuteRain: patch.minuteRain ?? previous.minuteRain,
      animatedBackground: patch.animatedBackground ?? previous.animatedBackground,
      alerts: patch.alerts ?? previous.alerts
    };
    this.state = next;
    Storage.write(SettingsStore.FILE, JSON.stringify(next));
    for (const listener of this.listeners) {
      listener(next, previous);
    }
  }

  private static windUnit(value: string | undefined): WindSpeedUnit {
    switch (value) {
      case WindSpeedUnit.Mph:
        return WindSpeedUnit.Mph;
      case WindSpeedUnit.Ms:
        return WindSpeedUnit.Ms;
      case WindSpeedUnit.Kn:
        return WindSpeedUnit.Kn;
      default:
        return WindSpeedUnit.Kmh;
    }
  }

  /**
   * Sets the app's colour mode so system UI (dialogs, pickers) matches the
   * light or dark choice made by AppModel.refreshTheme.
   */
  static applyColorMode(dark: boolean): void {
    const application = AppContext.application;
    if (application === undefined) {
      return;
    }
    try {
      application.setColorMode(dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (error) {
      hilog.warn(0x0000, 'Settings', 'Could not set colour mode');
    }
  }
}
