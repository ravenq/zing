import { Song } from '../models/index';
import { formatDuration } from '../common/Theme';

// 歌曲列表项组件
@Component
export struct SongItem {
  @Prop song: Song;
  index: number = 0;
  @Prop isPlaying: boolean = false;
  onPlay: (song: Song, index: number) => void = () => {};
  onMore: (song: Song) => void = () => {};

  build() {
    Row() {
      // 封面
      Stack() {
        if (this.song.coverUri) {
          Image(this.song.coverUri)
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

      // 歌曲名 + 歌手
      Column() {
        Text(this.song.title)
          .fontSize(16)
          .fontColor(this.isPlaying ? $r('app.color.primary') : $r('app.color.text_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text(this.song.artist || '未知歌手')
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '55%' })
          Text('  -  ')
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
          Text(formatDuration(this.song.duration))
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      // 播放中指示器
      if (this.isPlaying) {
        Text('●')
          .fontSize(8)
          .fontColor($r('app.color.primary'))
          .margin({ right: 6 })
      }

      // 更多按钮
      Text('⋮')
        .fontSize(22)
        .fontColor($r('app.color.text_sub'))
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => this.onMore(this.song))
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onPlay(this.song, this.index))
  }
}
