import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AppContext } from '../common/AppContext';
import { AppModel } from '../state/AppModel';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | undefined = undefined;
  /** Re-checks the "Auto" theme every minute so it turns dark at sunset. */
  private themeTimer: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContext.init(this.context);
    // Loads saved settings (which applies the chosen colour mode) and places, then starts fetching.
    const model = AppModel.shared();
    model.onThemeChange = () => this.applyWindowColors();
    model.start();
    hilog.info(DOMAIN, 'BWeather', 'Ability onCreate');
  }

  onDestroy(): void {
    this.stopThemeTimer();
    hilog.info(DOMAIN, 'BWeather', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'BWeather', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.applyWindowColors();
      this.setUpEdgeToEdge();
    });
  }

  onWindowStageDestroy(): void {
    this.windowStage = undefined;
  }

  onForeground(): void {
    // Refresh stale forecasts when the user comes back to the app.
    const model = AppModel.shared();
    model.weather.onResume();
    model.refreshTheme();
    this.stopThemeTimer();
    this.themeTimer = setInterval(() => {
      AppModel.shared().refreshTheme();
    }, 60000);
  }

  onBackground(): void {
    this.stopThemeTimer();
    // Hand the latest place, settings and trips to the background worker.
    AppModel.shared().syncBackgroundWork();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // The app sets its own colour mode (AppModel.refreshTheme), so the system theme is not followed.
  }

  private stopThemeTimer(): void {
    if (this.themeTimer !== -1) {
      clearInterval(this.themeTimer);
      this.themeTimer = -1;
    }
  }

  /** Window background and system bar text colours for light and dark mode. The bars themselves are transparent. */
  private applyWindowColors(): void {
    const stage = this.windowStage;
    if (stage === undefined) {
      return;
    }
    try {
      const palette = AppModel.shared().ui.palette;
      const main = stage.getMainWindowSync();
      main.setWindowBackgroundColor(palette.surfaceLowest);
      main.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: palette.dark ? '#FFFFFF' : '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: palette.dark ? '#FFFFFF' : '#000000'
      }).catch((error: Object) => {
        hilog.warn(DOMAIN, 'BWeather', 'System bar colours not set: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'BWeather', 'Window colours not set: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * Draws the app under the status bar and the navigation indicator. The
   * screens pad their content by the system bar heights (UiStore.topInset/bottomInset).
   */
  private setUpEdgeToEdge(): void {
    const stage = this.windowStage;
    if (stage === undefined) {
      return;
    }
    try {
      const main = stage.getMainWindowSync();
      main.setWindowLayoutFullScreen(true).catch((error: Object) => {
        hilog.warn(DOMAIN, 'BWeather', 'Full-screen layout not set: %{public}s', JSON.stringify(error));
      });
      this.updateInsets(main);
      main.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        this.updateInsets(main);
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'BWeather', 'Edge-to-edge layout unavailable: %{public}s', JSON.stringify(error));
    }
  }

  private updateInsets(main: window.Window): void {
    try {
      const density = display.getDefaultDisplaySync().densityPixels;
      const system = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const ui = AppModel.shared().ui;
      ui.systemTop = system.topRect.height / density;
      ui.systemBottom = Math.max(system.bottomRect.height, indicator.bottomRect.height) / density;
      ui.windowHeight = main.getWindowProperties().windowRect.height / density;
    } catch (error) {
      hilog.warn(DOMAIN, 'BWeather', 'Avoid areas unavailable: %{public}s', JSON.stringify(error));
    }
  }
}
