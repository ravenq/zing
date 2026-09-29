import { Song } from '../models/index';
import { AppStorageKey } from '../common/Constants';
import { SongItem } from '../components/SongItem';
import { PlayerService } from '../services/PlayerService';

// 歌手详情页
@Entry
@Component
struct ArtistDetailPage {
  @State artistName: string = '未知歌手';
  @State songs: Song[] = [];
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.artistName = params?.artistName || '未知歌手';
    const all: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
    this.songs = all.filter((s: Song) => (s.artist || '未知歌手') === this.artistName);
  }

  private playSong(index: number) {
    PlayerService.getInstance().playQueue(this.songs, index);
  }

  private onMore(song: Song) {
    // 预留：弹出更多操作
  }

  private firstChar(): string {
    return this.artistName.charAt(0);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_main'))
          .onClick(() => this.getUIContext().getRouter().back())
        Text(this.artistName)
          .fontSize(18)
          .fontColor($r('app.color.text_main'))
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      // 顶部歌手信息
      Row() {
        // 歌手头像
        Column() {
          if (this.artistName && this.artistName.length > 0) {
            Text(this.firstChar())
              .fontSize(28)
              .fontColor($r('app.color.primary'))
          } else {
            SymbolGlyph($r('sys.symbol.music'))
              .fontSize(28)
              .fontColor([$r('app.color.primary')])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          }
        }
        .width(80)
        .height(80)
        .borderRadius(40)
        .backgroundColor($r('app.color.bg_gray'))
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(this.artistName)
            .fontSize(20)
            .fontColor($r('app.color.text_main'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`${this.songs.length}首歌曲`)
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Divider().color($r('app.color.divider'))

      if (this.songs.length > 0) {
        // 全部播放按钮
        Row() {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(15)
            .fontColor([$r('app.color.primary')])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          Text('全部播放')
            .fontSize(14)
            .fontColor($r('app.color.primary'))
            .margin({ left: 4 })
          Text(`(${this.songs.length}首)`)
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
            .margin({ left: 4 })
          Blank()
          Text('›')
            .fontSize(20)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 12 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => this.playSong(0))

        Divider().color($r('app.color.divider'))

        // 歌曲列表
        List({ space: 0 }) {
          ForEach(this.songs, (song: Song, index: number) => {
            ListItem() {
              SongItem({
                song: song,
                index: index,
                isPlaying: this.currentSong?.id === song.id,
                onPlay: (s: Song, i: number) : void => this.playSong(i),
                onMore: (s: Song) : void => this.onMore(s)
              })
            }
          }, (song: Song) => song.id)
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 72, endMargin: 12 })
      } else {
        // 空状态
        Column() {
          Text('该歌手暂无歌曲')
            .fontSize(16)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_white'))
  }
}
