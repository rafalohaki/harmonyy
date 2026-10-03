/**
 * Builds a RewriteEngine for the input method extension, together with the facts
 * the keyboard needs in order to explain itself.
 *
 * Two lessons are baked into this shape:
 *
 *  1. The engine must be built per rewrite, not once per extension lifetime.
 *     Built once in onCreate, it caches whatever the API key was at that moment,
 *     so a user who configures the keyboard afterwards sees the offline path with
 *     no explanation. Found by testing on the emulator, not by reading code.
 *  2. "The store could not be read" and "no key has been set" are different
 *     failures that look identical from the outside. They are returned separately
 *     so the keyboard can say which one happened.
 */

import type { common } from '@kit.AbilityKit';

import type { EngineOptions } from '../core/engine';
import { DEFAULT_OPTIONS, RewriteEngine } from '../core/engine';
import { ArkHttpTransport } from '../net/ArkHttpTransport';
import { BridgeSettings } from '../common/Settings';

/** What a build attempt produced, and why. */
export class EngineBuild {
  engine: RewriteEngine;
  /** True when a key is present, so a remote attempt has a chance. */
  configured: boolean;
  /** False when the preferences store could not be opened at all. */
  readOk: boolean;
  /** The endpoint that was read, for diagnostics. */
  baseUrl: string;
  /** The directory this context resolved preferences to, for diagnostics. */
  preferencesDir: string;

  constructor(engine: RewriteEngine, configured: boolean, readOk: boolean, baseUrl: string,
    preferencesDir: string) {
    this.engine = engine;
    this.configured = configured;
    this.readOk = readOk;
    this.baseUrl = baseUrl;
    this.preferencesDir = preferencesDir;
  }
}

export class BridgeEngineFactory {
  /** A clock, injected so the engine's latency measurement stays testable. */
  private static clock(): number {
    return Date.now();
  }

  /**
   * Read the current settings and build an engine around them.
   * Cheap enough to call per rewrite, which is exactly the point.
   */
  static build(context: common.Context): EngineBuild {
    const settings: BridgeSettings = BridgeSettings.read(context);
    // Leave a trace that this context could write, so the settings screen can show
    // whether the keyboard sees the same store. (It does not: see SettingsBus.)
    BridgeSettings.markSeen(context, String(Date.now()));
    return BridgeEngineFactory.fromSettings(settings);
  }

  /**
   * Build from settings that arrived over the event channel rather than from this
   * context's own store. This is the path the keyboard normally uses.
   */
  static fromSettings(settings: BridgeSettings): EngineBuild {
    const transport: ArkHttpTransport = new ArkHttpTransport(
      settings.baseUrl, settings.model, settings.apiKey);
    const options: EngineOptions = {
      timeoutMs: DEFAULT_OPTIONS.timeoutMs,
      maxAttempts: DEFAULT_OPTIONS.maxAttempts,
      limits: DEFAULT_OPTIONS.limits,
      redactionEnabled: DEFAULT_OPTIONS.redactionEnabled,
      // A user-facing promise: with this on, the engine returns before it can
      // construct a request, so no network call is possible even if the endpoint
      // and the key are both configured.
      forceOffline: settings.offlineOnly
    };
    const engine: RewriteEngine = new RewriteEngine(transport, options, BridgeEngineFactory.clock);
    return new EngineBuild(engine, settings.isConfigured(), settings.readOk, settings.baseUrl,
      settings.preferencesDir);
  }
}
