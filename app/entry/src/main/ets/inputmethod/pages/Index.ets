/**
 * The keyboard surface.
 *
 * Two ways to produce text, and the surface has to make both obvious without
 * instructions, because the people it exists for cannot be asked to read a manual:
 *
 *   Rewrite  type however you can, then Correct / Plain / Polite.
 *   Compose  pick pictures instead of typing, then Compose.
 *
 * Design rules this file follows:
 *
 *  - Every concept carries its word. An unlabelled pictogram is a guess, and a
 *    guess is not accessible. The emoji is the fast path for a returning user; the
 *    label is what makes it usable the first time.
 *  - The status line is for the user, not the developer. It says what happened and
 *    whether anything personal left the device, rather than reporting a latency and
 *    a counter whose meaning is private to the code.
 *  - A control that cannot do anything is disabled, so the surface never invites a
 *    tap that will silently do nothing.
 *  - A degraded answer always says so.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { keyboardController, KEY_ATTACHED, KEY_FIELD_TEXT, KEY_STATUS } from '../KeyboardController';
import { TAG, DOMAIN } from '../../common/Log';
import type { RewriteMode, RewriteOutcome, Variant } from '../../core/contracts';

/**
 * The concept set: what the user sees, and the word behind it.
 *
 * Small on purpose. A strip that needs scrolling is not usable by the people this
 * mode exists for, and every concept has to be recognisable at a glance.
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

const HINT: string = 'Type however you can and tap Correct, or pick pictures below and tap Compose.';

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

  private hasText(): boolean {
    return this.fieldText.trim().length > 0;
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
      AppStorage.setOrCreate(KEY_STATUS, 'Something went wrong. See the logs.');
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

  /**
   * The mode buttons are gated on having an editor, not on the cached field text.
   *
   * Gating them on our own copy of the text was a real bug, found while capturing
   * the demo: when text arrives by any route other than this keyboard - system
   * autofill, dictation, a paste, or a script - the cached copy is empty, so the
   * buttons stayed disabled and the keyboard silently refused to act on text that
   * was visibly there. The editor is the authority on whether there is something to
   * work on, and the engine already answers "Nothing to rewrite yet." for an empty
   * field, so there is nothing to protect against.
   */
  @Builder
  modeButton(label: string, mode: RewriteMode) {
    Button(label)
      .layoutWeight(1)
      .enabled(!this.busy && this.attached)
      .onClick(() => { this.run(mode); })
  }

  /** One concept: the picture for speed, the word for meaning. */
  @Builder
  conceptButton(concept: string[]) {
    Column({ space: 0 }) {
      Text(concept[0])
        .fontSize(19)
        .maxLines(1)
      Text(concept[1])
        .fontSize(9)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.picked.includes(concept[1]) ? '#FFFFFF' : '#555555')
    }
    .width(62)
    .height(48)
    .margin(2)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.picked.includes(concept[1]) ? '#2A5CDB' : '#FFFFFF')
    .borderRadius(8)
    .onClick(() => { this.toggle(concept[1]); })
  }

  build() {
    Column({ space: 6 }) {
      // Status: what happened, in the user's terms.
      Row({ space: 8 }) {
        Text(this.attached ? 'Ready' : 'No text field')
          .fontSize(12)
          .fontColor(this.attached ? '#2A5CDB' : '#B3690A')
        Text(this.busy ? 'Working…' : this.status)
          .fontSize(12)
          .fontColor('#555555')
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      // What the keyboard can see, or what has been picked to compose from.
      Text(this.picked.length > 0 ? 'Picked: ' + this.picked.join(', ') : this.fieldText)
        .fontSize(12)
        .fontColor('#1A1A1A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        Row({ space: 8 }) {
          this.modeButton('Correct', 'correct')
          this.modeButton('Plain', 'plain')
          this.modeButton('Polite', 'polite')
        }
        .width('100%')

        Text(this.hasText() ? 'Or pick pictures instead of typing:' : HINT)
          .fontSize(10)
          .fontColor('#777777')
          .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(CONCEPTS, (concept: string[]) => {
            this.conceptButton(concept)
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
