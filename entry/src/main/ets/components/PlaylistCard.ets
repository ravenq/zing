import { Playlist } from '../models/index';

// 歌单卡片组件
@Component
export struct PlaylistCard {
  @Prop playlist: Playlist;
  onCardClick: (playlist: Playlist) => void = () => {};

  build() {
    Column() {
      // 封面
      Stack() {
        if (this.playlist.coverUri) {
          Image(this.playlist.coverUri)
            .width('100%')
            .aspectRatio(1)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.music'))
              .fontSize(32)
              .fontColor([$r('app.color.primary_light')])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          }
          .width('100%')
          .aspectRatio(1)
          .borderRadius(8)
          .backgroundColor($r('app.color.bg_gray'))
          .justifyContent(FlexAlign.Center)
        }
      }
      .margin({ bottom: 6 })

      // 歌单名
      Text(this.playlist.name)
        .fontSize(13)
        .fontColor($r('app.color.text_main'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      // 歌曲数
      Text(`${this.playlist.songIds.length}首`)
        .fontSize(11)
        .fontColor($r('app.color.text_sub'))
        .width('100%')
        .margin({ top: 2 })
    }
    .width('100%')
    .onClick(() => this.onCardClick(this.playlist))
  }
}
