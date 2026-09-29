import { Song } from '../models/index';
import { PlayerService } from '../services/PlayerService';

// 全局迷你播放条
@Component
export struct MiniPlayerBar {
  @StorageProp('currentSong') currentSong: Song | null = null;
  @StorageProp('playerState') playerState: string = 'idle';
  @StorageProp('currentPosition') currentPosition: number = 0;
  private playerService: PlayerService | undefined = AppStorage.get<PlayerService>('playerService');

  private isPlaying(): boolean {
    return this.playerState === 'playing';
  }

  private getProgress(): number {
    if (this.currentSong && this.currentSong.duration > 0) {
      return (this.currentPosition / this.currentSong.duration) * 100;
    }
    return 0;
  }

  build() {
    if (this.currentSong) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Row() {
          // 封面
          if (this.currentSong.coverUri) {
            Image(this.currentSong.coverUri)
              .width(40)
              .height(40)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              SymbolGlyph($r('sys.symbol.music'))
                .fontSize(18)
                .fontColor([$r('app.color.text_sub')])
                .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            }
            .width(40)
            .height(40)
            .borderRadius(6)
            .backgroundColor($r('app.color.bg_gray'))
            .justifyContent(FlexAlign.Center)
          }

          // 歌曲名 + 歌手
          Column() {
            Text(this.currentSong.title)
              .fontSize(14)
              .fontColor($r('app.color.text_main'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.currentSong.artist || '未知歌手')
              .fontSize(11)
              .fontColor($r('app.color.text_sub'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .margin({ left: 10, right: 10 })
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
        }
        .height(56)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.bg_white'))
        .onClick(() => this.openPlayingPage())

        // 播放/暂停（需内联状态判断以建立 ArkUI 渲染依赖，方法调用不会被追踪）
        SymbolGlyph(this.playerState === 'playing' ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_main')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .width(36)
          .height(36)
          .hitTestBehavior(HitTestMode.Block)
          .position({ x: '65%', y: 10 })
          .onClick(() => this.togglePlay())

        // 下一首
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_main')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .width(36)
          .height(36)
          .hitTestBehavior(HitTestMode.Block)
          .position({ x: '78%', y: 10 })
          .onClick(() => this.playerService?.next())

        // 迷你进度条
        Progress({ value: this.getProgress(), total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.divider'))
      }
      .width('100%')
      .height(56)
    } else {
      Row() {}
        .height(0)
    }
  }

  private togglePlay(): void {
    if (this.isPlaying()) {
      this.playerService?.pause();
    } else if (this.playerState === 'paused') {
      this.playerService?.resume();
    } else {
      const currentIndex: number = AppStorage.get<number>('currentIndex') ?? -1;
      const queue: Song[] = AppStorage.get<Song[]>('playQueue') ?? [];
      if (currentIndex >= 0 && queue.length > 0) {
        this.playerService?.playQueue(queue, currentIndex);
      }
    }
  }

  private openPlayingPage(): void {
    AppStorage.setOrCreate('isPlayingPageShow', true);
  }
}
