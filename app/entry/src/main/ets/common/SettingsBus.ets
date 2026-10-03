/**
 * Carries the rewrite configuration from the settings screen to the keyboard.
 *
 * WHY THIS EXISTS, and it is not a design preference:
 *
 * The input method extension and the settings UIAbility live in the same bundle,
 * run under the same UID, and both report the SAME preferences directory
 * (/data/storage/el2/base/haps/entry/preferences). They do not share its
 * contents. This was established experimentally: the keyboard wrote a marker into
 * the store, the ability cold-started and still read nothing. The extension
 * therefore runs in its own sandbox view of that path, and any file-based channel
 * fails silently.
 *
 * So the configuration crosses the boundary explicitly, as a common event. The
 * keyboard keeps whatever it last received in memory, and still falls back to its
 * own preferences read if no event has arrived yet.
 *
 * The settings are published when the screen saves them and when it appears, and
 * the keyboard asks for them when it starts, so a keyboard that starts after the
 * settings were saved still gets them.
 */

import { commonEventManager } from '@kit.BasicServicesKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from './Log';
import { BridgeSettings } from './Settings';

/** Published by the settings screen whenever the configuration is (re)sent. */
export const EVENT_SETTINGS_CHANGED: string = 'com.bridge.ime.SETTINGS_CHANGED';
/** Published by the keyboard to ask for the configuration. */
export const EVENT_SETTINGS_REQUEST: string = 'com.bridge.ime.SETTINGS_REQUEST';

const BUNDLE_NAME: string = 'com.bridge.ime';

/** The subset of settings the keyboard needs. The secret travels only here. */
interface SettingsDto {
  baseUrl?: string;
  model?: string;
  apiKey?: string;
}

/** Serialise for the wire. Deliberately explicit rather than reflection. */
export function encodeSettings(settings: BridgeSettings): string {
  const dto: SettingsDto = {
    baseUrl: settings.baseUrl,
    model: settings.model,
    apiKey: settings.apiKey
  };
  return JSON.stringify(dto);
}

/** Parse a payload, or return undefined if it is not usable. */
export function decodeSettings(payload: string | undefined): BridgeSettings | undefined {
  // CommonEventData.data is declared optional, so this is a real case, not a
  // defensive nicety.
  if (payload === undefined || payload.length === 0) {
    return undefined;
  }
  try {
    const dto: SettingsDto = JSON.parse(payload) as SettingsDto;
    const settings: BridgeSettings = new BridgeSettings();
    if (dto.baseUrl !== undefined && dto.baseUrl.length > 0) {
      settings.baseUrl = dto.baseUrl;
    }
    if (dto.model !== undefined && dto.model.length > 0) {
      settings.model = dto.model;
    }
    if (dto.apiKey !== undefined) {
      settings.apiKey = dto.apiKey;
    }
    return settings;
  } catch (err) {
    hilog.warn(DOMAIN, TAG, 'settings payload was not usable');
    return undefined;
  }
}

/**
 * Send the configuration to whoever is listening.
 *
 * The options overload of publish takes a callback and has no Promise form, so the
 * callback is the success path, not a fallback.
 */
export function publishSettings(settings: BridgeSettings): void {
  const options: commonEventManager.CommonEventPublishData = {
    bundleName: BUNDLE_NAME,
    code: 0,
    data: encodeSettings(settings)
  };
  commonEventManager.publish(EVENT_SETTINGS_CHANGED, options, (err: BusinessError): void => {
    if (err) {
      hilog.error(DOMAIN, TAG, 'settings publish failed: %{public}s', err.message);
    } else {
      hilog.info(DOMAIN, TAG, 'settings published to the keyboard');
    }
  });
}

/** Ask the settings screen to send the configuration again. */
export function requestSettings(): void {
  const options: commonEventManager.CommonEventPublishData = {
    bundleName: BUNDLE_NAME,
    code: 0,
    data: ''
  };
  commonEventManager.publish(EVENT_SETTINGS_REQUEST, options, (err: BusinessError): void => {
    if (err) {
      hilog.warn(DOMAIN, TAG, 'settings request failed: %{public}s', err.message);
    }
  });
}
