import { connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DayNight } from '../common/DayNight';
import { CardService } from '../data/CardService';
import { CardDataUtil } from '../model/CardData';
import { DARK, LIGHT, Palette } from '../common/Theme';
import { AlertScheduler } from './AlertScheduler';
import { SearchStore } from './SearchStore';
import { SettingsStore } from './SettingsStore';
import { City } from '../model/Models';
import { AppTab, SettingsState, States, ThemeMode } from './StateTypes';
import { TripsStore } from './TripsStore';
import { WeatherStore } from './WeatherStore';

/** The place the rain radar opens on. */
export interface RadarTarget {
  latitude: number;
  longitude: number;
  name: string;
}

/** A short message at the bottom of the screen, optionally with an action ("Undo"). */
export class Snack {
  readonly id: number;
  readonly text: string;
  readonly actionLabel: string;
  readonly action: (() => void) | undefined;

  constructor(id: number, text: string, actionLabel: string, action: (() => void) | undefined) {
    this.id = id;
    this.text = text;
    this.actionLabel = actionLabel;
    this.action = action;
  }
}

/** Layout classes, as in the Flutter app's responsive breakpoints. */
export enum LayoutSize {
  /** < 600 vp: bottom navigation bar. */
  Mobile = 'mobile',
  /** 600–1023 vp: navigation rail. */
  Tablet = 'tablet',
  /** ≥ 1024 vp: rail plus a permanent places panel. */
  Desktop = 'desktop'
}

/** Navigation and screen state (lib/states/main_cubit.dart plus theme and window size). */
@ObservedV2
export class UiStore {
  @Trace tab: AppTab = AppTab.Forecast;
  /** Key of the place the forecast pager should show ("" = first place). */
  @Trace selectedPlace: string = '';
  /** Bumped on every request to show a place, so asking twice still jumps. */
  @Trace selectionRequest: number = 0;
  @Trace dark: boolean = false;
  /** Window width in vp. */
  @Trace width: number = 360;
  @Trace snack: Snack | undefined = undefined;
  /** Heights of the status bar and the bottom navigation area, in vp. */
  @Trace systemTop: number = 0;
  @Trace systemBottom: number = 0;
  /** Window height and the height the root content actually got, in vp. */
  @Trace windowHeight: number = 0;
  @Trace contentHeight: number = 0;

  /** The trip the detail page shows. */
  @Trace tripId: string = '';
  /** The trip the editor edits ("" for a new trip). */
  @Trace editingTripId: string = '';
  /**
   * Set while the city search is used as a picker (trip editor): the chosen
   * city goes here instead of being saved to Locations.
   */
  pickCity: ((city: City) => void) | undefined = undefined;
  /** Where the rain radar opens (set before pushing "radar"). */
  radarTarget: RadarTarget | undefined = undefined;

  private snackCounter: number = 0;
  private snackTimer: number = -1;

  get palette(): Palette {
    return this.dark ? DARK : LIGHT;
  }

  /** True when the app is drawn under the system bars (so screens must pad their content). */
  get edgeToEdge(): boolean {
    return this.windowHeight > 0 && this.contentHeight >= this.windowHeight - 2;
  }

  /** Space to leave at the top for the status bar. */
  get topInset(): number {
    return this.edgeToEdge ? this.systemTop : 0;
  }

  /** Space to leave at the bottom for the navigation indicator. */
  get bottomInset(): number {
    return this.edgeToEdge ? this.systemBottom : 0;
  }

  /** Bottom space for scrolling pages: on phones the bottom bar already covers it. */
  get contentBottomInset(): number {
    return this.layout === LayoutSize.Mobile ? 0 : this.bottomInset;
  }

  get layout(): LayoutSize {
    if (this.width < 600) {
      return LayoutSize.Mobile;
    }
    return this.width < 1024 ? LayoutSize.Tablet : LayoutSize.Desktop;
  }

  /** Switches to the forecast and pages to the place with [key]. */
  showPlace(key: string): void {
    this.tab = AppTab.Forecast;
    this.selectedPlace = key;
    this.selectionRequest++;
  }

  /** Records the page the user swiped to (does not trigger a jump). */
  placeVisible(key: string): void {
    if (this.selectedPlace !== key) {
      this.selectedPlace = key;
    }
  }

  showSnack(text: string, actionLabel: string = '', action?: () => void): void {
    this.snackCounter++;
    this.snack = new Snack(this.snackCounter, text, actionLabel, action);
    if (this.snackTimer !== -1) {
      clearTimeout(this.snackTimer);
    }
    const id = this.snackCounter;
    this.snackTimer = setTimeout(() => {
      this.snackTimer = -1;
      if (this.snack !== undefined && this.snack.id === id) {
        this.snack = undefined;
      }
    }, 4000);
  }

  hideSnack(): void {
    this.snack = undefined;
  }
}

/** Everything the screens need, created once (what the BlocProviders were in the Flutter app). */
@ObservedV2
export class AppModel {
  private static instance: AppModel | undefined = undefined;

  readonly settings: SettingsStore = new SettingsStore();
  readonly weather: WeatherStore = new WeatherStore();
  readonly search: SearchStore = new SearchStore();
  readonly trips: TripsStore = new TripsStore();
  readonly ui: UiStore = new UiStore();
  /** Background alerts and trip reminders. */
  readonly alerts: AlertScheduler = new AlertScheduler();
  /** Shared by the root Navigation; screens push and pop on it. */
  readonly nav: NavPathStack = new NavPathStack();

  private started: boolean = false;
  private net: connection.NetConnection | undefined = undefined;
  private themeApplied: boolean = false;
  /** Called after light/dark changes (EntryAbility recolours the window and system bars). */
  onThemeChange: (() => void) | undefined = undefined;

  static shared(): AppModel {
    if (AppModel.instance === undefined) {
      AppModel.instance = new AppModel();
    }
    return AppModel.instance;
  }

  /** Loads saved state and starts fetching. Safe to call more than once. */
  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.settings.load();
    this.weather.load(this.settings.state);
    this.trips.load(this.settings.state);
    this.refreshTheme();
    this.syncBackgroundWork();
    this.weather.onSaved = () => this.updateCard();
    this.settings.listen((settings: SettingsState, previous: SettingsState) => {
      this.weather.onSettingsChanged(settings, previous);
      this.trips.onSettingsChanged(settings);
      if (settings.theme !== previous.theme) {
        this.refreshTheme();
      }
      this.syncBackgroundWork();
    });
    this.weather.start();
    this.watchNetwork();
  }

  /**
   * Saves the card text for the first place (the user's location, or the
   * first saved city) and redraws any home-screen cards.
   */
  updateCard(): void {
    const places = States.places(this.weather.state);
    const place = places.length === 0 ? undefined : places[0];
    const forecast = place?.city.forecast;
    if (place === undefined || forecast === undefined) {
      return;
    }
    CardService.push(CardDataUtil.from(place.city, forecast, place.updatedAt ?? Date.now())).catch((error: Object) => {
      hilog.warn(0x0000, 'AppModel', 'Card not updated: %{public}s', JSON.stringify(error));
    });
  }

  /**
   * Tells the background worker what to check. Called on start, when settings
   * change, when a trip reminder is switched and when the app goes to the background.
   */
  syncBackgroundWork(): void {
    try {
      this.alerts.sync(this.settings.state, this.weather.state, this.trips.state.trips);
    } catch (error) {
      hilog.warn(0x0000, 'AppModel', 'Background work not updated: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * Light or dark: an explicit choice in settings wins; "Auto" is light from
   * sunrise to sunset at the user's location (07:00–19:00 without one).
   * Called on start, on a theme change, when the app returns to the
   * foreground and once a minute.
   */
  refreshTheme(): void {
    const theme = this.settings.state.theme;
    const city = this.weather.state.location?.city;
    const dark = theme === ThemeMode.Auto ?
      !DayNight.isDay(Date.now(), city?.latitude, city?.longitude) : theme === ThemeMode.Dark;
    if (this.themeApplied && dark === this.ui.dark) {
      return;
    }
    this.themeApplied = true;
    this.ui.dark = dark;
    SettingsStore.applyColorMode(dark);
    this.onThemeChange?.();
  }

  private watchNetwork(): void {
    try {
      const net = connection.createNetConnection();
      net.on('netAvailable', () => {
        this.weather.onConnected();
      });
      net.register(() => {
      });
      this.net = net;
    } catch (error) {
      hilog.warn(0x0000, 'AppModel', 'Network monitoring unavailable: %{public}s', JSON.stringify(error));
    }
  }
}
