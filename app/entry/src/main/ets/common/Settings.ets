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
const KEY_SEEN_AT: string = 'keyboardSeenAt';

/**
 * Defaults for the rewrite endpoint.
 *
 * These are defaults, not a lock-in: the settings screen exposes all three fields
 * and the engine only ever sees an `LlmTransport`. They point at the provider this
 * build is configured for, so that the only value a user must type on the device is
 * the secret itself, which is the part that must never live in the repository.
 *
 * Groq serves an OpenAI-compatible API, so supporting it required no change to the
 * transport at all - which is the interface paying for itself.
 */
export const DEFAULT_BASE_URL: string = 'https://api.groq.com/openai/v1';
export const DEFAULT_MODEL: string = 'openai/gpt-oss-120b';

export class BridgeSettings {
  baseUrl: string = DEFAULT_BASE_URL;
  model: string = DEFAULT_MODEL;
  apiKey: string = '';
  /**
   * False when the preferences store could not be opened at all.
   *
   * This is deliberately distinct from an empty key: an unreadable store and an
   * unconfigured one look identical from the outside, and conflating them cost
   * real debugging time. The keyboard reports them differently.
   */
  readOk: boolean = true;
  /**
   * The directory this context resolved preferences to.
   *
   * Kept because an input method extension and a UIAbility can resolve different
   * directories inside the same bundle, and the only way to see that is to print
   * it. Reported in the UI rather than buried in a log.
   */
  preferencesDir: string = '';

  /** True when there is enough configuration to attempt a remote rewrite. */
  isConfigured(): boolean {
    return this.apiKey.trim().length > 0 && this.baseUrl.trim().length > 0;
  }

  /**
   * Record that the keyboard successfully opened the store, and when.
   *
   * This exists because an input method extension and a UIAbility in the same
   * bundle, with the same UID and the same reported preferences directory, were
   * observed to disagree about the store's contents. Writing a value from the
   * keyboard and reading it from the settings screen is the only way to tell
   * "shared store, unexpected content" apart from "different sandbox entirely".
   * It doubles as a user-facing answer to "can the keyboard see my settings?".
   */
  static markSeen(context: common.Context, value: string): void {
    const options: preferences.Options = { name: STORE_NAME };
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(KEY_SEEN_AT, value);
      store.flush();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'markSeen failed: %{public}s', error.message);
    }
  }

  /** The last value written by the keyboard, as seen from this context. */
  static readSeenAt(context: common.Context): string {
    const options: preferences.Options = { name: STORE_NAME };
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return String(store.getSync(KEY_SEEN_AT, 'never'));
    } catch (err) {
      return 'unreadable';
    }
  }

  static read(context: common.Context): BridgeSettings {
    const options: preferences.Options = { name: STORE_NAME };
    const settings: BridgeSettings = new BridgeSettings();
    try {
      settings.preferencesDir = context.preferencesDir;
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      settings.baseUrl = store.getSync(KEY_BASE_URL, DEFAULT_BASE_URL) as string;
      settings.model = store.getSync(KEY_MODEL, DEFAULT_MODEL) as string;
      settings.apiKey = store.getSync(KEY_API_KEY, '') as string;
    } catch (err) {
      // Falling back to defaults is correct here: an unreadable store must not
      // prevent the keyboard from starting. But it must not masquerade as "no key
      // configured" either, so the failure is recorded and surfaced.
      settings.readOk = false;
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
