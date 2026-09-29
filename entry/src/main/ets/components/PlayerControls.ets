import { PlayMode, Song } from '../models/index';
import { PlayerService } from '../services/PlayerService';

// 播放控制区组件
@Component
export struct PlayerControls {
  @StorageProp('playMode') playMode: PlayMode = PlayMode.SEQUENCE;
  @StorageProp('playerState') playerState: string = 'idle';
  private playerService: PlayerService | undefined = AppStorage.get<PlayerService>('playerService');
  onShowQueue: () => void = () => {};

  private isPlaying(): boolean {
    return this.playerState === 'playing';
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

  private togglePlayMode(): void {
    const modes: PlayMode[] = [PlayMode.SEQUENCE, PlayMode.REPEAT_ONE, PlayMode.SHUFFLE];
    const currentIdx = modes.indexOf(this.playMode);
    const nextMode = modes[(currentIdx + 1) % modes.length];
    this.playerService?.setPlayMode(nextMode);
  }

  build() {
    Row() {
      // 播放模式
      Stack() {
        SymbolGlyph(this.playMode === PlayMode.SHUFFLE ? $r('sys.symbol.shuffle') : $r('sys.symbol.repeat'))
          .fontSize(24)
          .fontColor([this.playMode !== PlayMode.SEQUENCE
            ? $r('app.color.primary')
            : $r('app.color.text_sub')])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        if (this.playMode === PlayMode.REPEAT_ONE) {
          Text('1')
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .position({ x: 27, y: 6 })
        }
      }
      .width(48)
      .height(48)
      .onClick(() => this.togglePlayMode())

      // 上一首
      SymbolGlyph($r('sys.symbol.backward_end_fill'))
        .fontSize(30)
        .fontColor([$r('app.color.text_main')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .width(48)
        .height(48)
        .onClick(() => this.playerService?.previous())

      // 播放/暂停（大圆按钮）
      Stack() {
        SymbolGlyph(this.isPlaying() ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(30)
          .fontColor([Color.White])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.primary'))
      .onClick(() => this.togglePlay())

      // 下一首
      SymbolGlyph($r('sys.symbol.forward_end_fill'))
        .fontSize(30)
        .fontColor([$r('app.color.text_main')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .width(48)
        .height(48)
        .onClick(() => this.playerService?.next())

      // 播放列表
      SymbolGlyph($r('sys.symbol.list_bullet'))
        .fontSize(24)
        .fontColor([$r('app.color.text_sub')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .width(48)
        .height(48)
        .onClick(() => this.onShowQueue())
    }
    .width('100%')
    .height(80)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
  }
}
