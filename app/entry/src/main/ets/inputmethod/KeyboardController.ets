/**
 * KeyboardController — the bridge between the system input method framework and
 * our UI.
 *
 * Every platform call in this file was verified against the type declarations in
 * the Full OpenHarmony SDK for API 23 (`ets/api/@ohos.inputMethodEngine.d.ts`,
 * `@ohos.inputMethod.Panel.d.ts`, `@ohos.InputMethodExtensionAbility.d.ts`)
 * before it was written, not recalled from documentation examples. Two findings
 * from that verification are worth recording, because both are compile errors that
 * a plausible-looking sample would have introduced:
 *
 *   1. There is no `inputMethodAbility` symbol anywhere in the API 23 or 24
 *      declarations. The panel and event APIs are methods of the
 *      `InputMethodAbility` interface, obtained with
 *      `inputMethodEngine.getInputMethodAbility()`.
 *   2. `off('inputStop', callback)` requires the callback, while
 *      `off('inputStart', callback?)` does not. The reference must be kept.
 *   3. `PanelInfo`, `PanelType` and `PanelFlag` are declared twice, once in
 *      `@ohos.inputMethod.Panel` and once inside the `inputMethodEngine`
 *      namespace. Only the second is accepted by `createPanel`, and the two
 *      disagree on enum spelling (`FLG_FIXED` versus `FLAG_FIXED`). This one was
 *      caught by the ArkTS compiler, not by reading, which is the point of
 *      building early.
 *
 * SCOPE NOTE: this file deliberately contains no AI or engine code. The first
 * milestone is proving that a third-party input method can attach to another
 * application's text field and write into it.
 */

import { inputMethodEngine } from '@kit.IMEKit';
import type { InputMethodExtensionContext } from '@kit.IMEKit';
import { display } from '@kit.ArkUI';
import { commonEventManager } from '@kit.BasicServicesKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from '../common/Log';
import type { RewriteMode, RewriteOutcome, RewriteRequest } from '../core/contracts';
import type { EngineBuild } from '../engine/BridgeEngineFactory';
import { BridgeEngineFactory } from '../engine/BridgeEngineFactory';
import { BridgeSettings } from '../common/Settings';
import { EVENT_SETTINGS_CHANGED, decodeSettings, requestSettings } from '../common/SettingsBus';

/** Keyboard height as a fraction of the display. */
const KEYBOARD_HEIGHT_RATIO: number = 0.46;

/** Keys published to AppStorage so the ArkUI page can render state. */
export const KEY_ATTACHED: string = 'bridgeAttached';
export const KEY_FIELD_TEXT: string = 'bridgeFieldText';
export const KEY_STATUS: string = 'bridgeStatus';

export class KeyboardController {
  private context: InputMethodExtensionContext | undefined = undefined;
  private ability: inputMethodEngine.InputMethodAbility | undefined = undefined;
  private panel: inputMethodEngine.Panel | undefined = undefined;
  private inputClient: inputMethodEngine.InputClient | undefined = undefined;
  private keyboardDelegate: inputMethodEngine.KeyboardDelegate | undefined = undefined;
  /** Kept because off('inputStop') requires the exact callback reference. */
  private inputStopCallback: (() => void) | undefined = undefined;
  private fieldText: string = '';
  /** Best-effort name of the hosting app, used to pick a register. */
  private contextHint: string = '';
  /** Configuration received over the event channel; see SettingsBus for why. */
  private liveSettings: BridgeSettings | undefined = undefined;
  private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  onCreate(context: InputMethodExtensionContext): void {
    this.context = context;
    try {
      this.ability = inputMethodEngine.getInputMethodAbility();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'getInputMethodAbility failed: %{public}s', error.message);
      this.publishState(false, '', 'not an input method application');
      return;
    }
    // The engine is deliberately NOT built here. See rewrite().
    this.subscribeToSettings();
    this.publishState(false, '', 'keyboard created');
    this.createPanel();
    this.registerListeners();
  }

  onDestroy(): void {
    this.unregisterListeners();
    this.destroyPanel();
    const subscriber: commonEventManager.CommonEventSubscriber | undefined = this.subscriber;
    if (subscriber !== undefined) {
      commonEventManager.unsubscribe(subscriber);
      this.subscriber = undefined;
    }
    this.context = undefined;
    this.ability = undefined;
  }

  /**
   * Listen for the configuration sent by the settings screen.
   *
   * This is the only working channel: the extension does not share the ability's
   * preferences store even though both report the same directory. See SettingsBus.
   */
  private subscribeToSettings(): void {
    try {
      const info: commonEventManager.CommonEventSubscribeInfo = {
        events: [EVENT_SETTINGS_CHANGED]
      };
      this.subscriber = commonEventManager.createSubscriberSync(info);
      commonEventManager.subscribe(this.subscriber,
        (err: BusinessError, data: commonEventManager.CommonEventData): void => {
          if (err) {
            hilog.warn(DOMAIN, TAG, 'settings event error: %{public}s', err.message);
            return;
          }
          const decoded: BridgeSettings | undefined = decodeSettings(data.data);
          if (decoded !== undefined) {
            this.liveSettings = decoded;
            hilog.info(DOMAIN, TAG, 'settings received from the settings screen');
            this.publishState(this.isAttached(), this.fieldText, 'settings received');
          }
        });
      // The configuration may have been saved before this process started.
      requestSettings();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'could not subscribe to settings: %{public}s', error.message);
    }
  }

  /** Create the soft keyboard panel and load our UI into it. */
  private createPanel(): void {
    const ability: inputMethodEngine.InputMethodAbility | undefined = this.ability;
    const context: InputMethodExtensionContext | undefined = this.context;
    if (ability === undefined || context === undefined) {
      return;
    }

    // PanelInfo/PanelType/PanelFlag exist TWICE in this SDK: once in
    // @ohos.inputMethod.Panel (re-exported by @kit.IMEKit) and once inside the
    // inputMethodEngine namespace. They are structurally similar but NOT
    // interchangeable - the compiler rejects one where the other is expected - and
    // createPanel wants the engine's. Their enum members also differ in spelling:
    // the engine uses FLG_FIXED, the Panel module uses FLAG_FIXED.
    const panelInfo: inputMethodEngine.PanelInfo = {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: inputMethodEngine.PanelFlag.FLG_FIXED
    };

    ability.createPanel(context, panelInfo)
      .then((panel: inputMethodEngine.Panel): Promise<void> => {
        this.panel = panel;
        const info: display.Display = display.getDefaultDisplaySync();
        const height: number = Math.round(info.height * KEYBOARD_HEIGHT_RATIO);
        return panel.resize(info.width, height);
      })
      .then((): Promise<void> => {
        const panel: inputMethodEngine.Panel | undefined = this.panel;
        if (panel === undefined) {
          return Promise.resolve();
        }
        return panel.setUiContent('inputmethod/pages/Index');
      })
      .then((): void => {
        this.publishState(this.inputClient !== undefined, this.fieldText, 'keyboard ready');
      })
      .catch((err: BusinessError): void => {
        // A failure here is the difference between a working keyboard and a blank
        // strip, so it is logged with the full error rather than swallowed.
        hilog.error(DOMAIN, TAG, 'panel setup failed: %{public}d %{public}s',
          err.code, err.message);
        this.publishState(false, '', 'panel setup failed: ' + err.code);
      });
  }

  private destroyPanel(): void {
    const ability: inputMethodEngine.InputMethodAbility | undefined = this.ability;
    const panel: inputMethodEngine.Panel | undefined = this.panel;
    if (ability === undefined || panel === undefined) {
      this.panel = undefined;
      return;
    }
    ability.destroyPanel(panel)
      .then((): void => {
        hilog.info(DOMAIN, TAG, 'panel destroyed');
      })
      .catch((err: BusinessError): void => {
        hilog.error(DOMAIN, TAG, 'destroyPanel failed: %{public}s', err.message);
      });
    this.panel = undefined;
  }

  private registerListeners(): void {
    const ability: inputMethodEngine.InputMethodAbility | undefined = this.ability;
    if (ability === undefined) {
      return;
    }

    ability.on('inputStart',
      (kbController: inputMethodEngine.KeyboardController,
        client: inputMethodEngine.InputClient): void => {
        this.inputClient = client;
        this.refreshFieldText();
        hilog.info(DOMAIN, TAG, 'inputStart: editor attached');
        this.publishState(true, this.fieldText, 'editor attached');
      });

    const stopCallback: () => void = (): void => {
      this.inputClient = undefined;
      hilog.info(DOMAIN, TAG, 'inputStop: editor detached');
      this.publishState(false, this.fieldText, 'editor detached');
    };
    this.inputStopCallback = stopCallback;
    ability.on('inputStop', stopCallback);

    // EditorAttribute.bundleName (API 14+) tells us which application owns the
    // focused field. That is the contextual signal the prompt uses to match the
    // register: a message to a friend and an e-mail to an office are not the same
    // text, even when the words are.
    this.keyboardDelegate = inputMethodEngine.getKeyboardDelegate();
    this.keyboardDelegate.on('editorAttributeChanged',
      (attr: inputMethodEngine.EditorAttribute): void => {
        this.contextHint = describeHost(attr.bundleName);
        hilog.info(DOMAIN, TAG, 'editor attribute changed, host hint: %{public}s',
          this.contextHint);
      });
  }

  private unregisterListeners(): void {
    const ability: inputMethodEngine.InputMethodAbility | undefined = this.ability;
    if (ability !== undefined) {
      ability.off('inputStart');
      const stopCallback: (() => void) | undefined = this.inputStopCallback;
      if (stopCallback !== undefined) {
        ability.off('inputStop', stopCallback);
        this.inputStopCallback = undefined;
      }
    }

    const delegate: inputMethodEngine.KeyboardDelegate | undefined = this.keyboardDelegate;
    if (delegate !== undefined) {
      delegate.off('editorAttributeChanged');
      this.keyboardDelegate = undefined;
    }
  }

  /**
   * Read the text before the cursor so a rewrite has something to work on.
   *
   * NAMING TRAP, verified against two independent sources before relying on it:
   * "Forward" here means *before* the cursor and "Backward" means *after* it,
   * which is the opposite of what the English names suggest. The SDK's own
   * declaration comments do not state the direction, so the evidence is the
   * Chinese reference (the source of the English translation, which says the same
   * thing) and the official IME sample, which maps KEYCODE_DEL — the backspace
   * key — to deleteForward(1) and KEYCODE_FORWARD_DEL to deleteBackward(1).
   * Using the intuitive reading would have made the rewrite append text instead
   * of replacing it.
   */
  private refreshFieldText(): void {
    const client: inputMethodEngine.InputClient | undefined = this.inputClient;
    if (client === undefined) {
      this.fieldText = '';
      return;
    }
    try {
      const cursor: number = client.getTextIndexAtCursorSync();
      this.fieldText = cursor > 0 ? client.getForwardSync(cursor) : '';
    } catch (err) {
      // Reading the field is best-effort: some editors do not expose it.
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'refreshFieldText failed: %{public}s', error.message);
      this.fieldText = '';
    }
  }

  /** Public accessor used by the keyboard UI. */
  getFieldText(): string {
    this.refreshFieldText();
    return this.fieldText;
  }

  /** True when an editor is attached and text can be written. */
  isAttached(): boolean {
    return this.inputClient !== undefined;
  }

  /** Append text at the cursor. The first thing that must work on the emulator. */
  insertText(text: string): boolean {
    const client: inputMethodEngine.InputClient | undefined = this.inputClient;
    if (client === undefined) {
      this.publishState(false, this.fieldText, 'no editor attached');
      return false;
    }
    try {
      client.insertTextSync(text);
      this.fieldText = this.fieldText + text;
      this.publishState(true, this.fieldText, 'inserted ' + text.length + ' characters');
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'insertTextSync failed: %{public}s', error.message);
      this.publishState(true, this.fieldText, 'insert failed: ' + error.code);
      return false;
    }
  }

  /**
   * Replace everything before the cursor with new text.
   * This is the operation the rewrite modes rely on.
   *
   * deleteForwardSync removes text *before* the cursor (see the naming trap noted
   * on refreshFieldText). The cursor index is exactly the number of characters
   * before the cursor, so deleting that many removes precisely the text that was
   * read, and the subsequent insert lands where the original started.
   *
   * Known limitation, stated rather than hidden: text *after* the cursor is left
   * alone, so with the cursor mid-field the rewrite covers the prefix only.
   */
  replaceBeforeCursor(text: string): boolean {
    const client: inputMethodEngine.InputClient | undefined = this.inputClient;
    if (client === undefined) {
      this.publishState(false, this.fieldText, 'no editor attached');
      return false;
    }
    try {
      const cursor: number = client.getTextIndexAtCursorSync();
      if (cursor > 0) {
        client.deleteForwardSync(cursor);
      }
      client.insertTextSync(text);
      this.fieldText = text;
      this.publishState(true, this.fieldText, 'replaced ' + cursor + ' characters');
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'replaceBeforeCursor failed: %{public}s', error.message);
      this.publishState(true, this.fieldText, 'replace failed: ' + error.code);
      return false;
    }
  }

  /**
   * Run the rewrite engine for one mode.
   *
   * The engine never throws for an expected failure: it answers with either the
   * model's variants or the offline engine's, plus a reason. That reason is shown
   * verbatim on the keyboard, so a degraded answer is never presented as a normal
   * one.
   */
  async rewrite(mode: RewriteMode, tokens: string[]): Promise<RewriteOutcome> {
    const request: RewriteRequest = {
      text: this.getFieldText(),
      mode: mode,
      contextHint: this.contextHint,
      locale: 'pl-PL',
      tokens: tokens
    };

    const context: InputMethodExtensionContext | undefined = this.context;
    if (context === undefined) {
      return {
        variants: [],
        source: 'local',
        fallbackReason: 'The keyboard has no context yet.',
        redactedCount: 0,
        latencyMs: 0
      };
    }

    // Built per rewrite on purpose. The engine used to be built once in onCreate,
    // which cached whatever the API key was at that moment, so a user who
    // configured the keyboard afterwards saw the offline path with no explanation.
    // Found by testing on the emulator, not by reading the code.
    //
    // Prefer the configuration that arrived over the event channel: this context's
    // own preferences read returns an empty store (see SettingsBus).
    const live: BridgeSettings | undefined = this.liveSettings;
    const build: EngineBuild = (live !== undefined && live.isConfigured())
      ? BridgeEngineFactory.fromSettings(live)
      : BridgeEngineFactory.build(context);
    const outcome: RewriteOutcome = await build.engine.rewrite(request);

    if (outcome.source === 'local') {
      // Say which failure this is. An unreadable store and an unset key look
      // identical from the outside, and conflating them wasted real debugging time.
      if (!build.readOk) {
        outcome.fallbackReason = 'device settings could not be read';
      } else if (!build.configured) {
        outcome.fallbackReason = 'no API key set on this device';
      }
    }

    // The status line is written for the person using the keyboard, not for the
    // person who wrote it. It says what happened, how long it took, and whether
    // anything personal left the device, instead of reporting a latency and a
    // counter whose meaning is private to the code.
    let status: string = '';
    if (outcome.source === 'remote') {
      const seconds: string = (Math.round(outcome.latencyMs / 100) / 10).toFixed(1);
      const count: number = outcome.redactedCount;
      const privacy: string = count > 0
        ? count + (count === 1 ? ' personal item' : ' personal items') + ' stayed on this device'
        : 'nothing personal left this device';
      status = 'Rewritten by the model in ' + seconds + ' s — ' + privacy;
    } else {
      status = 'Offline: ' + outcome.fallbackReason.charAt(0).toUpperCase() + outcome.fallbackReason.slice(1);
    }
    this.publishState(this.isAttached(), this.fieldText, status);
    return outcome;
  }

  private publishState(attached: boolean, text: string, status: string): void {
    AppStorage.setOrCreate(KEY_ATTACHED, attached);
    AppStorage.setOrCreate(KEY_FIELD_TEXT, text);
    AppStorage.setOrCreate(KEY_STATUS, status);
  }
}

/** Single instance shared by the extension ability and the keyboard page. */
export const keyboardController: KeyboardController = new KeyboardController();

/**
 * Turn a bundle name into a register hint for the prompt.
 *
 * This is a small, honest heuristic, not a classifier. The declaration marks
 * `bundleName` as optional and the documentation warns it may be an empty string,
 * so both cases are handled explicitly, and an unrecognised bundle is passed
 * through rather than guessed at: a raw package name is still a useful signal to
 * the model, whereas a wrong friendly label would not be.
 */
export function describeHost(bundleName: string | undefined): string {
  if (bundleName === undefined || bundleName.length === 0) {
    return '';
  }
  const name: string = bundleName.toLowerCase();
  if (name.includes('mms') || name.includes('sms') || name.includes('messag')) {
    return 'a casual messaging app (' + bundleName + ')';
  }
  if (name.includes('mail') || name.includes('email')) {
    return 'an e-mail client, so a more formal register fits (' + bundleName + ')';
  }
  if (name.includes('note') || name.includes('memo')) {
    return 'a note-taking app (' + bundleName + ')';
  }
  if (name.includes('browser') || name.includes('webview')) {
    return 'a web page (' + bundleName + ')';
  }
  if (name.includes('setting')) {
    return 'the system settings app (' + bundleName + ')';
  }
  return bundleName;
}
