/**
 * The first screen.
 *
 * Its job is to answer two questions before it asks for anything: what is this,
 * and what do I do now. The previous version opened straight onto the
 * configuration form, so a new user met three unlabelled boxes and a Save button
 * with no idea what the product was for, and closed it.
 *
 * Configuration therefore moved to pages/Advanced, and this screen explains the
 * product, gives the two steps that turn it on, and offers a box to try it in
 * without leaving the app.
 *
 * This page also remains the one that answers the keyboard's request for settings,
 * because it is the page that is running. The extension cannot read the store
 * itself; see common/SettingsBus.ets for why.
 */

import type { common } from '@kit.AbilityKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { TAG, DOMAIN } from '../common/Log';
import { BridgeSettings } from '../common/Settings';
import { EVENT_SETTINGS_REQUEST, publishSettings } from '../common/SettingsBus';

const LABEL_COLOR: string = '#1A1A1A';
const MUTED_COLOR: string = '#8A8A8E';
const BODY_COLOR: string = '#555555';
const ACCENT_COLOR: string = '#2A5CDB';

@Entry
@Component
struct Home {
  /** Scratchpad so the keyboard can be tried without leaving the app. */
  @State draft: string = '';
  /** The live configuration, held only so it can be handed to the keyboard. */
  @State ready: boolean = false;
  /** Answers the keyboard's request for the configuration. */
  private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;

  private hostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  /**
   * Read the store and send it to the keyboard.
   *
   * Failure is non-fatal and visible: without this the keyboard shows "no API key
   * set on this device", which is the correct thing for it to say.
   */
  private publish(): void {
    const context: common.UIAbilityContext | undefined = this.hostContext();
    if (context === undefined) {
      return;
    }
    const settings: BridgeSettings = BridgeSettings.read(context);
    publishSettings(settings);
    this.ready = settings.isConfigured();
  }

  aboutToAppear(): void {
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

  /** Returning from Advanced settings must pick up whatever changed there. */
  onPageShow(): void {
    this.publish();
  }

  aboutToDisappear(): void {
    const subscriber: commonEventManager.CommonEventSubscriber | undefined = this.subscriber;
    if (subscriber !== undefined) {
      commonEventManager.unsubscribe(subscriber);
      this.subscriber = undefined;
    }
  }

  private openAdvanced(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/Advanced' });
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
  hint(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(MUTED_COLOR)
  }

  /** One numbered step, so the reader can see there are exactly two. */
  @Builder
  step(number: string, text: string) {
    Row({ space: 10 }) {
      Text(number)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .width(22)
        .height(22)
        .backgroundColor(ACCENT_COLOR)
        .borderRadius(11)
      Text(text)
        .fontSize(13)
        .fontColor(LABEL_COLOR)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('Bridge')
          .fontSize(28)
          .fontColor(LABEL_COLOR)
        Text('Type however you can. Bridge turns it into a clear sentence, in the ' +
          'field you are already using — in any app on this device.')
          .fontSize(14)
          .fontColor(BODY_COLOR)
        Text('If typing is not possible at all, build the sentence from pictures ' +
          'instead.')
          .fontSize(14)
          .fontColor(BODY_COLOR)

        this.section('HOW TO TURN IT ON')
        this.step('1', 'Open Settings, then Input method, and turn Bridge on.')
        this.step('2', 'Pick Bridge in the keyboard switcher.')
        this.hint('On a workstation, scripts/enable-ime.sh does both.')

        if (!this.ready) {
          Row({ space: 8 }) {
            Text('Bridge needs an API key before it can rewrite anything.')
              .fontSize(12)
              .fontColor('#8A5A00')
              .layoutWeight(1)
            Button('Open settings')
              .fontSize(12)
              .onClick(() => { this.openAdvanced(); })
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#FFF4E0')
          .borderRadius(8)
        }

        this.section('TRY IT HERE')

        TextArea({
          text: this.draft,
          placeholder: 'Type a messy sentence, then use the Bridge keyboard below'
        })
          .height(120)
          .onChange((value: string) => { this.draft = value; })

        this.hint('Focus this box and the Bridge keyboard appears at the bottom of ' +
          'the screen. Write badly on purpose: that is what it is for.')

        Button('Advanced settings')
          .width('100%')
          .onClick(() => { this.openAdvanced(); })

        this.hint('Point Bridge at a different model, or keep everything on this ' +
          'device.')

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
