/**
 * KeyboardController — the bridge between the system input method framework and
 * our UI.
 *
 * Verified against OpenHarmony's IME Kit documentation before writing:
 *   - inputMethodAbility.createPanel(context, panelInfo) -> Panel
 *   - panel.resize(w, h) and panel.setUiContent('inputmethod/pages/Index')
 *   - inputMethodAbility.on('inputStart', (kbController, inputClient) => ...)
 *   - inputMethodAbility.on('inputStop', () => ...)
 *   - InputClient: insertTextSync / deleteBackwardSync / getTextIndexAtCursorSync
 *     / getBackwardSync, reached through the InputMethodEngine
 *
 * SCOPE NOTE: this file deliberately contains no AI or engine code. The first
 * milestone is proving that a third-party input method can attach to another
 * application's text field and write into it. Wiring the rewrite engine in is the
 * next step, once this is observed working on the emulator.
 */

import { inputMethodAbility } from '@kit.IMEKit';
import type { inputMethodEngine, InputMethodExtensionContext } from '@kit.IMEKit';
import { display } from '@kit.ArkUI';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from './Log';

/** Keyboard height as a fraction of the display. */
const KEYBOARD_HEIGHT_RATIO: number = 0.34;

/** Keys published to AppStorage so the ArkUI page can render state. */
export const KEY_ATTACHED: string = 'bridgeAttached';
export const KEY_FIELD_TEXT: string = 'bridgeFieldText';
export const KEY_STATUS: string = 'bridgeStatus';

export class KeyboardController {
  private context: InputMethodExtensionContext | undefined = undefined;
  private panel: inputMethodEngine.Panel | undefined = undefined;
  private inputClient: inputMethodEngine.InputClient | undefined = undefined;
  private fieldText: string = '';

  onCreate(context: InputMethodExtensionContext): void {
    this.context = context;
    this.publishState(false, '', 'keyboard created');
    this.createPanel();
    this.registerListeners();
  }

  onDestroy(): void {
    this.unregisterListeners();
    this.destroyPanel();
    this.context = undefined;
  }

  /** Create the soft keyboard panel and load our UI into it. */
  private createPanel(): void {
    const context: InputMethodExtensionContext | undefined = this.context;
    if (context === undefined) {
      return;
    }

    const panelInfo: inputMethodEngine.PanelInfo = {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: inputMethodEngine.PanelFlag.FLG_FIXED
    };

    inputMethodAbility.createPanel(context, panelInfo)
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
    const panel: inputMethodEngine.Panel | undefined = this.panel;
    if (panel === undefined) {
      return;
    }
    inputMethodAbility.destroyPanel(panel)
      .then((): void => {
        hilog.info(DOMAIN, TAG, 'panel destroyed');
      })
      .catch((err: BusinessError): void => {
        hilog.error(DOMAIN, TAG, 'destroyPanel failed: %{public}s', err.message);
      });
    this.panel = undefined;
  }

  private registerListeners(): void {
    inputMethodAbility.on('inputStart',
      (kbController: inputMethodEngine.KeyboardController,
        client: inputMethodEngine.InputClient): void => {
        this.inputClient = client;
        this.refreshFieldText();
        hilog.info(DOMAIN, TAG, 'inputStart: editor attached');
        this.publishState(true, this.fieldText, 'editor attached');
      });

    inputMethodAbility.on('inputStop', (): void => {
      this.inputClient = undefined;
      hilog.info(DOMAIN, TAG, 'inputStop: editor detached');
      this.publishState(false, this.fieldText, 'editor detached');
    });
  }

  private unregisterListeners(): void {
    inputMethodAbility.off('inputStart');
    inputMethodAbility.off('inputStop');
  }

  /** Read the text before the cursor so a rewrite has something to work on. */
  private refreshFieldText(): void {
    const client: inputMethodEngine.InputClient | undefined = this.inputClient;
    if (client === undefined) {
      this.fieldText = '';
      return;
    }
    try {
      const cursor: number = client.getTextIndexAtCursorSync();
      this.fieldText = cursor > 0 ? client.getBackwardSync(cursor) : '';
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
        client.deleteBackwardSync(cursor);
      }
      client.insertTextSync(text);
      this.fieldText = text;
      this.publishState(true, this.fieldText, 'replaced');
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'replaceBeforeCursor failed: %{public}s', error.message);
      this.publishState(true, this.fieldText, 'replace failed: ' + error.code);
      return false;
    }
  }

  private publishState(attached: boolean, text: string, status: string): void {
    AppStorage.setOrCreate(KEY_ATTACHED, attached);
    AppStorage.setOrCreate(KEY_FIELD_TEXT, text);
    AppStorage.setOrCreate(KEY_STATUS, status);
  }
}

/** Single instance shared by the extension ability and the keyboard page. */
export const keyboardController: KeyboardController = new KeyboardController();
