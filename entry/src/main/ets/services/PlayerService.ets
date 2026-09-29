import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Song, PlayMode, PlayerState } from '../models/index';
import { AppStorageKey } from '../common/Constants';
import { PlaybackSession, SessionController } from './PlaybackSession';

export class PlayerService {
  private static instance: PlayerService | null = null;
  private playbackSession: PlaybackSession = PlaybackSession.getInstance();
  private sessionReady: boolean = false;
  private avPlayer: media.AVPlayer | null = null;
  private currentFile: fs.File | null = null;
  private queue: Song[] = [];
  private currentIndex: number = -1;
  private playMode: PlayMode = PlayMode.SEQUENCE;
  private currentToken: number = 0;
  private errorCount: number = 0;
  private stateWaiters: ((state: string) => void)[] = [];
  private static readonly MAX_ERROR_COUNT: number = 10;

  private constructor() {
    AppStorage.setOrCreate(AppStorageKey.CURRENT_SONG, null);
    AppStorage.setOrCreate(AppStorageKey.PLAYER_STATE, PlayerState.IDLE);
    AppStorage.setOrCreate(AppStorageKey.CURRENT_POSITION, 0);
    AppStorage.setOrCreate(AppStorageKey.PLAY_MODE, PlayMode.SEQUENCE);
    AppStorage.setOrCreate(AppStorageKey.PLAY_QUEUE, []);
    AppStorage.setOrCreate(AppStorageKey.CURRENT_INDEX, -1);
  }

  static getInstance(): PlayerService {
    if (PlayerService.instance === null) {
      PlayerService.instance = new PlayerService();
    }
    return PlayerService.instance;
  }

  /**
   * 初始化系统媒体会话与后台播放能力
   */
  async initSession(context: common.UIAbilityContext): Promise<void> {
    if (this.sessionReady) {
      return;
    }
    this.sessionReady = true;
    const controller: SessionController = {
      onPlayCommand: () => {
        this.resume();
      },
      onPauseCommand: () => {
        this.pause();
      },
      onNextCommand: () => {
        this.next();
      },
      onPreviousCommand: () => {
        this.previous();
      },
      onSeekCommand: (positionMs: number) => {
        this.seek(positionMs);
      }
    };
    await this.playbackSession.init(context, controller);
  }

  /**
   * 设置播放队列并从指定位置开始播放
   */
  playQueue(songs: Song[], startIndex: number): void {
    this.queue = songs.slice();
    AppStorage.setOrCreate(AppStorageKey.PLAY_QUEUE, this.queue);

    if (songs.length === 0) {
      this.currentIndex = -1;
      this.updateCurrentIndex(-1);
      this.updateCurrentSong(null);
      this.updatePlayerState(PlayerState.IDLE);
      this.releasePlayer();
      return;
    }

    const index: number = Math.max(0, Math.min(startIndex, songs.length - 1));
    this.currentIndex = index;
    this.playCurrent();
  }

  /**
   * 播放单首歌曲
   */
  play(song: Song): void {
    this.queue = [song];
    AppStorage.setOrCreate(AppStorageKey.PLAY_QUEUE, this.queue);
    this.currentIndex = 0;
    this.playCurrent();
  }

  /**
   * 暂停播放
   */
  pause(): void {
    if (this.avPlayer) {
      this.avPlayer.pause();
    }
  }

  /**
   * 恢复播放
   */
  resume(): void {
    if (this.avPlayer) {
      this.avPlayer.play();
    }
  }

  /**
   * 跳转到指定位置（毫秒）
   */
  seek(position: number): void {
    if (this.avPlayer) {
      // AVPlayer.seek 参数为秒，需要从毫秒转换
      this.avPlayer.seek(Math.floor(position / 1000));
      this.updatePosition(position);
      this.playbackSession.syncPosition(position, true);
    }
  }

  /**
   * 下一首（根据播放模式）
   */
  next(): void {
    if (this.queue.length === 0) return;

    let nextIndex: number;
    if (this.playMode === PlayMode.SHUFFLE) {
      if (this.queue.length === 1) {
        nextIndex = 0;
      } else {
        nextIndex = Math.floor(Math.random() * (this.queue.length - 1));
        if (nextIndex >= this.currentIndex) {
          nextIndex++;
        }
      }
    } else {
      nextIndex = (this.currentIndex + 1) % this.queue.length;
    }

    this.currentIndex = nextIndex;
    this.playCurrent();
  }

  /**
   * 上一首（根据播放模式）
   */
  previous(): void {
    if (this.queue.length === 0) return;

    let prevIndex: number;
    if (this.playMode === PlayMode.SHUFFLE) {
      if (this.queue.length === 1) {
        prevIndex = 0;
      } else {
        prevIndex = Math.floor(Math.random() * (this.queue.length - 1));
        if (prevIndex >= this.currentIndex) {
          prevIndex++;
        }
      }
    } else {
      prevIndex = (this.currentIndex - 1 + this.queue.length) % this.queue.length;
    }

    this.currentIndex = prevIndex;
    this.playCurrent();
  }

  /**
   * 设置播放模式
   */
  setPlayMode(mode: PlayMode): void {
    this.playMode = mode;
    AppStorage.setOrCreate(AppStorageKey.PLAY_MODE, mode);
  }

  /**
   * 获取播放模式
   */
  getPlayMode(): PlayMode {
    return this.playMode;
  }

  /**
   * 释放播放器资源（单例保留）
   */
  async release(): Promise<void> {
    const context = this.getContext();
    if (context !== null) {
      await this.playbackSession.stopBackground(context);
    }
    await this.releasePlayer();
    this.queue = [];
    this.currentIndex = -1;
  }

  // ====== 内部方法 ======

  private async playCurrent(): Promise<void> {
    if (this.queue.length === 0 || this.currentIndex < 0 || this.currentIndex >= this.queue.length) {
      return;
    }

    const token = ++this.currentToken;
    const song = this.queue[this.currentIndex];

    // 更新 AppStorage 状态
    this.updateCurrentSong(song);
    this.updateCurrentIndex(this.currentIndex);
    this.updatePosition(0);
    this.playbackSession.updateMetadata(song);

    const context = this.getContext();

    try {
      // 切歌时先 release 旧的 AVPlayer，再创建新的
      await this.releasePlayer();
      if (token !== this.currentToken) return;

      const player = await media.createAVPlayer();
      if (token !== this.currentToken) {
        try { await player.release(); } catch (e) {}
        return;
      }

      this.avPlayer = player;

      // 注册回调（带 token 检查，防止旧播放器事件干扰）；
      // stateChange 全播放器只注册一次，等待器通过订阅队列接收，
      // 避免 off(type, callback) 误清同类型全部回调
      player.on('stateChange', (state: string, reason: number) => {
        if (token !== this.currentToken) return;
        this.dispatchStateChange(state, reason);
      });
      player.on('timeUpdate', (time: number) => {
        if (token !== this.currentToken) return;
        this.onTimeUpdate(time);
      });
      player.on('error', (err: Object) => {
        if (token !== this.currentToken) return;
        this.onError(err);
      });

      // 设置数据源；setMediaSource 与 url 赋值均异步切换到 initialized，
      // 需等待 initialized 事件后才能调用 prepare
      if (song.fileHeaders) {
        const mediaSource: media.MediaSource =
          media.createMediaSourceWithUrl(song.filePath, song.fileHeaders);
        player.setMediaSource(mediaSource);
      } else if (song.filePath.startsWith('file://')) {
        // AVPlayer 不接受 file:// 沙箱路径，本地文件需以 fd:// 方式播放
        const localPath: string = song.filePath.substring('file://'.length);
        this.currentFile = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
        player.fdSrc = { fd: this.currentFile.fd };
      } else {
        player.url = song.filePath;
      }
      await this.waitForState(player, token, 'initialized');
      if (token !== this.currentToken) return;

      // prepare() 的 Promise 可能早于 prepared 状态切换返回，
      // 需以 prepared 事件为准
      try {
        await player.prepare();
      } catch (e) {}
      await this.waitForState(player, token, 'prepared');
      if (token !== this.currentToken) return;

      player.play();
      this.errorCount = 0;
      if (context !== null) {
        await this.playbackSession.startBackground(context);
      }
    } catch (err) {
      if (token !== this.currentToken) return;
      console.error('播放失败: ' + err);
      this.updatePlayerState(PlayerState.ERROR);
      // 错误处理：播放失败时自动跳到下一首
      this.errorCount++;
      if (this.errorCount < PlayerService.MAX_ERROR_COUNT && this.queue.length > 1) {
        this.next();
      }
    }
  }

  private dispatchStateChange(state: string, reason: number): void {
    const waiters: ((state: string) => void)[] = this.stateWaiters.slice();
    for (let i = 0; i < waiters.length; i++) {
      waiters[i](state);
    }
    this.onStateChange(state, reason);
  }

  private async waitForState(player: media.AVPlayer, token: number, target: string): Promise<void> {
    if (player.state === target) {
      return;
    }
    await new Promise<void>((resolve, reject) => {
      let settled: boolean = false;
      const finish = (): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        const idx: number = this.stateWaiters.indexOf(onState);
        if (idx >= 0) {
          this.stateWaiters.splice(idx, 1);
        }
        resolve();
      };
      const fail = (msg: string): void => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        const idx: number = this.stateWaiters.indexOf(onState);
        if (idx >= 0) {
          this.stateWaiters.splice(idx, 1);
        }
        reject(new Error(msg));
      };
      const timer: number = setTimeout(() => {
        fail('等待 ' + target + ' 超时');
      }, 15000);
      const onState = (state: string): void => {
        if (token !== this.currentToken) {
          finish();
          return;
        }
        if (state === target) {
          finish();
        } else if (state === 'error' || state === 'released') {
          fail('播放状态异常: ' + state);
        }
      };
      this.stateWaiters.push(onState);
      if (player.state === target) {
        finish();
      }
    });
  }

  private async releasePlayer(player?: media.AVPlayer): Promise<void> {
    const p: media.AVPlayer | null = player !== undefined ? player : this.avPlayer;
    if (!p) {
      this.closeCurrentFile();
      return;
    }

    try { p.off('stateChange'); } catch (e) {}
    try { p.off('timeUpdate'); } catch (e) {}
    try { p.off('error'); } catch (e) {}
    try { await p.release(); } catch (e) {}

    if (this.avPlayer === p) {
      this.avPlayer = null;
      this.closeCurrentFile();
    }
  }

  private closeCurrentFile(): void {
    if (this.currentFile) {
      try { fs.closeSync(this.currentFile); } catch (e) {}
      this.currentFile = null;
    }
  }

  private onStateChange(state: string, reason: number): void {
    switch (state) {
      case 'idle':
        this.updatePlayerState(PlayerState.IDLE);
        break;
      case 'initialized':
        this.updatePlayerState(PlayerState.INITIALIZED);
        break;
      case 'prepared':
        this.updatePlayerState(PlayerState.PREPARED);
        break;
      case 'playing':
        this.updatePlayerState(PlayerState.PLAYING);
        this.playbackSession.updatePlaybackState(true);
        break;
      case 'paused':
        this.updatePlayerState(PlayerState.PAUSED);
        this.playbackSession.updatePlaybackState(false);
        const pausedContext = this.getContext();
        if (pausedContext !== null) {
          this.playbackSession.stopBackground(pausedContext);
        }
        break;
      case 'completed':
        this.updatePlayerState(PlayerState.COMPLETED);
        this.handleComplete();
        break;
      case 'error':
        this.updatePlayerState(PlayerState.ERROR);
        // 错误处理：自动跳到下一首
        this.errorCount++;
        if (this.errorCount < PlayerService.MAX_ERROR_COUNT && this.queue.length > 1) {
          this.next();
        }
        break;
      case 'released':
        // 释放状态，无需更新 AppStorage
        break;
      default:
        break;
    }
  }

  private onTimeUpdate(time: number): void {
    AppStorage.setOrCreate(AppStorageKey.CURRENT_POSITION, time);
    this.playbackSession.syncPosition(time);
  }

  private onError(err: Object): void {
    console.error('AVPlayer 错误: ' + err);
  }

  private handleComplete(): void {
    if (this.playMode === PlayMode.REPEAT_ONE) {
      // 单曲循环：重头播放
      if (this.avPlayer) {
        this.avPlayer.seek(0);
        this.avPlayer.play();
      }
    } else {
      // 自动下一首
      this.next();
    }
  }

  private updateCurrentSong(song: Song | null): void {
    if (song === null) {
      AppStorage.setOrCreate(AppStorageKey.CURRENT_SONG, null);
    } else {
      // 创建新对象确保 AppStorage 可观察性
      const songCopy: Song = {
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        filePath: song.filePath,
        fileHeaders: song.fileHeaders,
        fileSize: song.fileSize,
        coverUri: song.coverUri,
        favorite: song.favorite,
        lyrics: song.lyrics
      };
      AppStorage.setOrCreate(AppStorageKey.CURRENT_SONG, songCopy);
    }
  }

  private updatePlayerState(state: PlayerState): void {
    AppStorage.setOrCreate(AppStorageKey.PLAYER_STATE, state);
  }

  private updatePosition(position: number): void {
    AppStorage.setOrCreate(AppStorageKey.CURRENT_POSITION, position);
  }

  private updateCurrentIndex(index: number): void {
    AppStorage.setOrCreate(AppStorageKey.CURRENT_INDEX, index);
  }

  private getContext(): common.UIAbilityContext | null {
    return AppStorage.get<common.UIAbilityContext>('context') || null;
  }
}
