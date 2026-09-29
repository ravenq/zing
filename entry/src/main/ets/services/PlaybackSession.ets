import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../models/index';

export interface SessionController {
  onPlayCommand: () => void;
  onPauseCommand: () => void;
  onNextCommand: () => void;
  onPreviousCommand: () => void;
  onSeekCommand: (positionMs: number) => void;
}

export class PlaybackSession {
  private static instance: PlaybackSession | null = null;
  private session: avSession.AVSession | null = null;
  private controller: SessionController | null = null;
  private backgroundStarted: boolean = false;
  private currentSong: Song | null = null;
  private isPlaying: boolean = false;
  private lastPositionSync: number = 0;
  private readonly POSITION_SYNC_INTERVAL: number = 1000;

  private constructor() {}

  static getInstance(): PlaybackSession {
    if (PlaybackSession.instance === null) {
      PlaybackSession.instance = new PlaybackSession();
    }
    return PlaybackSession.instance;
  }

  async init(context: common.UIAbilityContext, controller: SessionController): Promise<void> {
    this.controller = controller;
    if (this.session !== null) {
      return;
    }
    try {
      const session = await avSession.createAVSession(context, 'Zing', 'audio');
      this.session = session;
      this.registerCommands();
      const launchAgent = await this.createLaunchAgent(context);
      await session.setLaunchAbility(launchAgent);
      await session.activate();
    } catch (err) {
      console.error('创建媒体会话失败: ' + err);
    }
  }

  updateMetadata(song: Song | null): void {
    this.currentSong = song;
    if (this.session === null || song === null) {
      return;
    }
    const metadata: avSession.AVMetadata = {
      assetId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration
    };
    if (song.coverUri) {
      metadata.mediaImage = song.coverUri;
    }
    this.session.setAVMetadata(metadata).then(() => {
      console.info('设置媒体信息成功');
    }).catch((err: BusinessError) => {
      console.error('设置媒体信息失败 code:' + err.code + ' msg:' + err.message);
    });
  }

  updatePlaybackState(isPlaying: boolean): void {
    this.isPlaying = isPlaying;
    if (this.session === null) {
      return;
    }
    const song = this.currentSong;
    const state: avSession.AVPlaybackState = {
      state: isPlaying ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: 1.0,
      position: {
        elapsedTime: this.readPosition(),
        updateTime: systemDateTime.getTime(false)
      },
      duration: song !== null ? song.duration : 0,
      bufferedTime: song !== null ? song.duration : 0
    };
    this.session.setAVPlaybackState(state).catch((err: Error) => {
      console.error('设置播放状态失败: ' + err);
    });
  }

  syncPosition(positionMs: number, force: boolean = false): void {
    const now: number = systemDateTime.getTime(false);
    if (!force && now - this.lastPositionSync < this.POSITION_SYNC_INTERVAL) {
      return;
    }
    this.lastPositionSync = now;
    if (this.session === null) {
      return;
    }
    const state: avSession.AVPlaybackState = {
      state: this.isPlaying ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: 1.0,
      position: {
        elapsedTime: positionMs,
        updateTime: now
      }
    };
    this.session.setAVPlaybackState(state).catch((err: Error) => {
      console.error('同步播放进度失败: ' + err);
    });
  }

  async startBackground(context: common.UIAbilityContext): Promise<void> {
    if (this.backgroundStarted) {
      return;
    }
    try {
      const agent = await this.createLaunchAgent(context);
      await backgroundTaskManager.startBackgroundRunning(
        context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.backgroundStarted = true;
    } catch (err) {
      console.error('启动后台播放任务失败: ' + err);
    }
  }

  async stopBackground(context: common.UIAbilityContext): Promise<void> {
    if (!this.backgroundStarted) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      this.backgroundStarted = false;
    } catch (err) {
      console.error('停止后台播放任务失败: ' + err);
    }
  }

  async destroy(context: common.UIAbilityContext): Promise<void> {
    await this.stopBackground(context);
    if (this.session !== null) {
      try {
        await this.session.deactivate();
        await this.session.destroy();
      } catch (err) {
        console.error('销毁媒体会话失败: ' + err);
      }
      this.session = null;
    }
  }

  private registerCommands(): void {
    if (this.session === null || this.controller === null) {
      return;
    }
    const session = this.session;
    const controller = this.controller;
    session.on('play', () => {
      controller.onPlayCommand();
    });
    session.on('pause', () => {
      controller.onPauseCommand();
    });
    session.on('playNext', () => {
      controller.onNextCommand();
    });
    session.on('playPrevious', () => {
      controller.onPreviousCommand();
    });
    session.on('seek', (time: number) => {
      controller.onSeekCommand(time);
    });
  }

  private async createLaunchAgent(context: common.UIAbilityContext): Promise<WantAgent> {
    return wantAgent.getWantAgent({
      wants: [
        {
          bundleName: context.abilityInfo.bundleName,
          abilityName: 'EntryAbility'
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0
    });
  }

  private readPosition(): number {
    return AppStorage.get<number>('currentPosition') || 0;
  }
}
