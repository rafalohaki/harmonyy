/**
 * The keyboard surface.
 *
 * It renders whatever the engine returned, including the case where the engine
 * fell back to the offline path. The status line always names the source, so a
 * degraded answer is never presented as a normal one.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { keyboardController, KEY_ATTACHED, KEY_FIELD_TEXT, KEY_STATUS } from '../KeyboardController';
import { TAG, DOMAIN } from '../../common/Log';
import type { RewriteMode, RewriteOutcome, Variant } from '../../core/contracts';

@Entry
@Component
struct Index {
  @StorageProp(KEY_ATTACHED) attached: boolean = false;
  @StorageProp(KEY_FIELD_TEXT) fieldText: string = '';
  @StorageProp(KEY_STATUS) status: string = 'starting';
  @State variants: Variant[] = [];
  @State busy: boolean = false;

  /** Ask the engine for variants. Never throws: the engine degrades by design. */
  private async run(mode: RewriteMode): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.variants = [];
    try {
      const outcome: RewriteOutcome = await keyboardController.rewrite(mode);
      this.variants = outcome.variants;
      hilog.info(DOMAIN, TAG, 'rewrite %{public}s: %{public}s, %{public}d variants',
        mode, outcome.source, outcome.variants.length);
    } catch (err) {
      // The engine is designed not to throw. If it ever does, fail visibly
      // rather than leaving the keyboard looking frozen.
      AppStorage.setOrCreate(KEY_STATUS, 'unexpected error, see logs');
      hilog.error(DOMAIN, TAG, 'rewrite threw unexpectedly');
    } finally {
      this.busy = false;
    }
  }

  /** Replace the field content with the chosen variant. */
  private apply(variant: Variant): void {
    keyboardController.replaceBeforeCursor(variant.text);
    this.variants = [];
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.attached ? 'attached' : 'no editor')
          .fontSize(12)
          .fontColor(this.attached ? '#2A5CDB' : '#B3690A')
        Text(this.busy ? 'working...' : this.status)
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
          .enabled(!this.busy)
          .onClick(() => { this.run('correct'); })
        Button('Plain')
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { this.run('plain'); })
        Button('Polite')
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { this.run('polite'); })
      }
      .width('100%')

      if (this.variants.length > 0) {
        ForEach(this.variants, (item: Variant) => {
          Column({ space: 2 }) {
            Text(item.label)
              .fontSize(11)
              .fontColor('#2A5CDB')
            Text(item.text)
              .fontSize(13)
              .fontColor('#1A1A1A')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => { this.apply(item); })
        }, (item: Variant) => item.label + '|' + item.text)
      } else {
        Row({ space: 8 }) {
          Button('Insert test text')
            .layoutWeight(1)
            .backgroundColor('#2A5CDB')
            .onClick(() => { keyboardController.insertText('Bridge works. '); })
          Button('Reload field')
            .layoutWeight(1)
            .onClick(() => {
              const text: string = keyboardController.getFieldText();
              AppStorage.setOrCreate(KEY_STATUS, 'field has ' + text.length + ' characters');
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F2F3F5')
    .justifyContent(FlexAlign.Center)
  }
}
