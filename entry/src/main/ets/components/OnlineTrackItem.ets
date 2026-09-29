import { DownloadTask, OnlineTrack } from '../models/OnlineTypes';
import { formatDuration } from '../common/Theme';

@Component
export struct OnlineTrackItem {
  @Prop track: OnlineTrack;
  index: number = 0;
  @Prop isPlaying: boolean = false;
  @Prop task: DownloadTask | null = null;
  onPlay: (track: OnlineTrack, index: number) => void = () => {};
  onDownload: (track: OnlineTrack) => void = () => {};

  build() {
    Row() {
      Stack() {
        if (this.track.coverUrl && this.track.coverUrl.length > 0) {
          Image(this.track.coverUrl)
            .width(48)
            .height(48)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.music'))
              .fontSize(22)
              .fontColor([$r('app.color.text_sub')])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          }
          .width(48)
          .height(48)
          .borderRadius(6)
          .backgroundColor($r('app.color.bg_gray'))
          .justifyContent(FlexAlign.Center)
        }
      }

      Column() {
        Text(this.track.title)
          .fontSize(16)
          .fontColor(this.isPlaying ? $r('app.color.primary') : $r('app.color.text_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text(this.track.artist || '未知艺术家')
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '38%' })
          Text('  -  ')
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
          Text(formatDuration(this.track.duration))
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
          if (this.track.licenseName && this.track.licenseName.length > 0) {
            Text(this.track.licenseName)
              .fontSize(10)
              .fontColor($r('app.color.text_sub'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '30%' })
              .margin({ left: 8 })
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.bg_gray'))
              .borderRadius(4)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      if (this.isPlaying) {
        Text('●')
          .fontSize(8)
          .fontColor($r('app.color.primary'))
          .margin({ right: 6 })
      }

      if (this.task && this.task.status === 'running') {
        Text(this.task.progress + '%')
          .fontSize(11)
          .fontColor($r('app.color.primary'))
          .width(48)
          .height(40)
          .textAlign(TextAlign.Center)
      } else if (this.task && this.task.status === 'completed') {
        Text('✓')
          .fontSize(16)
          .fontColor($r('app.color.primary'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
      } else if (this.task && this.task.status === 'failed') {
        Text('↻')
          .fontSize(18)
          .fontColor($r('app.color.text_sub'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => this.onDownload(this.track))
          .bindMenu([
            {
              value: this.task.error ? this.task.error : '未知错误',
              action: () => {}
            }
          ])
      } else {
        Text('⬇')
          .fontSize(18)
          .fontColor($r('app.color.text_sub'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .opacity(this.track.downloadable ? 1 : 0.4)
          .hitTestBehavior(this.track.downloadable ? HitTestMode.Default : HitTestMode.Block)
          .onClick(() => this.onDownload(this.track))
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onPlay(this.track, this.index))
  }
}
