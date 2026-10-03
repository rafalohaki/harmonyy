/**
 * Device-local settings for the rewrite engine.
 *
 * The API key is entered on the device and kept in preferences. It is not
 * compiled into the package (a key inside a HAP can be extracted from it) and it
 * is not written to this repository (a key committed to a public repo is leaked
 * by definition).
 */

import { preferences } from '@kit.ArkData';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { common } from '@kit.AbilityKit';

import { TAG, DOMAIN } from './Log';

const STORE_NAME: string = 'bridge_settings';
const KEY_BASE_URL: string = 'baseUrl';
const KEY_MODEL: string = 'model';
const KEY_API_KEY: string = 'apiKey';

export const DEFAULT_BASE_URL: string = 'https://api.openai.com/v1';
export const DEFAULT_MODEL: string = 'gpt-4o-mini';

export class BridgeSettings {
  baseUrl: string = DEFAULT_BASE_URL;
  model: string = DEFAULT_MODEL;
  apiKey: string = '';

  /** True when there is enough configuration to attempt a remote rewrite. */
  isConfigured(): boolean {
    return this.apiKey.trim().length > 0 && this.baseUrl.trim().length > 0;
  }

  static read(context: common.Context): BridgeSettings {
    const options: preferences.Options = { name: STORE_NAME };
    const settings: BridgeSettings = new BridgeSettings();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      settings.baseUrl = store.getSync(KEY_BASE_URL, DEFAULT_BASE_URL) as string;
      settings.model = store.getSync(KEY_MODEL, DEFAULT_MODEL) as string;
      settings.apiKey = store.getSync(KEY_API_KEY, '') as string;
    } catch (err) {
      // Falling back to defaults is correct here: an unreadable store must not
      // prevent the keyboard from starting.
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'settings read failed, using defaults: %{public}s', error.message);
    }
    return settings;
  }

  static write(context: common.Context, settings: BridgeSettings): void {
    const options: preferences.Options = { name: STORE_NAME };
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(KEY_BASE_URL, settings.baseUrl);
      store.putSync(KEY_MODEL, settings.model);
      store.putSync(KEY_API_KEY, settings.apiKey);
      store.flush()
        .then((): void => {
          hilog.info(DOMAIN, TAG, 'settings saved');
        })
        .catch((err: BusinessError): void => {
          hilog.error(DOMAIN, TAG, 'settings save failed: %{public}s', err.message);
        });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'settings store unavailable: %{public}s', error.message);
    }
  }
}
