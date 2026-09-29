import { Playlist } from '../models/index';
import { AppStorageKey, RouterPath } from '../common/Constants';
import { PlaylistCard } from '../components/PlaylistCard';
import { PlaylistRepository } from '../data/PlaylistRepository';

@CustomDialog
struct CreatePlaylistDialog {
  controller: CustomDialogController;
  name: string = '';
  onConfirm: (name: string) => void = () => {};

  build() {
    Column() {
      Text('新建歌单')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_main'))
        .margin({ top: 20, bottom: 16 })
      TextInput({ text: this.name, placeholder: '请输入歌单名称' })
        .onChange((value: string) => {
          this.name = value;
        })
        .width('80%')
        .height(44)
        .backgroundColor($r('app.color.bg_gray'))
        .borderRadius(8)
        .margin({ bottom: 20 })
      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor($r('app.color.text_main'))
          .backgroundColor($r('app.color.bg_gray'))
          .borderRadius(20)
          .width(100)
          .onClick(() => this.controller.close())
        Button('确定')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(20)
          .width(100)
          .onClick(() => {
            this.onConfirm(this.name);
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ bottom: 20 })
    }
    .width('80%')
    .backgroundColor($r('app.color.bg_white'))
    .borderRadius(12)
  }
}

@Component
export struct PlaylistPage {
  @StorageProp(AppStorageKey.PLAYLISTS) playlists: Playlist[] = [];

  private dialogController: CustomDialogController = new CustomDialogController({
    builder: CreatePlaylistDialog({
      onConfirm: (name: string) : void => { this.createPlaylist(name); }
    }),
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  private async createPlaylist(name: string) {
    const trimmed: string = name.trim();
    if (trimmed.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '歌单名称不能为空' });
      return;
    }
    try {
      await PlaylistRepository.create(trimmed);
      const playlists: Playlist[] = await PlaylistRepository.getAll();
      AppStorage.setOrCreate(AppStorageKey.PLAYLISTS, playlists);
      this.getUIContext().getPromptAction().showToast({ message: '创建成功' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '创建失败' });
    }
  }

  build() {
    Column() {
      Row() {
        Text('歌单')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_main'))
        Blank()
        Text('+')
          .fontSize(28)
          .fontColor($r('app.color.primary'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => this.dialogController.open())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      if (this.playlists.length === 0) {
        Column() {
          Text('☰')
            .fontSize(48)
            .fontColor($r('app.color.text_sub'))
          Text('还没有歌单')
            .fontSize(15)
            .fontColor($r('app.color.text_sub'))
            .margin({ top: 12 })
          Text('点击右上角 + 新建歌单')
            .fontSize(13)
            .fontColor($r('app.color.text_sub'))
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Grid() {
            ForEach(this.playlists, (playlist: Playlist) => {
              GridItem() {
                PlaylistCard({
                  playlist: playlist,
                  onCardClick: () => {
                    this.getUIContext().getRouter().pushUrl({
                    url: RouterPath.PLAYLIST_DETAIL,
                    params: { playlistId: playlist.id }
                  });
                  }
                })
              }
            }, (playlist: Playlist) => playlist.id)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12)
          .rowsGap(16)
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_gray'))
  }
}
