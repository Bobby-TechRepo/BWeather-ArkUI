import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { runBackgroundRefresh } from '../data/BackgroundRefresh';

/**
 * The periodic background check registered by AlertScheduler: morning
 * briefing, rain and severe-weather alerts, and trip reminders. The system
 * gives each run up to 2 minutes.
 */
export default class AlertWorker extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    AppContext.initBackground(this.context);
    runBackgroundRefresh().catch((error: Object) => {
      hilog.warn(0x0000, 'AlertWorker', 'Run failed: %{public}s', JSON.stringify(error));
    });
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
  }
}
