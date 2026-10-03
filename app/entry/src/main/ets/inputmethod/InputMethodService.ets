/**
 * Bridge input method extension.
 *
 * The lifecycle callbacks required by InputMethodExtensionAbility. All real work
 * lives in KeyboardController so that the ability stays a thin entry point.
 */

import { InputMethodExtensionAbility } from '@kit.IMEKit';
import type { InputMethodExtensionContext } from '@kit.IMEKit';
import type { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { keyboardController } from './KeyboardController';
import { TAG, DOMAIN } from '../common/Log';

export default class InputMethodService extends InputMethodExtensionAbility {
  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate: %{public}s', want.abilityName);
    keyboardController.onCreate(this.context as InputMethodExtensionContext);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
    keyboardController.onDestroy();
  }
}
