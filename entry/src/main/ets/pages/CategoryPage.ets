import { Song, Artist, Album } from '../models/index';
import { AppStorageKey, RouterPath } from '../common/Constants';

@Component
export struct CategoryPage {
  @StorageProp(AppStorageKey.ALL_SONGS) allSongs: Song[] = [];
  @State subTab: number = 0;

  private getArtists(): Artist[] {
    const map: Map<string, string[]> = new Map<string, string[]>();
    for (let i = 0; i < this.allSongs.length; i++) {
      const song: Song = this.allSongs[i];
      const key: string = song.artist || '未知歌手';
      if (!map.has(key)) {
        map.set(key, []);
      }
      map.get(key)!.push(song.id);
    }
    const result: Artist[] = [];
    map.forEach((ids: string[], name: string) => {
      result.push({
        name: name,
        songCount: ids.length,
        songIds: ids
      });
    });
    return result;
  }

  private getAlbums(): Album[] {
    const map: Map<string, Song[]> = new Map<string, Song[]>();
    for (let i = 0; i < this.allSongs.length; i++) {
      const song: Song = this.allSongs[i];
      const key: string = (song.album || '未知专辑') + '||' + (song.artist || '未知歌手');
      if (!map.has(key)) {
        map.set(key, []);
      }
      map.get(key)!.push(song);
    }
    const result: Album[] = [];
    map.forEach((songs: Song[]) => {
      const ids: string[] = [];
      for (let i = 0; i < songs.length; i++) {
        ids.push(songs[i].id);
      }
      result.push({
        name: songs[0].album || '未知专辑',
        artist: songs[0].artist || '未知歌手',
        songCount: songs.length,
        songIds: ids
      });
    });
    return result;
  }

  private firstChar(text: string): string {
    return text.charAt(0);
  }

  @Builder
  subTabItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontColor(this.subTab === index
          ? $r('app.color.primary')
          : $r('app.color.text_sub'))
      Column()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.subTab === index
          ? $r('app.color.primary')
          : Color.Transparent)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.subTab = index;
    })
  }

  build() {
    Column() {
      Row() {
        Text('分类')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Row() {
        this.subTabItem('歌手', 0)
        this.subTabItem('专辑', 1)
      }
      .width('100%')
      .backgroundColor($r('app.color.bg_white'))

      Divider().color($r('app.color.divider'))

      if (this.allSongs.length === 0) {
        Column() {
          Text('暂无音乐数据')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.subTab === 0) {
        List({ space: 0 }) {
          ForEach(this.getArtists(), (artist: Artist) => {
            ListItem() {
              Row() {
                Column() {
                  if (artist.name && artist.name.length > 0) {
                    Text(this.firstChar(artist.name))
                      .fontSize(22)
                      .fontColor($r('app.color.primary'))
                  } else {
                    SymbolGlyph($r('sys.symbol.music'))
                      .fontSize(22)
                      .fontColor([$r('app.color.primary')])
                      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                  }
                }
                .width(48)
                .height(48)
                .borderRadius(24)
                .backgroundColor($r('app.color.bg_gray'))
                .justifyContent(FlexAlign.Center)

                Column() {
                  Text(artist.name)
                    .fontSize(16)
                    .fontColor($r('app.color.text_main'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(`${artist.songCount}首歌曲`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_sub'))
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(68)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url: RouterPath.ARTIST_DETAIL,
                  params: { artistName: artist.name }
                });
              })
            }
          }, (artist: Artist) => artist.name)
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 76, endMargin: 16 })
      } else {
        List({ space: 0 }) {
          ForEach(this.getAlbums(), (album: Album) => {
            ListItem() {
              Row() {
                Column() {
                  SymbolGlyph($r('sys.symbol.music'))
                    .fontSize(22)
                    .fontColor([$r('app.color.primary_light')])
                    .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                }
                .width(48)
                .height(48)
                .borderRadius(6)
                .backgroundColor($r('app.color.bg_gray'))
                .justifyContent(FlexAlign.Center)

                Column() {
                  Text(album.name)
                    .fontSize(16)
                    .fontColor($r('app.color.text_main'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(album.artist)
                    .fontSize(12)
                    .fontColor($r('app.color.text_sub'))
                    .margin({ top: 3 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                }
                .layoutWeight(1)
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(68)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url: RouterPath.ALBUM_DETAIL,
                  params: {
                    albumName: album.name,
                    artistName: album.artist
                  }
                });
              })
            }
          }, (album: Album) => album.name + '||' + album.artist)
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 76, endMargin: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_white'))
  }
}
