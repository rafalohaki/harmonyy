/**
 * Bridge settings: where the OpenAI-compatible endpoint and the API key live.
 *
 * Design decision worth stating: the key is entered on the device and stored in
 * preferences, not compiled in. A key bundled into a HAP is extractable from the
 * package, and a key committed to a public repository is leaked by definition.
 */

import { preferences } from '@kit.ArkData';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

import { TAG, DOMAIN } from '../inputmethod/Log';

const STORE_NAME: string = 'bridge_settings';
const KEY_BASE_URL: string = 'baseUrl';
const KEY_MODEL: string = 'model';
const KEY_API_KEY: string = 'apiKey';

const DEFAULT_BASE_URL: string = 'https://api.openai.com/v1';
const DEFAULT_MODEL: string = 'gpt-4o-mini';

/** Typed access to device preferences. */
export class BridgeSettings {
  static read(context: common.UIAbilityContext): BridgeSettings {
    const options: preferences.Options = { name: STORE_NAME };
    const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
    const settings: BridgeSettings = new BridgeSettings();
    settings.baseUrl = store.getSync(KEY_BASE_URL, DEFAULT_BASE_URL) as string;
    settings.model = store.getSync(KEY_MODEL, DEFAULT_MODEL) as string;
    settings.apiKey = store.getSync(KEY_API_KEY, '') as string;
    return settings;
  }

  static write(context: common.UIAbilityContext, settings: BridgeSettings): void {
    const options: preferences.Options = { name: STORE_NAME };
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
  }

  baseUrl: string = DEFAULT_BASE_URL;
  model: string = DEFAULT_MODEL;
  apiKey: string = '';
}

@Entry
@Component
struct Home {
  @State baseUrl: string = DEFAULT_BASE_URL;
  @State model: string = DEFAULT_MODEL;
  @State apiKey: string = '';
  @State saved: string = '';

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext()
      .getHostContext() as common.UIAbilityContext;
    const loaded: BridgeSettings = BridgeSettings.read(context);
    this.baseUrl = loaded.baseUrl;
    this.model = loaded.model;
    this.apiKey = loaded.apiKey;
  }

  private save(): void {
    const context: common.UIAbilityContext = this.getUIContext()
      .getHostContext() as common.UIAbilityContext;
    const settings: BridgeSettings = new BridgeSettings();
    settings.baseUrl = this.baseUrl;
    settings.model = this.model;
    settings.apiKey = this.apiKey;
    BridgeSettings.write(context, settings);
    this.saved = 'Saved on this device only.';
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

      Text(this.saved)
        .fontSize(12)
        .fontColor('#2A5CDB')

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
