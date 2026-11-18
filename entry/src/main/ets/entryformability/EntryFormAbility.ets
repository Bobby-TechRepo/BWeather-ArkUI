import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { AlertStore } from '../data/AlertStore';
import { refreshCard } from '../data/BackgroundRefresh';
import { CardService } from '../data/CardService';
import { AlertScheduler } from '../state/AlertScheduler';

/**
 * The home-screen card (WeatherWidgetProvider.kt on Android). It shows what
 * the app and the background worker saved, and fetches a fresh forecast on
 * the card's own periodic update (form_config.json).
 */
export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    AppContext.initBackground(this.context);
    const raw: Object | undefined = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    const id = raw === undefined ? '' : `${raw}`;
    if (id.length > 0) {
      CardService.addForm(id);
      // Keep the card fresh even if the app isn't opened again.
      const target = AlertStore.readTarget();
      if (target !== undefined && !target.card) {
        target.card = true;
        AlertStore.writeTarget(target);
      }
      AlertScheduler.ensureScheduled();
    }
    return CardService.binding(CardService.saved());
  }

  onCastToNormalForm(formId: string): void {
    // Temporary cards aren't offered (form_config.json); nothing to do.
  }

  onUpdateForm(formId: string): void {
    AppContext.initBackground(this.context);
    refreshCard().catch((error: Object) => {
      hilog.warn(0x0000, 'Card', 'Update failed: %{public}s', JSON.stringify(error));
    });
  }

  onFormEvent(formId: string, message: string): void {
  }

  onRemoveForm(formId: string): void {
    AppContext.initBackground(this.context);
    CardService.removeForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
