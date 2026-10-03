/**
 * Bridge settings: where the OpenAI-compatible endpoint and the API key live.
 *
 * Design decision worth stating: the key is entered on the device and stored in
 * device preferences, not compiled in. A key bundled into a HAP is extractable
 * from the package, and a key committed to a public repository is leaked by
 * definition.
 *
 * The settings store itself lives in common/Settings.ets, because the input
 * method extension reads it too and must not import from a UI file.
 *
 * Verified against the API 23 declaration:
 *   UIContext.getHostContext(): Context | undefined
 * so the context is treated as possibly absent rather than assumed, and a missing
 * context produces a visible message instead of a blank screen.
 */

import type { common } from '@kit.AbilityKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from '../common/Log';
import { BridgeSettings, DEFAULT_BASE_URL, DEFAULT_MODEL } from '../common/Settings';
import { EVENT_SETTINGS_REQUEST, publishSettings } from '../common/SettingsBus';

@Entry
@Component
struct Home {
  @State baseUrl: string = DEFAULT_BASE_URL;
  @State model: string = DEFAULT_MODEL;
  @State apiKey: string = '';
  @State saved: string = '';
  /** Scratchpad so the keyboard can be tried without leaving the app. */
  @State draft: string = '';
  /** The directory this ability resolved preferences to; compared against the
   *  keyboard's own, which is shown in its status line. */
  @State preferencesDir: string = '';
  /** What the keyboard last wrote into the shared store, if it is shared. */
  @State keyboardSeenAt: string = 'never';
  /** Answers the keyboard's request for the configuration. */
  private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  /** Send the current configuration to the keyboard. See SettingsBus for why. */
  private publish(): void {
    const settings: BridgeSettings = new BridgeSettings();
    settings.baseUrl = this.baseUrl;
    settings.model = this.model;
    settings.apiKey = this.apiKey;
    publishSettings(settings);
  }

  aboutToDisappear(): void {
    const subscriber: commonEventManager.CommonEventSubscriber | undefined = this.subscriber;
    if (subscriber !== undefined) {
      commonEventManager.unsubscribe(subscriber);
      this.subscriber = undefined;
    }
  }

  private hostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  aboutToAppear(): void {
    const context: common.UIAbilityContext | undefined = this.hostContext();
    if (context === undefined) {
      this.saved = 'No host context available; settings cannot be loaded.';
      return;
    }
    const loaded: BridgeSettings = BridgeSettings.read(context);
    this.baseUrl = loaded.baseUrl;
    this.model = loaded.model;
    this.apiKey = loaded.apiKey;
    this.preferencesDir = context.preferencesDir;
    this.keyboardSeenAt = BridgeSettings.readSeenAt(context);
    // Send what we have, and answer future requests from the keyboard.
    this.publish();
    try {
      const info: commonEventManager.CommonEventSubscribeInfo = {
        events: [EVENT_SETTINGS_REQUEST]
      };
      this.subscriber = commonEventManager.createSubscriberSync(info);
      commonEventManager.subscribe(this.subscriber,
        (err: BusinessError, data: commonEventManager.CommonEventData): void => {
          if (err) {
            return;
          }
          hilog.info(DOMAIN, TAG, 'keyboard asked for settings; resending');
          this.publish();
        });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'could not listen for settings requests: %{public}s',
        error.message);
    }
  }

  private save(): void {
    const context: common.UIAbilityContext | undefined = this.hostContext();
    if (context === undefined) {
      this.saved = 'No host context available; nothing was saved.';
      return;
    }
    const settings: BridgeSettings = new BridgeSettings();
    settings.baseUrl = this.baseUrl;
    settings.model = this.model;
    settings.apiKey = this.apiKey;
    BridgeSettings.write(context, settings);
    this.saved = 'Saved on this device only. Nothing is written to the repository.';
    // Push it to the keyboard as well: it cannot read this store. See SettingsBus.
    this.publish();
  }

  build() {
    Column({ space: 12 }) {
      Text('Bridge')
        .fontSize(24)
        .fontColor('#1A1A1A')
      Text('A rewrite engine for every text field on this device.')
        .fontSize(13)
        .fontColor('#555555')

      TextInput({ text: this.baseUrl, placeholder: 'Base URL' })
        .onChange((value: string) => { this.baseUrl = value; })
      TextInput({ text: this.model, placeholder: 'Model' })
        .onChange((value: string) => { this.model = value; })
      TextInput({ text: this.apiKey, placeholder: 'API key' })
        .type(InputType.Password)
        .onChange((value: string) => { this.apiKey = value; })

      Button('Save')
        .width('100%')
        .onClick(() => this.save())

      Text('Try it here')
        .fontSize(13)
        .fontColor('#1A1A1A')
      TextArea({
        text: this.draft,
        placeholder: 'Type however you like, then use the Bridge keyboard below'
      })
        .height(110)
        .onChange((value: string) => { this.draft = value; })

      Text(this.saved)
        .fontSize(12)
        .fontColor('#2A5CDB')

      Text('Personal data is removed on this device before any text is sent, and ' +
        'put back afterwards. The keyboard tells you how many items were hidden.')
        .fontSize(12)
        .fontColor('#555555')

      Text('To use Bridge: enable it in Settings, then switch to it from the ' +
        'keyboard picker. scripts/enable-ime.sh does both from the command line.')
        .fontSize(12)
        .fontColor('#555555')

      Text('ability store: ' + this.preferencesDir)
        .fontSize(10)
        .fontColor('#888888')
      Text('keyboard saw settings at: ' + this.keyboardSeenAt)
        .fontSize(10)
        .fontColor('#888888')

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
  }
}
