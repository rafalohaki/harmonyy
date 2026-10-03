/**
 * Advanced settings.
 *
 * Deliberately a separate screen. The previous version put this form on the first
 * screen, which meant a new user's first impression of the product was three
 * unlabelled boxes and a Save button: nothing said what Bridge does, and the
 * natural reaction was to close it. Configuration now lives behind one clearly
 * labelled door, and the first screen explains the product instead.
 *
 * The key is entered on the device and stored in device preferences, never
 * compiled in: a key bundled into a HAP is extractable from the package, and a key
 * committed to a public repository is leaked by definition.
 *
 * The settings store lives in common/Settings.ets, because the input method
 * extension reads it too and must not import from a UI file.
 */

import type { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';

import { BridgeSettings, DEFAULT_BASE_URL, DEFAULT_MODEL } from '../common/Settings';
import { publishSettings } from '../common/SettingsBus';

const LABEL_COLOR: string = '#1A1A1A';
const MUTED_COLOR: string = '#8A8A8E';
const BODY_COLOR: string = '#555555';
const ACCENT_COLOR: string = '#2A5CDB';

@Entry
@Component
struct Advanced {
  @State baseUrl: string = DEFAULT_BASE_URL;
  @State model: string = DEFAULT_MODEL;
  @State apiKey: string = '';
  @State offlineOnly: boolean = false;
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
    this.offlineOnly = loaded.offlineOnly;
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
    // Push it to the keyboard as well: the extension cannot read this store.
    publishSettings(settings);
    this.saved = 'Saved on this device. Nothing is written to the repository.';
  }

  private goBack(): void {
    this.getUIContext().getRouter().back();
  }

  @Builder
  section(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(MUTED_COLOR)
      .letterSpacing(1.2)
      .margin({ top: 8 })
  }

  @Builder
  fieldLabel(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor(LABEL_COLOR)
  }

  @Builder
  hint(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor(MUTED_COLOR)
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Button('Back')
            .onClick(() => { this.goBack(); })
          Text('Advanced settings')
            .fontSize(20)
            .fontColor(LABEL_COLOR)
            .layoutWeight(1)
        }
        .width('100%')

        this.hint('Most people never need this screen. Bridge works with the ' +
          'settings it ships with, once a key is entered.')

        // ---------------------------------------------------------------- model
        this.section('MODEL SERVICE')

        Column({ space: 4 }) {
          this.fieldLabel('Service address')
          Row({ space: 8 }) {
            TextInput({ text: this.baseUrl })
              .layoutWeight(1)
              .onChange((value: string) => { this.baseUrl = value; })
            Button('Clear')
              .width(80)
              .onClick(() => { this.baseUrl = ''; })
          }
          .width('100%')
          this.hint('Any OpenAI-compatible endpoint.')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          this.fieldLabel('Model name')
          Row({ space: 8 }) {
            TextInput({ text: this.model })
              .layoutWeight(1)
              .onChange((value: string) => { this.model = value; })
            Button('Clear')
              .width(80)
              .onClick(() => { this.model = ''; })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          this.fieldLabel('API key')
          Row({ space: 8 }) {
            TextInput({ text: this.apiKey })
              .type(InputType.Password)
              .layoutWeight(1)
              .onChange((value: string) => { this.apiKey = value; })
            Button('Clear')
              .width(80)
              .onClick(() => { this.apiKey = ''; })
          }
          .width('100%')
          this.hint('Kept on this device. Never written to the repository.')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Button('Save')
          .width('100%')
          .onClick(() => this.save())

        if (this.saved.length > 0) {
          Text(this.saved)
            .fontSize(12)
            .fontColor(ACCENT_COLOR)
        }

        // -------------------------------------------------------------- privacy
        this.section('PRIVACY')

        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('Offline only')
              .fontSize(13)
              .fontColor(LABEL_COLOR)
            this.hint('Never contact the network at all, even with a key set.')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.offlineOnly })
            .onChange((isOn: boolean) => { this.offlineOnly = isOn; })
        }
        .width('100%')

        this.hint('Otherwise, personal data such as e-mail addresses and card ' +
          'numbers is removed on this device before any text is sent, and put back ' +
          'afterwards. The keyboard tells you how many items were hidden.')

        Blank().height(24)
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .align(Alignment.Top)
  }
}
