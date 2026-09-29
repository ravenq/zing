import { Song } from '../models/index';
import { AppStorageKey } from '../common/Constants';
import { SongItem } from '../components/SongItem';
import { MusicRepository } from '../data/MusicRepository';
import { PlayerService } from '../services/PlayerService';

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State results: Song[] = [];
  @State hasSearched: boolean = false;
  @State searching: boolean = false;
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;
  private searchToken: number = 0;

  private async doSearch() {
    const token: number = ++this.searchToken;
    const text: string = this.keyword.trim();
    if (text.length === 0) {
      this.results = [];
      this.hasSearched = false;
      return;
    }
    this.searching = true;
    this.hasSearched = true;
    try {
      const list: Song[] = await MusicRepository.search(text);
      if (token === this.searchToken) {
        this.results = list;
      }
    } catch (e) {
      if (token === this.searchToken) {
        this.results = [];
      }
    }
    if (token === this.searchToken) {
      this.searching = false;
    }
  }

  private playSong(index: number) {
    PlayerService.getInstance().playQueue(this.results, index);
  }

  private clearKeyword() {
    this.keyword = '';
    this.results = [];
    this.hasSearched = false;
  }

  build() {
    Column() {
      // 顶部搜索栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_main'))
          .width(36)
          .onClick(() => this.getUIContext().getRouter().back())

        Row() {
          Text('🔍')
            .fontSize(14)
            .margin({ left: 12 })
          TextInput({ text: this.keyword, placeholder: '搜索歌曲/歌手/专辑' })
            .fontSize(14)
            .fontColor($r('app.color.text_main'))
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.keyword = value;
              this.doSearch();
            })
          if (this.keyword.length > 0) {
            Text('✕')
              .fontSize(14)
              .fontColor($r('app.color.text_sub'))
              .margin({ right: 12 })
              .onClick(() => this.clearKeyword())
          }
        }
        .layoutWeight(1)
        .height(36)
        .backgroundColor($r('app.color.bg_gray'))
        .borderRadius(18)
        .alignItems(VerticalAlign.Center)
        .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Divider().color($r('app.color.divider'))

      if (!this.hasSearched) {
        Column() {
          Text('🔍')
            .fontSize(48)
          Text('输入关键词搜索')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.searching && this.results.length === 0) {
        Column() {
          Text('搜索中...')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0) {
        Column() {
          Text('未找到相关歌曲')
            .fontSize(15)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.results, (song: Song, index: number) => {
            ListItem() {
              SongItem({
                song: song,
                index: index,
                isPlaying: this.currentSong?.id === song.id,
                onPlay: (s: Song, i: number) : void => this.playSong(i),
                onMore: (s: Song) => {}
              })
            }
          }, (song: Song) => song.id)
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 72, endMargin: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_white'))
  }
}
