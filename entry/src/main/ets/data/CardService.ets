import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Storage } from '../common/Storage';
import { CardData, CardDataUtil } from '../model/CardData';

interface SavedForms {
  ids: string[];
}

/**
 * The home-screen card's data and the ids of the cards placed by the user
 * (what HomeWidgetService did on Android). The app, the background worker and
 * the form ability all go through here.
 */
export class CardService {
  private static readonly DATA: string = 'card';
  private static readonly FORMS: string = 'card_forms';
  /** FormKit error: "the ID of the form to be operated does not exist". */
  private static readonly FORM_NOT_FOUND: number = 16501001;

  static formIds(): string[] {
    const text = Storage.read(CardService.FORMS);
    if (text === undefined || text.length === 0) {
      return [];
    }
    try {
      const saved = JSON.parse(text) as SavedForms;
      return Array.isArray(saved.ids) ? saved.ids.map((id: string) => `${id}`) : [];
    } catch (error) {
      return [];
    }
  }

  static hasCards(): boolean {
    return CardService.formIds().length > 0;
  }

  static addForm(id: string): void {
    const ids = CardService.formIds();
    if (!ids.includes(id)) {
      CardService.writeForms(ids.concat([id]));
    }
  }

  static removeForm(id: string): void {
    CardService.writeForms(CardService.formIds().filter((existing: string) => existing !== id));
  }

  /** The last data shown, or the "open the app" card. */
  static saved(): CardData {
    const text = Storage.read(CardService.DATA);
    const empty = CardDataUtil.empty();
    if (text === undefined || text.length === 0) {
      return empty;
    }
    try {
      const saved = JSON.parse(text) as CardData;
      const data: CardData = {
        ready: saved.ready === true,
        place: typeof saved.place === 'string' ? saved.place : '',
        temperature: typeof saved.temperature === 'string' ? saved.temperature : empty.temperature,
        condition: typeof saved.condition === 'string' ? saved.condition : '',
        icon: typeof saved.icon === 'string' ? saved.icon : empty.icon,
        range: typeof saved.range === 'string' ? saved.range : '',
        updated: typeof saved.updated === 'string' ? saved.updated : ''
      };
      return data;
    } catch (error) {
      return empty;
    }
  }

  static binding(data: CardData): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(data);
  }

  /** Saves [data] and redraws every card. Unchanged data is skipped unless [force]. */
  static async push(data: CardData, force: boolean = false): Promise<void> {
    if (!force && CardDataUtil.same(data, CardService.saved())) {
      return;
    }
    Storage.write(CardService.DATA, JSON.stringify(data));
    const binding = CardService.binding(data);
    for (const id of CardService.formIds()) {
      try {
        await formProvider.updateForm(id, binding);
      } catch (error) {
        hilog.info(0x0000, 'Card', 'Card %{public}s not updated: %{public}s', id, JSON.stringify(error));
        if ((error as BusinessError).code === CardService.FORM_NOT_FOUND) {
          // The card was removed without the form ability being told; forget it.
          CardService.removeForm(id);
        }
      }
    }
  }

  private static writeForms(ids: string[]): void {
    const saved: SavedForms = { ids: ids };
    Storage.write(CardService.FORMS, ids.length === 0 ? '' : JSON.stringify(saved));
  }
}
