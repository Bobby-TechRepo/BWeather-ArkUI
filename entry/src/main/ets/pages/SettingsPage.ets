import { bundleManager } from '@kit.AbilityKit';
import { AppContext, S } from '../common/AppContext';
import { Format, LANGUAGE_NAMES, SUPPORTED_LANGUAGES } from '../common/Format';
import { Palette, SettingsColors } from '../common/Theme';
import { PrecipitationUnit, TempUnit, WindSpeedUnit } from '../common/Units';
import { SegmentOption } from '../components/Segmented';
import {
  SettingsDivider, SettingsSection, SettingsSegmentedTile, SettingsSwitchTile, SettingsTile
} from '../components/SettingsRows';
import { Notifier } from '../data/Notifier';
import { AlertPrefs, AlertPrefsUtil } from '../model/Alerts';
import { AppModel } from '../state/AppModel';
import { SettingsState, ThemeMode } from '../state/StateTypes';

/** "Version 1.0.0 (1)" for the installed build; "" if unknown. */
export function appVersion(): string {
  try {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return S.get($r('app.string.version'), `${info.versionName} (${info.versionCode})`);
  } catch (error) {
    return '';
  }
}

/** Keeps lines readable on tablets and desktop windows. */
const MAX_CONTENT_WIDTH: number = 720;

interface LanguageChoice {
  code: string;
  name: string;
}

/** Settings tab with grouped lists (lib/pages/settings.dart). */
@ComponentV2
export struct SettingsPage {
  @Local model: AppModel = AppModel.shared();
  @Local areaWidth: number = 360;
  @Local showLanguages: boolean = false;
  @Local showBriefTimes: boolean = false;

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get settings(): SettingsState {
    return this.model.settings.state;
  }

  get rowWidth(): number {
    return Math.min(this.areaWidth, MAX_CONTENT_WIDTH) - 32;
  }

  get languageName(): string {
    return LANGUAGE_NAMES.get(this.settings.language) ?? S.get($r('app.string.languageSystem'));
  }

  get alerts(): AlertPrefs {
    return this.settings.alerts;
  }

  /** Morning briefing times offered: 05:00 to 10:00. */
  get briefHours(): number[] {
    return [5, 6, 7, 8, 9, 10];
  }

  hourLabel(hour: number): string {
    return Format.clock(Date.UTC(2000, 0, 1, hour, 0));
  }

  /** Turning the first alert on asks for notification permission first. */
  async updateAlerts(updated: AlertPrefs, turningOn: boolean): Promise<void> {
    if (turningOn && !AlertPrefsUtil.anyEnabled(this.alerts)) {
      const context = AppContext.ability;
      const granted = context !== undefined && await Notifier.requestPermission(context);
      if (!granted) {
        this.model.ui.showSnack(S.get($r('app.string.notifyPermissionDenied')));
        return;
      }
    }
    this.model.settings.setAlerts(updated);
  }

  copyAlerts(morningBrief: boolean, rain: boolean, severe: boolean, briefHour: number): AlertPrefs {
    const prefs: AlertPrefs = { morningBrief: morningBrief, rain: rain, severe: severe, briefHour: briefHour };
    return prefs;
  }

  get languages(): LanguageChoice[] {
    const choices: LanguageChoice[] = [{ code: '', name: S.get($r('app.string.languageSystem')) }];
    for (const code of SUPPORTED_LANGUAGES) {
      choices.push({ code: code, name: LANGUAGE_NAMES.get(code) ?? code });
    }
    return choices;
  }

  get themeOptions(): SegmentOption[] {
    const options: SegmentOption[] = [
      { value: ThemeMode.Auto, label: $r('app.string.themeAuto') },
      { value: ThemeMode.Light, label: $r('app.string.themeLight') },
      { value: ThemeMode.Dark, label: $r('app.string.themeDark') }
    ];
    return options;
  }

  get tempOptions(): SegmentOption[] {
    const options: SegmentOption[] = [
      { value: TempUnit.Celsius, label: '°C' },
      { value: TempUnit.Fahrenheit, label: '°F' }
    ];
    return options;
  }

  get windOptions(): SegmentOption[] {
    const options: SegmentOption[] = [
      { value: WindSpeedUnit.Kmh, label: 'km/h' },
      { value: WindSpeedUnit.Mph, label: 'mph' },
      { value: WindSpeedUnit.Ms, label: 'm/s' },
      { value: WindSpeedUnit.Kn, label: 'kn' }
    ];
    return options;
  }

  get precipitationOptions(): SegmentOption[] {
    const options: SegmentOption[] = [
      { value: PrecipitationUnit.Mm, label: 'mm' },
      { value: PrecipitationUnit.Inch, label: 'in' }
    ];
    return options;
  }

  build() {
    Scroll() {
      Column() {
        Text($r('app.string.navSettings'))
          .fontSize(32)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette.onSurface)
          .padding({ left: 16, right: 16, top: 24 + this.model.ui.topInset, bottom: 16 })
          .width('100%')

        Column() {
          SettingsSection({
            title: $r('app.string.settingsAppearance'),
            footer: this.settings.theme === ThemeMode.Auto ? $r('app.string.themeAutoHint') : '',
            palette: this.palette
          }) {
            SettingsSegmentedTile({
              icon: $r('app.media.ic_contrast'),
              color: SettingsColors.INDIGO,
              title: $r('app.string.settingsTheme'),
              options: this.themeOptions,
              selected: this.settings.theme,
              rowWidth: this.rowWidth,
              palette: this.palette,
              onSelect: (value: string) => {
                this.model.settings.setTheme(value as ThemeMode);
              }
            })
            SettingsDivider(this.palette)
            Column() {
              SettingsTile({
                icon: $r('app.media.ic_translate'),
                color: SettingsColors.BLUE,
                title: $r('app.string.settingsLanguage'),
                value: this.languageName,
                palette: this.palette,
                onTap: () => {
                  this.showLanguages = true;
                }
              })
            }
            .width('100%')
            .bindSheet(this.showLanguages, this.languageSheet(), {
              height: SheetSize.MEDIUM,
              title: { title: $r('app.string.settingsLanguage') },
              backgroundColor: this.palette.surfaceLow,
              onDisappear: () => {
                this.showLanguages = false;
              }
            })
            SettingsDivider(this.palette)
            SettingsSwitchTile({
              icon: $r('app.media.ic_auto_awesome'),
              color: SettingsColors.PINK,
              title: $r('app.string.settingsAnimatedBackground'),
              subtitle: $r('app.string.settingsAnimatedBackgroundDetail'),
              isOn: this.settings.animatedBackground,
              palette: this.palette,
              onToggle: (isOn: boolean) => {
                this.model.settings.setAnimatedBackground(isOn);
              }
            })
          }

          SettingsSection({ title: $r('app.string.settingsUnits'), palette: this.palette }) {
            SettingsSegmentedTile({
              icon: $r('app.media.ic_thermostat'),
              color: SettingsColors.ORANGE,
              title: $r('app.string.settingsTemperature'),
              options: this.tempOptions,
              selected: this.settings.temp,
              rowWidth: this.rowWidth,
              palette: this.palette,
              onSelect: (value: string) => {
                this.model.settings.setTemp(value as TempUnit);
              }
            })
            SettingsDivider(this.palette)
            SettingsSegmentedTile({
              icon: $r('app.media.ic_air'),
              color: SettingsColors.TEAL,
              title: $r('app.string.settingsWindSpeed'),
              options: this.windOptions,
              selected: this.settings.wind,
              rowWidth: this.rowWidth,
              palette: this.palette,
              onSelect: (value: string) => {
                this.model.settings.setWind(value as WindSpeedUnit);
              }
            })
            SettingsDivider(this.palette)
            SettingsSegmentedTile({
              icon: $r('app.media.ic_water_drop'),
              color: SettingsColors.BLUE,
              title: $r('app.string.settingsPrecipitation'),
              options: this.precipitationOptions,
              selected: this.settings.precipitation,
              rowWidth: this.rowWidth,
              palette: this.palette,
              onSelect: (value: string) => {
                this.model.settings.setPrecipitation(value as PrecipitationUnit);
              }
            })
          }

          SettingsSection({ title: $r('app.string.navForecast'), palette: this.palette }) {
            SettingsSwitchTile({
              icon: $r('app.media.ic_grain'),
              color: SettingsColors.INDIGO,
              title: $r('app.string.settingsMinuteRain'),
              subtitle: $r('app.string.settingsMinuteRainDetail'),
              isOn: this.settings.minuteRain,
              palette: this.palette,
              onToggle: (isOn: boolean) => {
                this.model.settings.setMinuteRain(isOn);
              }
            })
          }

          SettingsSection({
            title: $r('app.string.settingsNotifications'),
            footer: $r('app.string.notifyBackgroundNoteHarmony'),
            palette: this.palette
          }) {
            SettingsSwitchTile({
              icon: $r('app.media.ic_sunny'),
              color: SettingsColors.ORANGE,
              title: $r('app.string.notifyMorningBrief'),
              subtitle: $r('app.string.notifyMorningBriefDetail'),
              isOn: this.alerts.morningBrief,
              palette: this.palette,
              onToggle: (isOn: boolean) => {
                this.updateAlerts(this.copyAlerts(isOn, this.alerts.rain, this.alerts.severe, this.alerts.briefHour), isOn);
              }
            })
            if (this.alerts.morningBrief) {
              SettingsDivider(this.palette)
              Column() {
                SettingsTile({
                  icon: $r('app.media.ic_schedule'),
                  color: SettingsColors.ORANGE,
                  title: $r('app.string.notifyBriefTime'),
                  value: this.hourLabel(this.alerts.briefHour),
                  palette: this.palette,
                  onTap: () => {
                    this.showBriefTimes = true;
                  }
                })
              }
              .width('100%')
              .bindSheet(this.showBriefTimes, this.briefTimeSheet(), {
                height: SheetSize.MEDIUM,
                title: { title: $r('app.string.notifyBriefTime') },
                backgroundColor: this.palette.surfaceLow,
                onDisappear: () => {
                  this.showBriefTimes = false;
                }
              })
            }
            SettingsDivider(this.palette)
            SettingsSwitchTile({
              icon: $r('app.media.ic_umbrella'),
              color: SettingsColors.BLUE,
              title: $r('app.string.notifyRain'),
              subtitle: $r('app.string.notifyRainDetail'),
              isOn: this.alerts.rain,
              palette: this.palette,
              onToggle: (isOn: boolean) => {
                this.updateAlerts(this.copyAlerts(this.alerts.morningBrief, isOn, this.alerts.severe, this.alerts.briefHour), isOn);
              }
            })
            SettingsDivider(this.palette)
            SettingsSwitchTile({
              icon: $r('app.media.ic_bolt'),
              color: SettingsColors.RED,
              title: $r('app.string.notifySevere'),
              subtitle: $r('app.string.notifySevereDetail'),
              isOn: this.alerts.severe,
              palette: this.palette,
              onToggle: (isOn: boolean) => {
                this.updateAlerts(this.copyAlerts(this.alerts.morningBrief, this.alerts.rain, isOn, this.alerts.briefHour), isOn);
              }
            })
          }

          SettingsSection({ title: $r('app.string.settingsAbout'), palette: this.palette }) {
            SettingsTile({
              icon: $r('app.media.ic_info'),
              color: SettingsColors.BLUE,
              title: $r('app.string.aboutApp'),
              value: appVersion(),
              palette: this.palette,
              onTap: () => {
                this.model.nav.pushPathByName('info', null);
              }
            })
            SettingsDivider(this.palette)
            SettingsTile({
              icon: $r('app.media.ic_privacy'),
              color: SettingsColors.GREEN,
              title: $r('app.string.privacyPolicy'),
              palette: this.palette,
              onTap: () => {
                this.model.nav.pushPathByName('privacy', null);
              }
            })
            SettingsDivider(this.palette)
            SettingsTile({
              icon: $r('app.media.ic_description'),
              color: SettingsColors.GREY,
              title: $r('app.string.termsOfUse'),
              palette: this.palette,
              onTap: () => {
                this.model.nav.pushPathByName('terms', null);
              }
            })
          }
        }
        .constraintSize({ maxWidth: MAX_CONTENT_WIDTH })
        .width('100%')
        .padding({ bottom: this.model.ui.contentBottomInset })
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.areaWidth = Number(newArea.width);
    })
  }

  @Builder
  briefTimeSheet() {
    List() {
      ForEach(this.briefHours, (hour: number) => {
        ListItem() {
          Row() {
            Text(this.hourLabel(hour))
              .fontSize(16)
              .fontColor(hour === this.alerts.briefHour ? this.palette.primary : this.palette.onSurface)
              .layoutWeight(1)
            if (hour === this.alerts.briefHour) {
              Image($r('app.media.ic_check_circle')).width(24).height(24).fillColor(this.palette.primary)
            }
          }
          .padding({ left: 24, right: 24, top: 14, bottom: 14 })
          .width('100%')
          .onClick(() => {
            this.showBriefTimes = false;
            this.model.settings.setAlerts(this.copyAlerts(this.alerts.morningBrief, this.alerts.rain, this.alerts.severe, hour));
          })
        }
      }, (hour: number) => `${hour}`)
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  languageSheet() {
    List() {
      ForEach(this.languages, (choice: LanguageChoice) => {
        ListItem() {
          Row() {
            Text(choice.name)
              .fontSize(16)
              .fontColor(choice.code === this.settings.language ? this.palette.primary : this.palette.onSurface)
              .layoutWeight(1)
            if (choice.code === this.settings.language) {
              Image($r('app.media.ic_check_circle')).width(24).height(24).fillColor(this.palette.primary)
            }
          }
          .padding({ left: 24, right: 24, top: 14, bottom: 14 })
          .width('100%')
          .onClick(() => {
            this.showLanguages = false;
            if (choice.code !== this.settings.language) {
              // Give the sheet time to close before the app restarts.
              setTimeout(() => this.model.settings.setLanguage(choice.code), 300);
            }
          })
        }
      }, (choice: LanguageChoice) => choice.code)
    }
    .width('100%')
    .padding({ bottom: 16 })
  }
}
