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

import { BridgeSettings, DEFAULT_BASE_URL, DEFAULT_MODEL } from '../common/Settings';

@Entry
@Component
struct Home {
  @State baseUrl: string = DEFAULT_BASE_URL;
  @State model: string = DEFAULT_MODEL;
  @State apiKey: string = '';
  @State saved: string = '';

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
