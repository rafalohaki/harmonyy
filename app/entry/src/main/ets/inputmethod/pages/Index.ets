/**
 * The keyboard surface.
 *
 * Two ways to produce text:
 *
 *   Rewrite  type however you can, then Correct / Plain / Polite.
 *   Compose  pick concepts instead of typing, then Compose.
 *
 * Both go through the same engine and the same variant list, and both insert
 * through the same editor proxy. That is the point of the design: one platform
 * capability, two uses.
 *
 * The status line always names the source, so a degraded answer is never presented
 * as a normal one.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { keyboardController, KEY_ATTACHED, KEY_FIELD_TEXT, KEY_STATUS } from '../KeyboardController';
import { TAG, DOMAIN } from '../../common/Log';
import type { RewriteMode, RewriteOutcome, Variant } from '../../core/contracts';

/**
 * The concept set.
 *
 * Small on purpose: a strip that needs scrolling is not usable by the people this
 * mode exists for. Each entry is [what the user sees, what the model is told].
 */
const CONCEPTS: string[][] = [
  ['🍽️', 'jeść'],
  ['☕', 'pić'],
  ['🕐', 'teraz'],
  ['⏰', 'później'],
  ['🏠', 'dom'],
  ['🚗', 'jechać'],
  ['💊', 'lekarstwo'],
  ['🛏️', 'spać'],
  ['🚻', 'toaleta'],
  ['📞', 'zadzwonić'],
  ['💰', 'pieniądze'],
  ['🆘', 'pomoc'],
  ['😊', 'dobrze'],
  ['😢', 'smutno'],
  ['❤️', 'kocham'],
  ['🙏', 'proszę'],
  ['👋', 'cześć'],
  ['✅', 'tak'],
  ['❌', 'nie'],
  ['👨‍👩‍👧', 'rodzina']
];

@Entry
@Component
struct Index {
  @StorageProp(KEY_ATTACHED) attached: boolean = false;
  @StorageProp(KEY_FIELD_TEXT) fieldText: string = '';
  @StorageProp(KEY_STATUS) status: string = 'starting';
  @State variants: Variant[] = [];
  @State busy: boolean = false;
  /** Concepts picked so far, in the order they were picked. */
  @State picked: string[] = [];

  private toggle(concept: string): void {
    const next: string[] = [];
    let alreadyPicked: boolean = false;
    for (let i: number = 0; i < this.picked.length; i++) {
      if (this.picked[i] === concept) {
        alreadyPicked = true;
      } else {
        next.push(this.picked[i]);
      }
    }
    if (!alreadyPicked) {
      next.push(concept);
    }
    this.picked = next;
  }

  /** Ask the engine for variants. Never throws: the engine degrades by design. */
  private async run(mode: RewriteMode): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.variants = [];
    try {
      const tokenList: string[] = mode === 'compose' ? this.picked : [];
      const outcome: RewriteOutcome = await keyboardController.rewrite(mode, tokenList);
      this.variants = outcome.variants;
      hilog.info(DOMAIN, TAG, 'run %{public}s: %{public}s, %{public}d variants',
        mode, outcome.source, outcome.variants.length);
    } catch (err) {
      // The engine is designed not to throw. If it ever does, fail visibly rather
      // than leaving the keyboard looking frozen.
      AppStorage.setOrCreate(KEY_STATUS, 'unexpected error, see logs');
      hilog.error(DOMAIN, TAG, 'run threw unexpectedly');
    } finally {
      this.busy = false;
    }
  }

  /** Replace the field content with the chosen variant. */
  private apply(variant: Variant): void {
    if (variant.text.length === 0) {
      return;
    }
    keyboardController.replaceBeforeCursor(variant.text);
    this.variants = [];
    this.picked = [];
  }

  @Builder
  modeButton(label: string, mode: RewriteMode) {
    Button(label)
      .layoutWeight(1)
      .enabled(!this.busy)
      .onClick(() => { this.run(mode); })
  }

  build() {
    Column({ space: 6 }) {
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

      Text(this.picked.length > 0 ? 'picked: ' + this.picked.join(', ') : this.fieldText)
        .fontSize(12)
        .fontColor('#1A1A1A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        this.modeButton('Correct', 'correct')
        this.modeButton('Plain', 'plain')
        this.modeButton('Polite', 'polite')
      }
      .width('100%')

      if (this.variants.length > 0) {
        ForEach(this.variants, (item: Variant) => {
          Column({ space: 1 }) {
            Text(item.label)
              .fontSize(10)
              .fontColor('#2A5CDB')
            Text(item.text)
              .fontSize(12)
              .fontColor('#1A1A1A')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(6)
          .backgroundColor('#FFFFFF')
          .borderRadius(6)
          .onClick(() => { this.apply(item); })
        }, (item: Variant) => item.label + '|' + item.text)

        Button('Back')
          .width('100%')
          .onClick(() => { this.variants = []; })
      } else {
        // Compose: the concept strip replaces typing entirely.
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(CONCEPTS, (concept: string[]) => {
            Button(concept[0])
              .fontSize(18)
              .height(40)
              .width(56)
              .margin(2)
              .backgroundColor(this.picked.includes(concept[1]) ? '#2A5CDB' : '#FFFFFF')
              .fontColor(this.picked.includes(concept[1]) ? '#FFFFFF' : '#1A1A1A')
              .onClick(() => { this.toggle(concept[1]); })
          }, (concept: string[]) => concept[1])
        }
        .width('100%')

        Row({ space: 8 }) {
          Button(this.picked.length > 0 ? 'Compose (' + this.picked.length + ')' : 'Compose')
            .layoutWeight(1)
            .enabled(!this.busy && this.picked.length > 0)
            .onClick(() => { this.run('compose'); })
          Button('Clear picks')
            .layoutWeight(1)
            .enabled(this.picked.length > 0)
            .onClick(() => { this.picked = []; })
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor('#F2F3F5')
    .justifyContent(FlexAlign.Start)
  }
}
