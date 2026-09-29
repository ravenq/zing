import { Song } from '../models/index';
import { AppStorageKey, RouterPath } from '../common/Constants';
import { SongItem } from '../components/SongItem';
import { PlayerService } from '../services/PlayerService';
import { MusicRepository } from '../data/MusicRepository';
import { HistoryRepository } from '../data/HistoryRepository';
import { formatDuration } from '../common/Theme';

// 通用歌曲列表页（全部 / 收藏 / 最近）
@Entry
@Component
struct SongListPage {
  @State songs: Song[] = [];
  @State title: string = '歌曲列表';
  private type: string = 'all';
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.type = params?.type || 'all';
    this.title = params?.title || '歌曲列表';
    this.loadSongs();
  }

  private loadSongs() {
    if (this.type === 'all') {
      this.songs = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
    } else if (this.type === 'favorite') {
      this.songs = AppStorage.get<Song[]>(AppStorageKey.FAVORITE_SONGS) || [];
    } else if (this.type === 'recent') {
      this.songs = AppStorage.get<Song[]>(AppStorageKey.RECENT_SONGS) || [];
    }
  }

  private playSong(index: number) {
    PlayerService.getInstance().playQueue(this.songs, index);
  }

  private onMore(song: Song) {
    // 预留：弹出更多操作
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_main'))
          .onClick(() => this.getUIContext().getRouter().back())
        Text(this.title)
          .fontSize(18)
          .fontColor($r('app.color.text_main'))
          .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

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
          Text('暂无歌曲')
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
