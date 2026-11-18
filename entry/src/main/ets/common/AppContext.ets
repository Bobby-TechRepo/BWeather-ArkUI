import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';

/**
 * The application context, saved by EntryAbility before anything else runs,
 * so non-UI code (stores, repositories) can reach files and resources.
 */
export class AppContext {
  private static current: common.Context | undefined = undefined;
  private static uiContext: common.UIAbilityContext | undefined = undefined;

  static init(context: common.UIAbilityContext): void {
    AppContext.current = context;
    AppContext.uiContext = context;
  }

  /** For the background worker, which has no UI ability (only files and resources are available). */
  static initBackground(context: common.Context): void {
    if (AppContext.current === undefined) {
      AppContext.current = context;
    }
  }

  static get ability(): common.UIAbilityContext | undefined {
    return AppContext.uiContext;
  }

  /** The ability's or the background worker's context. */
  static get base(): common.Context | undefined {
    return AppContext.current;
  }

  static get application(): common.ApplicationContext | undefined {
    return AppContext.current?.getApplicationContext();
  }

  static get resources(): resourceManager.ResourceManager | undefined {
    return AppContext.current?.resourceManager;
  }

  static get filesDir(): string {
    return AppContext.current?.filesDir ?? '';
  }
}

/**
 * Localized strings outside the UI tree. Placeholders are positional ("%1$s")
 * and always filled with strings (see tools/arb_to_harmony.py).
 */
export class S {
  static get(res: Resource, ...args: string[]): string {
    const rm = AppContext.resources;
    if (rm === undefined) {
      return '';
    }
    try {
      return args.length === 0 ? rm.getStringSync(res.id) : rm.getStringSync(res.id, ...args);
    } catch (error) {
      return '';
    }
  }

  /**
   * One of three messages by count, mirroring the ARB plurals
   * ("=0{..} =1{..} other{..}"), which became <key>_zero/_one/_other.
   */
  static count(n: number, zero: Resource, one: Resource, other: Resource): string {
    const res = n === 0 ? zero : (n === 1 ? one : other);
    return S.get(res, `${n}`);
  }
}
