import { Song, PlayMode } from '../models/index';
import { AppStorageKey, RouterPath } from '../common/Constants';
import { MusicRepository } from '../data/MusicRepository';
import { PlayerService } from '../services/PlayerService';

@Component
export struct SettingsPage {
  @State showLyrics: boolean = true;
  @State rememberPosition: boolean = true;
  @State modeIndex: number = 0;
  private modeLabels: string[] = ['顺序播放', '单曲循环', '随机播放'];

  private async rescan() {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '开始扫描...' });
      const songs: Song[] = await MusicRepository.scanFromMediaLibrary();
      AppStorage.setOrCreate(AppStorageKey.ALL_SONGS, songs);
      await MusicRepository.cacheSongs(songs);
      this.getUIContext().getPromptAction().showToast({ message: `扫描完成，共${songs.length}首` });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '扫描失败' });
    }
  }

  private async importMusic() {
    try {
      const imported: Song[] = await MusicRepository.importFromPicker();
      if (imported.length > 0) {
        await MusicRepository.mergeAndCache(imported);
        this.getUIContext().getPromptAction().showToast({ message: `导入成功，共${imported.length}首` });
      }
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '导入失败' });
    }
  }

  private applyMode(index: number) {
    this.modeIndex = index;
    let mode: PlayMode = PlayMode.SEQUENCE;
    if (index === 1) {
      mode = PlayMode.REPEAT_ONE;
    } else if (index === 2) {
      mode = PlayMode.SHUFFLE;
    }
    PlayerService.getInstance().setPlayMode(mode);
  }

  private selectMode() {
    this.getUIContext().showActionSheet({
      title: '默认播放模式',
      message: '',
      sheets: [
        { title: this.modeLabels[0], action: () => this.applyMode(0) },
        { title: this.modeLabels[1], action: () => this.applyMode(1) },
        { title: this.modeLabels[2], action: () => this.applyMode(2) }
      ]
    });
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_sub'))
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8, right: 16 })
  }

  @Builder
  cell(label: string, valueText: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_main'))
      Blank()
      Text(valueText)
        .fontSize(13)
        .fontColor($r('app.color.text_sub'))
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.text_sub'))
        .margin({ left: 4 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => action())
  }

  @Builder
  toggleCell(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_main'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.primary'))
        .onChange((value: boolean) => onChange(value))
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('设置')
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
          this.sectionHeader('扫描设置')
          Column() {
            this.cell('重新扫描本地音乐', '', () : void => { this.rescan(); })
            Divider().color($r('app.color.divider')).margin({ left: 16 })
            this.cell('导入音乐文件', '', () : void => { this.importMusic(); })
            Divider().color($r('app.color.divider')).margin({ left: 16 })
            this.cell('支持格式', 'MP3/FLAC/WAV/AAC/OGG', () => {})
          }
          .backgroundColor($r('app.color.bg_white'))

          this.sectionHeader('播放设置')
          Column() {
            this.cell('默认播放模式', this.modeLabels[this.modeIndex], () : void => this.selectMode())
            Divider().color($r('app.color.divider')).margin({ left: 16 })
            this.toggleCell('记忆播放位置', this.rememberPosition, (v: boolean) => {
              this.rememberPosition = v;
            })
          }
          .backgroundColor($r('app.color.bg_white'))

          this.sectionHeader('歌词设置')
          Column() {
            this.toggleCell('显示歌词', this.showLyrics, (v: boolean) => {
              this.showLyrics = v;
            })
          }
          .backgroundColor($r('app.color.bg_white'))

          this.sectionHeader('在线音乐')
          Column() {
            this.cell('在线音源管理', '', () : void => {
              this.getUIContext().getRouter().pushUrl({ url: RouterPath.SOURCE_MANAGE });
            })
          }
          .backgroundColor($r('app.color.bg_white'))

          this.sectionHeader('关于')
          Column() {
            this.cell('版本号', '1.0.0', () => {})
            Divider().color($r('app.color.divider')).margin({ left: 16 })
            this.cell('关于应用', '知音 本地音乐播放器', () => {})
          }
          .backgroundColor($r('app.color.bg_white'))

          Column()
            .height(20)
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
