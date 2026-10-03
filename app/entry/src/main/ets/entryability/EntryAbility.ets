/**
 * Application entry ability: the Bridge settings and diagnostics screen.
 *
 * This is where the API key is entered. The key is stored in device preferences
 * and is never written to the repository, never logged and never put in a URL.
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from '../inputmethod/Log';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Home')
      .catch((err: Error): void => {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', err.message);
      });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }
}
