import { Song, Playlist } from '../models/index';
import { AppStorageKey, RouterPath } from '../common/Constants';
import { SongItem } from '../components/SongItem';
import { PlaylistCard } from '../components/PlaylistCard';
import { PlayerService } from '../services/PlayerService';
import { MusicRepository } from '../data/MusicRepository';

@Component
export struct MyMusicPage {
  @StorageProp(AppStorageKey.ALL_SONGS) allSongs: Song[] = [];
  @StorageProp(AppStorageKey.FAVORITE_SONGS) favoriteSongs: Song[] = [];
  @StorageProp(AppStorageKey.RECENT_SONGS) recentSongs: Song[] = [];
  @StorageProp(AppStorageKey.PLAYLISTS) playlists: Playlist[] = [];
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;
  @State importing: boolean = false;

  private previewSongs(): Song[] {
    const result: Song[] = [];
    const count = this.allSongs.length < 5 ? this.allSongs.length : 5;
    for (let i = 0; i < count; i++) {
      result.push(this.allSongs[i]);
    }
    return result;
  }

  private playSong(songs: Song[], index: number) {
    PlayerService.getInstance().playQueue(songs, index);
  }

  private goSongList(type: string, title: string) {
    this.getUIContext().getRouter().pushUrl({
      url: RouterPath.SONG_LIST,
      params: { type, title }
    });
  }

  private goOnlineMusic() {
    this.getUIContext().getRouter().pushUrl({ url: RouterPath.ONLINE_SEARCH });
  }

  private goWebSniffer() {
    this.getUIContext().getRouter().pushUrl({ url: RouterPath.WEB_SNIFFER });
  }

  private async importMusic() {
    if (this.importing) {
      return;
    }
    this.importing = true;
    try {
      const imported: Song[] = await MusicRepository.importFromPicker();
      if (imported.length > 0) {
        await MusicRepository.mergeAndCache(imported);
        this.getUIContext().getPromptAction().showToast({ message: `导入成功，共${imported.length}首` });
      }
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '导入失败' });
    }
    this.importing = false;
  }

  @Builder
  quickEntry(icon: Resource, label: string, action: () => void, color: Resource = $r('app.color.primary')) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor([color])
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_main'))
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .height(76)
    .backgroundColor($r('app.color.bg_white'))
    .borderRadius(8)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => action())
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('我的音乐')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Scroll() {
        Column() {
          // 快捷入口
          Row({ space: 10 }) {
            this.quickEntry($r('sys.symbol.music'), '本地歌曲', () : void => this.goSongList('all', '本地歌曲'))
            this.quickEntry($r('sys.symbol.heart'), '我喜欢', () : void => this.goSongList('favorite', '我喜欢'), $r('app.color.favorite'))
            this.quickEntry($r('sys.symbol.clock'), '最近播放', () : void => this.goSongList('recent', '最近播放'))
            this.quickEntry($r('sys.symbol.magnifyingglass'), '在线音乐', () : void => this.goOnlineMusic())
            this.quickEntry($r('sys.symbol.plus'), '网页嗅探', () : void => this.goWebSniffer())
            this.quickEntry($r('sys.symbol.upload'), '本地导入', () : void => { this.importMusic(); })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })

          // 本地歌曲预览
          Column() {
            Row() {
              Text('本地歌曲')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_main'))
              Blank()
              Text('查看全部 >')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .height(44)
            .padding({ left: 16, right: 16 })
            .onClick(() => this.goSongList('all', '本地歌曲'))

            if (this.allSongs.length === 0) {
              Column() {
                Text('未找到本地音乐')
                  .fontSize(14)
                  .fontColor($r('app.color.text_sub'))
                Text('点击导入')
                  .fontSize(14)
                  .fontColor($r('app.color.primary'))
                  .margin({ top: 10 })
                  .padding({ left: 20, top: 6, right: 20, bottom: 6 })
                  .border({ width: 1, color: $r('app.color.primary'), radius: 16 })
              }
              .width('100%')
              .height(120)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.importMusic())
            } else {
              Column() {
                ForEach(this.previewSongs(), (song: Song, index: number) => {
                  SongItem({
                    song: song,
                    index: index,
                    isPlaying: this.currentSong?.id === song.id,
                    onPlay: (s: Song, i: number) : void => this.playSong(this.allSongs, i),
                    onMore: (s: Song) => {}
                  })
                }, (song: Song) => song.id)
              }
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.bg_white'))
          .margin({ top: 8 })

          // 我的歌单
          Column() {
            Row() {
              Text('我的歌单')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_main'))
              Blank()
              Text('全部 >')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .height(44)
            .padding({ left: 16, right: 16 })

            if (this.playlists.length === 0) {
              Text('暂无自建歌单')
                .fontSize(13)
                .fontColor($r('app.color.text_sub'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 12, bottom: 16 })
            } else {
              Scroll() {
                Row({ space: 12 }) {
                  ForEach(this.playlists, (playlist: Playlist) => {
                    PlaylistCard({
                      playlist: playlist,
                      onCardClick: () => {
                        this.getUIContext().getRouter().pushUrl({
                          url: RouterPath.PLAYLIST_DETAIL,
                          params: { playlistId: playlist.id }
                        });
                      }
                    })
                  }, (playlist: Playlist) => playlist.id)
                }
                .padding({ left: 16, right: 16, bottom: 16 })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.bg_white'))
          .margin({ top: 8, bottom: 12 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_gray'))
  }
}
