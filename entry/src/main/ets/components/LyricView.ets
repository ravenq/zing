import { LyricLine } from '../models/index';

// 歌词滚动视图
@Component
export struct LyricView {
  @Prop lyrics: LyricLine[];
  @Prop @Watch('onTimeChange') currentTime: number = 0;
  private scroller: Scroller = new Scroller();
  private lastIndex: number = -1;

  private getCurrentIndex(): number {
    if (!this.lyrics || this.lyrics.length === 0) {
      return -1;
    }
    let index = -1;
    for (let i = 0; i < this.lyrics.length; i++) {
      if (this.lyrics[i].time <= this.currentTime) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  onTimeChange(): void {
    const index = this.getCurrentIndex();
    if (index >= 0 && index !== this.lastIndex) {
      this.lastIndex = index;
      this.scroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    }
  }

  build() {
    if (this.lyrics && this.lyrics.length > 0) {
      List({ scroller: this.scroller, space: 12 }) {
        ForEach(this.lyrics, (line: LyricLine, index: number) => {
          ListItem() {
            Text(line.text || '♪')
              .fontSize(index === this.getCurrentIndex() ? 18 : 14)
              .fontColor(index === this.getCurrentIndex()
                ? $r('app.color.text_main')
                : $r('app.color.text_sub'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24 })
              .height(46)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    } else {
      Column() {
        Text('暂无歌词')
          .fontSize(16)
          .fontColor($r('app.color.text_sub'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}
