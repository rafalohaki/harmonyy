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
  /** When on, the keyboard never contacts the network at all. */
  @State offlineOnly: boolean = false;
  /** Answers the keyboard's request for the configuration. */
  private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  /** Send the current configuration to the keyboard. See SettingsBus for why. */
  private publish(): void {
    const settings: BridgeSettings = new BridgeSettings();
    settings.baseUrl = this.baseUrl;
    settings.model = this.model;
    settings.apiKey = this.apiKey;
    settings.offlineOnly = this.offlineOnly;
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
    this.offlineOnly = loaded.offlineOnly;
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
    settings.offlineOnly = this.offlineOnly;
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

      // Each field has an explicit clear control. Without one there was no way to
      // replace a value, only to append to it, which made it impossible to point
      // the keyboard at a different endpoint - including a deliberately
      // unreachable one, which is how the offline fallback is demonstrated.
      Row({ space: 8 }) {
        TextInput({ text: this.baseUrl, placeholder: 'Base URL' })
          .layoutWeight(1)
          .onChange((value: string) => { this.baseUrl = value; })
        Button('Clear')
          .width(84)
          .onClick(() => { this.baseUrl = ''; })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.model, placeholder: 'Model' })
          .layoutWeight(1)
          .onChange((value: string) => { this.model = value; })
        Button('Clear')
          .width(84)
          .onClick(() => { this.model = ''; })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.apiKey, placeholder: 'API key' })
          .type(InputType.Password)
          .layoutWeight(1)
          .onChange((value: string) => { this.apiKey = value; })
        Button('Clear')
          .width(84)
          .onClick(() => { this.apiKey = ''; })
      }
      .width('100%')

      Button('Save')
        .width('100%')
        .onClick(() => this.save())

      Row({ space: 8 }) {
        Text('Offline only — never contact the network')
          .fontSize(13)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.offlineOnly })
          .onChange((isOn: boolean) => { this.offlineOnly = isOn; })
      }
      .width('100%')

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


      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
  }
}
