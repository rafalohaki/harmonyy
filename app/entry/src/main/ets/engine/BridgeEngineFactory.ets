/**
 * Builds a RewriteEngine for the input method extension.
 *
 * The keyboard extension runs in its own process without the ability's UI, so it
 * reads settings through its own context rather than sharing state with the
 * settings screen. Preferences are the shared store.
 */

import type { common } from '@kit.AbilityKit';

import type { EngineOptions } from '../core/engine';
import { DEFAULT_OPTIONS, RewriteEngine } from '../core/engine';
import { ArkHttpTransport } from '../net/ArkHttpTransport';
import { BridgeSettings } from '../common/Settings';

export class BridgeEngineFactory {
  /** A clock, injected so the engine's latency measurement stays testable. */
  private static clock(): number {
    return Date.now();
  }

  static create(context: common.Context): RewriteEngine {
    const settings: BridgeSettings = BridgeSettings.read(context);
    const transport: ArkHttpTransport = new ArkHttpTransport(
      settings.baseUrl, settings.model, settings.apiKey);
    const options: EngineOptions = DEFAULT_OPTIONS;
    return new RewriteEngine(transport, options, BridgeEngineFactory.clock);
  }

  /** True when a remote attempt has any chance of succeeding. */
  static isConfigured(context: common.Context): boolean {
    return BridgeSettings.read(context).isConfigured();
  }
}
