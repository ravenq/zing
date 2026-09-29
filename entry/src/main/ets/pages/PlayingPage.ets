import { Song, LyricLine } from '../models/index';
import { AppStorageKey } from '../common/Constants';
import { formatDuration } from '../common/Theme';
import { PlayerControls } from '../components/PlayerControls';
import { LyricView } from '../components/LyricView';
import { PlayerService } from '../services/PlayerService';
import { LrcParser } from '../services/LrcParser';
import { FavoriteRepository } from '../data/FavoriteRepository';

@Component
export struct PlayingPage {
  @StorageProp(AppStorageKey.CURRENT_SONG) @Watch('onSongChanged') currentSong: Song | null = null;
  @StorageProp(AppStorageKey.PLAYER_STATE) playerState: string = 'idle';
  @StorageProp(AppStorageKey.CURRENT_POSITION) currentPosition: number = 0;
  @StorageProp(AppStorageKey.FAVORITE_SONGS) favoriteSongs: Song[] = [];
  @State lyrics: LyricLine[] = [];
  @State swiperIndex: number = 0;
  @State showQueue: boolean = false;

  aboutToAppear() {
    this.parseLyrics();
  }

  onSongChanged() {
    this.parseLyrics();
  }

  private parseLyrics() {
    if (this.currentSong && this.currentSong.lyrics) {
      this.lyrics = LrcParser.parse(this.currentSong.lyrics);
    } else {
      this.lyrics = [];
    }
  }

  private close() {
    AppStorage.setOrCreate(AppStorageKey.IS_PLAYING_PAGE_SHOW, false);
  }

  private seek(value: number) {
    PlayerService.getInstance().seek(value);
  }

  private isFavorite(): boolean {
    if (!this.currentSong) {
      return false;
    }
    for (let i = 0; i < this.favoriteSongs.length; i++) {
      if (this.favoriteSongs[i].id === this.currentSong.id) {
        return true;
      }
    }
    return false;
  }

  private async toggleFavorite() {
    if (!this.currentSong) {
      return;
    }
    const isFav: boolean = await FavoriteRepository.toggle(this.currentSong.id);
    const allSongs: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
    const favIds: string[] = await FavoriteRepository.getFavoriteIds();
    const favSongs: Song[] = [];
    for (let i = 0; i < allSongs.length; i++) {
      if (favIds.indexOf(allSongs[i].id) >= 0) {
        favSongs.push(allSongs[i]);
      }
    }
    AppStorage.setOrCreate(AppStorageKey.FAVORITE_SONGS, favSongs);
    this.getUIContext().getPromptAction().showToast({
      message: isFav ? '已加入我喜欢' : '已取消喜欢'
    });
  }

  @Builder
  progressBar() {
    Column() {
      Slider({
        value: this.currentPosition,
        min: 0,
        max: this.currentSong ? this.currentSong.duration : 100,
        step: 1
      })
        .trackColor($r('app.color.divider'))
        .selectedColor($r('app.color.primary'))
        .blockColor($r('app.color.primary'))
        .width('100%')
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.seek(value);
          }
        })
      Row() {
        Text(formatDuration(this.currentPosition))
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
        Blank()
        Text(formatDuration(this.currentSong ? this.currentSong.duration : 0))
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  @Builder
  coverPage() {
    Column() {
      Stack() {
        if (this.currentSong && this.currentSong.coverUri) {
          Image(this.currentSong.coverUri)
            .width(260)
            .height(260)
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.music'))
              .fontSize(80)
              .fontColor([$r('app.color.primary_light')])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          }
          .width(260)
          .height(260)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_gray'))
          .justifyContent(FlexAlign.Center)
        }
      }

      Row() {
        Text(' ')
          .width(40)
          .height(40)
        Text(this.currentSong ? this.currentSong.title : '暂无播放')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        SymbolGlyph(this.isFavorite() ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
          .fontSize(24)
          .fontColor([this.isFavorite() ? $r('app.color.favorite') : $r('app.color.text_main')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .width(40)
          .height(40)
          .onClick(() => this.toggleFavorite())
      }
      .width('80%')
      .margin({ top: 28 })
      Text(this.currentSong && this.currentSong.artist
        ? this.currentSong.artist
        : '未知歌手')
        .fontSize(14)
        .fontColor($r('app.color.text_sub'))
        .margin({ top: 8 })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 12 })
  }

  @Builder
  lyricPage() {
    Column() {
      LyricView({
        lyrics: this.lyrics,
        currentTime: this.currentPosition
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: 20, bottom: 20 })
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('↓')
          .fontSize(24)
          .fontColor($r('app.color.text_main'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => this.close())
        Column() {
          Text('正在播放')
            .fontSize(16)
            .fontColor($r('app.color.text_main'))
          Text(this.currentSong ? this.currentSong.title : '')
            .fontSize(11)
            .fontColor($r('app.color.text_sub'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Text(' ')
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.currentSong) {
        Swiper() {
          this.coverPage()
          this.lyricPage()
        }
        .layoutWeight(1)
        .indicator(false)
        .loop(false)
        .index(this.swiperIndex)
        .onChange((index: number) => {
          this.swiperIndex = index;
        })

        // 共享进度条
        this.progressBar()

        // 共享控制区
        PlayerControls({
          onShowQueue: () => {
            this.showQueue = true;
          }
        })
        .margin({ bottom: 20, top: 4 })
      } else {
        Column() {
          Text('暂无播放')
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
