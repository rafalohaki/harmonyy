/**
 * The keyboard surface.
 *
 * MILESTONE 1 (current): prove that this panel renders inside another
 * application's text field and can write into it. The three mode buttons are
 * present so the shape of the product is visible, but they currently apply a
 * deliberately minimal local tidying and say so in the status line.
 *
 * MILESTONE 2 replaces the body of `applyMode` with a call to the rewrite engine
 * in core/, behind the ArkHttpTransport. Nothing else on this page changes.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { keyboardController, KEY_ATTACHED, KEY_FIELD_TEXT, KEY_STATUS } from '../KeyboardController';
import { TAG, DOMAIN } from '../Log';

@Entry
@Component
struct Index {
  @StorageProp(KEY_ATTACHED) attached: boolean = false;
  @StorageProp(KEY_FIELD_TEXT) fieldText: string = '';
  @StorageProp(KEY_STATUS) status: string = 'starting';

  /**
   * MILESTONE 1 placeholder. Deliberately does not pretend to be the model: it
   * only tidies whitespace, capitalises and punctuates, and the status line
   * makes clear that this is the offline path.
   */
  private applyMode(mode: string): void {
    const current: string = keyboardController.getFieldText();
    if (current.trim().length === 0) {
      AppStorage.setOrCreate(KEY_STATUS, 'nothing to rewrite yet');
      return;
    }
    const tidied: string = this.tidy(current);
    hilog.info(DOMAIN, TAG, 'applyMode %{public}s on %{public}d characters',
      mode, current.length);
    keyboardController.replaceBeforeCursor(tidied);
    AppStorage.setOrCreate(KEY_STATUS, 'milestone 1: local tidying only, engine not wired yet');
  }

  private tidy(text: string): string {
    let out: string = text.replace(/\s+/g, ' ').trim();
    if (out.length > 0) {
      out = out.charAt(0).toUpperCase() + out.substring(1);
    }
    const last: string = out.charAt(out.length - 1);
    if (last !== '.' && last !== '!' && last !== '?') {
      out = out + '.';
    }
    return out;
  }

  private onProbe(): void {
    keyboardController.insertText('Bridge works. ');
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.attached ? 'attached' : 'no editor')
          .fontSize(12)
          .fontColor(this.attached ? '#2A5CDB' : '#B3690A')
        Text(this.status)
          .fontSize(12)
          .fontColor('#555555')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Text(this.fieldText.length > 0 ? this.fieldText : 'Field is empty')
        .fontSize(13)
        .fontColor('#1A1A1A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        Button('Correct')
          .layoutWeight(1)
          .onClick(() => this.applyMode('correct'))
        Button('Plain')
          .layoutWeight(1)
          .onClick(() => this.applyMode('plain'))
        Button('Polite')
          .layoutWeight(1)
          .onClick(() => this.applyMode('polite'))
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('Insert test text')
          .layoutWeight(1)
          .backgroundColor('#2A5CDB')
          .onClick(() => this.onProbe())
        Button('Reload')
          .layoutWeight(1)
          .onClick(() => {
            const text: string = keyboardController.getFieldText();
            AppStorage.setOrCreate(KEY_STATUS, 'field has ' + text.length + ' characters');
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F2F3F5')
    .justifyContent(FlexAlign.Center)
  }
}
