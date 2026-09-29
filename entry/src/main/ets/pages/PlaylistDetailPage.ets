import { Song, Playlist } from '../models/index';
import { AppStorageKey } from '../common/Constants';
import { SongItem } from '../components/SongItem';
import { PlayerService } from '../services/PlayerService';
import { PlaylistRepository } from '../data/PlaylistRepository';

// 歌单详情页
@Entry
@Component
struct PlaylistDetailPage {
  @State playlistId: string = '';
  @State playlist: Playlist | null = null;
  @State songs: Song[] = [];
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;

  // 管理菜单与弹层
  @State showManageMenu: boolean = false;
  @State showAddPanel: boolean = false;
  @State showRenamePanel: boolean = false;
  @State renameText: string = '';
  @State selectedSongIds: string[] = [];
  @State addableSongs: Song[] = [];

  async aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.playlistId = params?.playlistId || '';
    await this.loadPlaylist();
  }

  private async loadPlaylist() {
    this.playlist = await PlaylistRepository.getById(this.playlistId);
    if (this.playlist) {
      const all: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
      const ids: string[] = this.playlist.songIds;
      const list: Song[] = [];
      for (let i = 0; i < ids.length; i++) {
        for (let j = 0; j < all.length; j++) {
          if (all[j].id === ids[i]) {
            list.push(all[j]);
            break;
          }
        }
      }
      this.songs = list;
    }
  }

  private async refreshPlaylists() {
    const playlists = await PlaylistRepository.getAll();
    AppStorage.setOrCreate(AppStorageKey.PLAYLISTS, playlists);
  }

  private playSong(index: number) {
    PlayerService.getInstance().playQueue(this.songs, index);
  }

  private onMore(song: Song) {
    // 预留：弹出更多操作
  }

  private formatDate(ts: number): string {
    if (!ts) return '';
    const d: Date = new Date(ts);
    const y: number = d.getFullYear();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  // 重命名
  private openRename() {
    if (!this.playlist) {
      return;
    }
    this.renameText = this.playlist.name;
    this.showManageMenu = false;
    this.showRenamePanel = true;
  }

  private async confirmRename() {
    const name: string = this.renameText.trim();
    if (name.length === 0) {
      return;
    }
    await PlaylistRepository.rename(this.playlistId, name);
    await this.refreshPlaylists();
    await this.loadPlaylist();
    this.showRenamePanel = false;
  }

  // 删除歌单
  private confirmDelete() {
    this.showManageMenu = false;
    this.getUIContext().showAlertDialog({
      title: '删除歌单',
      message: `确定删除歌单 "${this.playlist?.name || ''}" 吗？`,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.error'),
        action: () => this.deletePlaylist()
      }
    });
  }

  private async deletePlaylist() {
    await PlaylistRepository.delete(this.playlistId);
    await this.refreshPlaylists();
    this.getUIContext().getRouter().back();
  }

  // 添加歌曲
  private openAddPanel() {
    this.showManageMenu = false;
    const all: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
    const existIds: string[] = this.playlist ? this.playlist.songIds : [];
    const result: Song[] = [];
    for (let i = 0; i < all.length; i++) {
      if (existIds.indexOf(all[i].id) < 0) {
        result.push(all[i]);
      }
    }
    this.addableSongs = result;
    this.selectedSongIds = [];
    this.showAddPanel = true;
  }

  private toggleSelect(songId: string) {
    const idx: number = this.selectedSongIds.indexOf(songId);
    if (idx >= 0) {
      this.selectedSongIds.splice(idx, 1);
    } else {
      this.selectedSongIds.push(songId);
    }
  }

  private isSelected(songId: string): boolean {
    return this.selectedSongIds.indexOf(songId) >= 0;
  }

  private async confirmAddSongs() {
    if (!this.playlist || this.selectedSongIds.length === 0) {
      this.showAddPanel = false;
      return;
    }
    for (let i = 0; i < this.selectedSongIds.length; i++) {
      await PlaylistRepository.addSong(this.playlistId, this.selectedSongIds[i]);
    }
    this.selectedSongIds = [];
    this.showAddPanel = false;
    await this.loadPlaylist();
  }

  build() {
    Stack() {
      // 主内容
      Column() {
        // 标题栏
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor($r('app.color.text_main'))
            .onClick(() : void => { this.getUIContext().getRouter().back(); })
          Text(this.playlist?.name || '歌单')
            .fontSize(18)
            .fontColor($r('app.color.text_main'))
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('⋯')
            .fontSize(22)
            .fontColor($r('app.color.text_sub'))
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.showManageMenu = !this.showManageMenu;
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.bg_white'))

        // 管理菜单
        if (this.showManageMenu) {
          Column() {
            Row() {
              Text('添加歌曲')
                .fontSize(14)
                .fontColor($r('app.color.text_main'))
                .layoutWeight(1)
              Text('›')
                .fontSize(20)
                .fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 12 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.openAddPanel())

            Divider().color($r('app.color.divider')).margin({ left: 16 })

            Row() {
              Text('重命名歌单')
                .fontSize(14)
                .fontColor($r('app.color.text_main'))
                .layoutWeight(1)
              Text('›')
                .fontSize(20)
                .fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 12 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.openRename())

            Divider().color($r('app.color.divider')).margin({ left: 16 })

            Row() {
              Text('删除歌单')
                .fontSize(14)
                .fontColor($r('app.color.error'))
                .layoutWeight(1)
            }
            .width('100%')
            .height(48)
            .padding({ left: 16, right: 12 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.confirmDelete())
          }
          .backgroundColor($r('app.color.bg_white'))

          Divider().color($r('app.color.divider'))
        }

        // 顶部歌单信息
        if (this.playlist) {
          Row() {
            // 封面
            Column() {
              SymbolGlyph($r('sys.symbol.music'))
                .fontSize(40)
                .fontColor([$r('app.color.primary_light')])
                .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            }
            .width(120)
            .height(120)
            .borderRadius(8)
            .backgroundColor($r('app.color.bg_gray'))
            .justifyContent(FlexAlign.Center)

            Column() {
              Text(this.playlist.name)
                .fontSize(20)
                .fontColor($r('app.color.text_main'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(`${this.songs.length}首歌曲`)
                .fontSize(14)
                .fontColor($r('app.color.text_sub'))
                .margin({ top: 6 })
                .width('100%')
              Text('创建于 ' + this.formatDate(this.playlist.createdAt))
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
                .margin({ top: 4 })
                .width('100%')
            }
            .layoutWeight(1)
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .alignItems(VerticalAlign.Top)
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
            // 空歌单状态
            Column() {
              Text('歌单还没有歌曲')
                .fontSize(16)
                .fontColor($r('app.color.text_sub'))
              Text('+ 添加歌曲')
                .fontSize(14)
                .fontColor($r('app.color.primary'))
                .margin({ top: 16 })
                .padding({ left: 16, top: 8, right: 16, bottom: 8 })
                .border({ width: 1, color: $r('app.color.primary'), radius: 20 })
                .onClick(() => this.openAddPanel())
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        } else {
          // 歌单不存在
          Column() {
            Text('歌单不存在')
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

      // 添加歌曲面板（全屏覆盖层）
      if (this.showAddPanel) {
        Column() {
          // 顶部标题栏
          Row() {
            Text('取消')
              .fontSize(16)
              .fontColor($r('app.color.text_sub'))
              .onClick(() => {
                this.selectedSongIds = [];
                this.showAddPanel = false;
              })
            Text('添加歌曲')
              .fontSize(18)
              .fontColor($r('app.color.text_main'))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('完成')
              .fontSize(16)
              .fontColor(this.selectedSongIds.length > 0 ? $r('app.color.primary') : $r('app.color.text_sub'))
              .onClick(() => this.confirmAddSongs())
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor($r('app.color.bg_white'))

          Divider().color($r('app.color.divider'))

          if (this.addableSongs.length > 0) {
            Text(`已选 ${this.selectedSongIds.length} 首`)
              .fontSize(12)
              .fontColor($r('app.color.text_sub'))
              .width('100%')
              .padding({ left: 16, top: 8, bottom: 8 })

            List({ space: 0 }) {
              ForEach(this.addableSongs, (song: Song, index: number) => {
                ListItem() {
                  Row() {
                    // 选择圈
                    Text(this.isSelected(song.id) ? '●' : '○')
                      .fontSize(20)
                      .fontColor(this.isSelected(song.id) ? $r('app.color.primary') : $r('app.color.text_sub'))
                      .width(24)

                    Column() {
                      Text(song.title)
                        .fontSize(16)
                        .fontColor($r('app.color.text_main'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Text(song.artist || '未知歌手')
                        .fontSize(12)
                        .fontColor($r('app.color.text_sub'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .margin({ top: 2 })
                    }
                    .layoutWeight(1)
                    .margin({ left: 12 })
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .height(56)
                  .padding({ left: 16, right: 16 })
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => this.toggleSelect(song.id))
                }
              }, (song: Song) => song.id)
            }
            .layoutWeight(1)
            .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 52, endMargin: 16 })
          } else {
            Column() {
              Text('没有可添加的歌曲')
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

      // 重命名面板（全屏覆盖层）
      if (this.showRenamePanel) {
        Column() {
          Row() {
            Text('取消')
              .fontSize(16)
              .fontColor($r('app.color.text_sub'))
              .onClick(() => {
                this.showRenamePanel = false;
              })
            Text('重命名歌单')
              .fontSize(18)
              .fontColor($r('app.color.text_main'))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('保存')
              .fontSize(16)
              .fontColor($r('app.color.primary'))
              .onClick(() => this.confirmRename())
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor($r('app.color.bg_white'))

          Divider().color($r('app.color.divider'))

          Column() {
            Text('歌单名称')
              .fontSize(14)
              .fontColor($r('app.color.text_sub'))
              .width('100%')
              .margin({ bottom: 8 })
            TextInput({ text: this.renameText, placeholder: '请输入歌单名称' })
              .onChange((value: string) => {
                this.renameText = value;
              })
              .backgroundColor($r('app.color.bg_gray'))
              .borderRadius(8)
              .height(44)
              .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 20 })
          .alignItems(HorizontalAlign.Start)

          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_white'))
      }
    }
    .width('100%')
    .height('100%')
  }
}
