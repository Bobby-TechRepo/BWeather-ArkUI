import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { AlertKind, PendingAlert } from '../model/Alerts';

/** Posts BWeather's notifications (lib/services/notification_service.dart). */
export class Notifier {
  /** Ids below this are the weather alerts (one per kind); trip reminders come after. */
  private static readonly TRIP_ID_BASE: number = 100;

  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      return false;
    }
  }

  /** Asks to allow notifications (shows the system dialog when needed). Returns true when allowed. */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (await Notifier.isEnabled()) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(context);
    } catch (error) {
      hilog.info(0x0000, 'Notifier', 'Notifications not allowed: %{public}s', JSON.stringify(error));
    }
    return Notifier.isEnabled();
  }

  /** One id per kind: a newer alert of the same kind replaces the older one. */
  static async showAlert(alert: PendingAlert): Promise<void> {
    const forecast = alert.kind === AlertKind.Brief;
    await Notifier.publish(alert.kind, alert.title, alert.body,
      forecast ? notificationManager.SlotType.CONTENT_INFORMATION : notificationManager.SlotType.SERVICE_INFORMATION);
  }

  /** A pre-trip reminder; [key] keeps reminders for different trips apart. */
  static async showTripReminder(key: string, title: string, body: string): Promise<void> {
    await Notifier.publish(Notifier.TRIP_ID_BASE + (Notifier.hash(key) % 1000000), title, body,
      notificationManager.SlotType.CONTENT_INFORMATION);
  }

  private static async publish(id: number, title: string, body: string,
    slot: notificationManager.SlotType): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: id,
        notificationSlotType: slot,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_LONG_TEXT,
          longText: {
            title: title,
            text: body,
            longText: body,
            briefText: title,
            expandedTitle: title
          }
        }
      };
      const agent = await Notifier.openApp();
      if (agent !== undefined) {
        request.wantAgent = agent;
      }
      await notificationManager.publish(request);
    } catch (error) {
      hilog.warn(0x0000, 'Notifier', 'Notification not posted: %{public}s', JSON.stringify(error));
    }
  }

  /** Tapping a notification opens the app. */
  private static async openApp(): Promise<WantAgent | undefined> {
    const bundleName = AppContext.base?.applicationInfo.name;
    if (bundleName === undefined) {
      return undefined;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: bundleName, abilityName: 'EntryAbility' }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(info);
    } catch (error) {
      return undefined;
    }
  }

  /** A stable non-negative number for a string (Java's String.hashCode, made positive). */
  private static hash(text: string): number {
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
      hash = (hash * 31 + text.charCodeAt(i)) | 0;
    }
    return Math.abs(hash);
  }
}
