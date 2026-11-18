import { abilityAccessCtrl, bundleManager, common, Permissions, Want } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';

export enum LocationFailure {
  ServiceDisabled = 'serviceDisabled',
  PermissionDenied = 'permissionDenied',
  PermissionBlocked = 'permissionBlocked',
  Unavailable = 'unavailable'
}

export class LocationError extends Error {
  readonly reason: LocationFailure;

  constructor(reason: LocationFailure) {
    super(reason);
    this.reason = reason;
  }
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

const PERMISSIONS: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];

/** The device's position, with the permission and location-switch flows (lib/services/location_service.dart). */
export class LocationService {
  /** Oldest cached fix we accept when a fresh one can't be obtained. */
  static readonly MAX_LAST_KNOWN_AGE_MS: number = 60 * 60 * 1000;
  static readonly FIX_TIMEOUT_MS: number = 15000;

  /**
   * Current position. Asks for permission (and to turn location on) when
   * [request] is true; otherwise only uses access the user already granted.
   */
  async currentPosition(request: boolean): Promise<Coordinates> {
    const context = AppContext.ability;
    if (context === undefined) {
      throw new LocationError(LocationFailure.Unavailable);
    }

    if (!LocationService.hasPermission()) {
      if (!request) {
        throw new LocationError(LocationFailure.PermissionDenied);
      }
      await LocationService.requestPermission(context);
    }

    if (!LocationService.isEnabled()) {
      if (!request || !(await LocationService.askToEnable(context))) {
        throw new LocationError(LocationFailure.ServiceDisabled);
      }
    }

    try {
      const options: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        locatingTimeoutMs: LocationService.FIX_TIMEOUT_MS
      };
      const location = await geoLocationManager.getCurrentLocation(options);
      const coordinates: Coordinates = { latitude: location.latitude, longitude: location.longitude };
      return coordinates;
    } catch (error) {
      hilog.warn(0x0000, 'Location', 'No fix: %{public}s', JSON.stringify(error));
    }

    // Timed out or no fix (e.g. indoors): fall back to a recent cached fix.
    try {
      const last = geoLocationManager.getLastLocation();
      if (Date.now() - last.timeStamp <= LocationService.MAX_LAST_KNOWN_AGE_MS) {
        const coordinates: Coordinates = { latitude: last.latitude, longitude: last.longitude };
        return coordinates;
      }
    } catch (error) {
      // No cached fix either.
    }
    throw new LocationError(LocationFailure.Unavailable);
  }

  static hasPermission(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const manager = abilityAccessCtrl.createAtManager();
      const status = manager.checkAccessTokenSync(info.appInfo.accessTokenId, 'ohos.permission.APPROXIMATELY_LOCATION');
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      return false;
    }
  }

  static isEnabled(): boolean {
    try {
      return geoLocationManager.isLocationEnabled();
    } catch (error) {
      return false;
    }
  }

  /**
   * Shows the system permission dialog. When the user has already said no,
   * the system won't show it again, so we offer the in-place settings dialog.
   */
  private static async requestPermission(context: common.UIAbilityContext): Promise<void> {
    const manager = abilityAccessCtrl.createAtManager();
    let shown = true;
    try {
      const result = await manager.requestPermissionsFromUser(context, PERMISSIONS);
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return;
      }
      shown = result.dialogShownResults === undefined || result.dialogShownResults.length === 0 ||
        result.dialogShownResults[0];
    } catch (error) {
      hilog.warn(0x0000, 'Location', 'Permission request failed: %{public}s', JSON.stringify(error));
    }
    if (!shown) {
      try {
        const states = await manager.requestPermissionOnSetting(context, PERMISSIONS);
        if (states.length > 0 && states[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return;
        }
      } catch (error) {
        hilog.warn(0x0000, 'Location', 'Settings dialog failed: %{public}s', JSON.stringify(error));
      }
      throw new LocationError(LocationFailure.PermissionBlocked);
    }
    throw new LocationError(LocationFailure.PermissionDenied);
  }

  /** The system dialog that turns location services on. */
  private static async askToEnable(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const manager = abilityAccessCtrl.createAtManager();
      return await manager.requestGlobalSwitch(context, abilityAccessCtrl.SwitchType.LOCATION);
    } catch (error) {
      return false;
    }
  }

  /** Opens this app's page in system Settings (for a permission blocked earlier). */
  static openSettings(): void {
    const context = AppContext.ability;
    if (context === undefined) {
      return;
    }
    const bundleName = context.applicationInfo.name;
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'application_info_entry',
      parameters: { pushParams: bundleName }
    };
    context.startAbility(want).catch((error: Object) => {
      hilog.warn(0x0000, 'Location', 'Could not open settings: %{public}s', JSON.stringify(error));
    });
  }
}
