import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from './AppContext';

/**
 * Saved state as JSON files in the app's private files directory (what
 * HydratedBloc did in the Flutter app). Writes go to a temporary file first and
 * are then renamed, so a crash mid-write can't leave a half-written file.
 */
export class Storage {
  private static path(name: string): string {
    return `${AppContext.filesDir}/${name}.json`;
  }

  static read(name: string): string | undefined {
    const path = Storage.path(name);
    try {
      if (!fileIo.accessSync(path)) {
        return undefined;
      }
      return fileIo.readTextSync(path);
    } catch (error) {
      hilog.warn(0x0000, 'Storage', 'Could not read %{public}s: %{public}s', name, JSON.stringify(error));
      return undefined;
    }
  }

  static write(name: string, text: string): void {
    const path = Storage.path(name);
    const temporary = `${path}.tmp`;
    try {
      const file = fileIo.openSync(temporary, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, text);
      fileIo.closeSync(file);
      fileIo.renameSync(temporary, path);
    } catch (error) {
      hilog.error(0x0000, 'Storage', 'Could not save %{public}s: %{public}s', name, JSON.stringify(error));
    }
  }
}

/** Calls [action] once things have been quiet for [delay] ms (used to batch saves). */
export class Debouncer {
  private timer: number = -1;
  private readonly delay: number;

  constructor(delay: number) {
    this.delay = delay;
  }

  run(action: () => void): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout(() => {
      this.timer = -1;
      action();
    }, this.delay);
  }

  cancel(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }
}
