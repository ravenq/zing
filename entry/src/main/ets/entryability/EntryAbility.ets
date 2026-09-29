/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PlayerService } from '../services/PlayerService';
import { PlaybackSession } from '../services/PlaybackSession';
import { MusicScanner } from '../services/MusicScanner';
import { FavoriteRepository } from '../data/FavoriteRepository';
import { HistoryRepository } from '../data/HistoryRepository';
import { PlaylistRepository } from '../data/PlaylistRepository';
import { MusicRepository } from '../data/MusicRepository';
import { SourceRepository } from '../data/SourceRepository';
import { SourceRegistry } from '../services/online/SourceRegistry';
import { PlayMode, Song } from '../models/index';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 存储 context 到 AppStorage 供全局使用
    AppStorage.setOrCreate('context', this.context);

    // 初始化 PlayerService 单例
    const playerService = PlayerService.getInstance();
    AppStorage.setOrCreate('playerService', playerService);

    // 初始化系统媒体会话（后台播放、锁屏控制）
    playerService.initSession(this.context);

    // 初始化默认播放状态
    AppStorage.setOrCreate('currentSong', null);
    AppStorage.setOrCreate('playerState', 'idle');
    AppStorage.setOrCreate('currentPosition', 0);
    AppStorage.setOrCreate('playMode', PlayMode.SEQUENCE);
    AppStorage.setOrCreate('playQueue', []);
    AppStorage.setOrCreate('currentIndex', -1);
    AppStorage.setOrCreate('isPlayingPageShow', false);
    AppStorage.setOrCreate('allSongs', []);
    AppStorage.setOrCreate('favoriteSongs', []);
    AppStorage.setOrCreate('recentSongs', []);
    AppStorage.setOrCreate('playlists', []);

    // 初始化数据层 Repository
    this.initRepositories();

    // 初始化扫描服务
    const scanner = MusicScanner.getInstance();
    AppStorage.setOrCreate('musicScanner', scanner);
  }

  private async initRepositories(): Promise<void> {
    try {
      await FavoriteRepository.init(this.context);
      await HistoryRepository.init(this.context);
      await PlaylistRepository.init(this.context);
      await MusicRepository.init(this.context);
      await SourceRepository.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'Repositories initialized');

      // 按持久化配置刷新在线音源
      const sourceConfigs = await SourceRepository.getConfigs();
      const jamendoClientId: string = await SourceRepository.getJamendoClientId();
      SourceRegistry.configure(sourceConfigs, jamendoClientId);

      // 加载数据到 AppStorage 供 UI 响应式使用
      let songs = await MusicRepository.getAllSongs();
      AppStorage.setOrCreate('allSongs', songs);

      // 为历史下载的 0 秒本地歌曲回填真实时长
      await MusicRepository.backfillMissingDurations();
      songs = AppStorage.get<Song[]>('allSongs') || songs;

      const favIds = await FavoriteRepository.getFavoriteIds();
      const favSongs: Song[] = [];
      for (let i = 0; i < songs.length; i++) {
        if (favIds.indexOf(songs[i].id) >= 0) {
          favSongs.push(songs[i]);
        }
      }
      AppStorage.setOrCreate('favoriteSongs', favSongs);

      const recentIds = await HistoryRepository.getRecent();
      const recentSongs: Song[] = [];
      for (let i = 0; i < recentIds.length; i++) {
        for (let j = 0; j < songs.length; j++) {
          if (songs[j].id === recentIds[i]) {
            recentSongs.push(songs[j]);
            break;
          }
        }
      }
      AppStorage.setOrCreate('recentSongs', recentSongs);

      const playlists = await PlaylistRepository.getAll();
      AppStorage.setOrCreate('playlists', playlists);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init repositories: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    // 释放 PlayerService
    PlayerService.getInstance().release();
    PlaybackSession.getInstance().destroy(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
