import { Song } from '../models/index';
import { DownloadTask, OnlineTrack, SourceFailure } from '../models/OnlineTypes';
import { AppStorageKey, RouterPath } from '../common/Constants';
import { OnlineTrackItem } from '../components/OnlineTrackItem';
import { PlayerService } from '../services/PlayerService';
import { DownloadService } from '../services/DownloadService';
import { MusicRepository } from '../data/MusicRepository';
import { SourceRepository } from '../data/SourceRepository';
import { SourceRegistry } from '../services/online/SourceRegistry';
import { buildDownloadSongId, buildOnlineSongId } from '../services/online/JsonPath';

interface TrackGroup {
  sourceId: string;
  sourceName: string;
  tracks: OnlineTrack[];
}

@Entry
@Component
struct OnlineSearchPage {
  @State keyword: string = '';
  @State groups: TrackGroup[] = [];
  @State failedSources: SourceFailure[] = [];
  @State notReadyNames: string[] = [];
  @State bannerText: string = '';
  @State hasSearched: boolean = false;
  @State searching: boolean = false;
  @State taskMap: Record<string, DownloadTask> = {};
  @StorageProp(AppStorageKey.CURRENT_SONG) currentSong: Song | null = null;
  private searchToken: number = 0;
  private unsubscribeTasks: (() => void) | null = null;
  private handledCompleted: string[] = [];

  aboutToAppear(): void {
    this.unsubscribeTasks = DownloadService.onTasksChange((tasks: DownloadTask[]): void => {
      const map: Record<string, DownloadTask> = {};
      for (let i = 0; i < tasks.length; i++) {
        const key: string = tasks[i].sourceId + ':' + tasks[i].trackId;
        map[key] = tasks[i];
      }
      this.taskMap = map;
      this.handleTasksChange(tasks);
    });
  }

  aboutToDisappear(): void {
    if (this.unsubscribeTasks) {
      this.unsubscribeTasks();
      this.unsubscribeTasks = null;
    }
  }

  private async handleTasksChange(tasks: DownloadTask[]): Promise<void> {
    for (let i = 0; i < tasks.length; i++) {
      const task = tasks[i];
      const key: string = task.sourceId + ':' + task.trackId;
      if (task.status === 'completed') {
        let handled: boolean = false;
        for (let j = 0; j < this.handledCompleted.length; j++) {
          if (this.handledCompleted[j] === key) {
            handled = true;
            break;
          }
        }
        if (handled || !task.localPath) {
          continue;
        }
        this.handledCompleted.push(key);
        await this.onDownloadCompleted(task);
      }
    }
  }

  private async onDownloadCompleted(task: DownloadTask): Promise<void> {
    let autoAdd: boolean;
    try {
      autoAdd = await SourceRepository.getAutoAdd();
    } catch (e) {
      autoAdd = true;
    }
    if (!autoAdd) {
      this.getUIContext().getPromptAction().showToast({ message: '已保存到设备' });
      return;
    }
    const song: Song = {
      id: buildDownloadSongId(task.sourceId, task.trackId),
      title: task.title,
      artist: task.artist,
      album: task.sourceName,
      duration: task.duration,
      filePath: task.localPath as string,
      fileSize: 0,
      coverUri: task.coverUrl,
      favorite: false
    };
    try {
      await MusicRepository.mergeAndCache([song]);
      this.getUIContext().getPromptAction().showToast({ message: '已下载并加入本地库' });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '已下载，加入本地库失败' });
    }
  }

  private allTracks(): OnlineTrack[] {
    const list: OnlineTrack[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const tracks = this.groups[i].tracks;
      for (let j = 0; j < tracks.length; j++) {
        list.push(tracks[j]);
      }
    }
    return list;
  }

  private refreshNotReady(): void {
    const sources = SourceRegistry.getSources();
    const names: string[] = [];
    for (let i = 0; i < sources.length; i++) {
      const source = sources[i];
      if (source.config.enabled && !source.isReady()) {
        names.push(source.config.id === 'jamendo' ? 'Jamendo 未配置 client_id' : source.config.name + ' 未就绪');
      }
    }
    this.notReadyNames = names;
  }

  private refreshBanner(): void {
    const parts: string[] = this.notReadyNames.slice();
    for (let i = 0; i < this.failedSources.length; i++) {
      const failure = this.failedSources[i];
      let reason: string = failure.reason;
      const errorPrefix: string = 'Error: ';
      if (reason.startsWith(errorPrefix)) {
        reason = reason.substring(errorPrefix.length);
      }
      if (reason.length > 0) {
        parts.push(failure.sourceName + ' ' + reason);
      } else {
        parts.push(failure.sourceName + ' 音源暂不可用');
      }
    }
    this.bannerText = parts.join('；');
  }

  private async doSearch() {
    const token: number = ++this.searchToken;
    const text: string = this.keyword.trim();
    if (text.length === 0) {
      this.groups = [];
      this.failedSources = [];
      this.bannerText = '';
      this.hasSearched = false;
      return;
    }
    this.searching = true;
    this.hasSearched = true;
    try {
      const result = await SourceRegistry.searchAll(text);
      if (token !== this.searchToken) {
        return;
      }
      const groupMap: Record<string, TrackGroup> = {};
      const order: string[] = [];
      for (let i = 0; i < result.tracks.length; i++) {
        const track = result.tracks[i];
        let group = groupMap[track.sourceId];
        if (!group) {
          group = { sourceId: track.sourceId, sourceName: track.sourceName, tracks: [] };
          groupMap[track.sourceId] = group;
          order.push(track.sourceId);
        }
        group.tracks.push(track);
      }
      const list: TrackGroup[] = [];
      for (let i = 0; i < order.length; i++) {
        list.push(groupMap[order[i]]);
      }
      this.groups = list;
      this.failedSources = result.failedSources;
      this.refreshNotReady();
      this.refreshBanner();
    } catch (e) {
      if (token === this.searchToken) {
        this.groups = [];
        this.failedSources = [];
        this.refreshNotReady();
        this.refreshBanner();
      }
    }
    if (token === this.searchToken) {
      this.searching = false;
    }
  }

  private playTrack(track: OnlineTrack) {
    const songs = SourceRegistry.toPlayableSongs(this.allTracks());
    const targetId: string = buildOnlineSongId(track.sourceId, track.id);
    let index: number = -1;
    for (let i = 0; i < songs.length; i++) {
      if (songs[i].id === targetId) {
        index = i;
        break;
      }
    }
    if (index >= 0) {
      PlayerService.getInstance().playQueue(songs, index);
    }
  }

  private requestDownload(track: OnlineTrack) {
    if (!track.downloadable) {
      this.getUIContext().getPromptAction().showToast({ message: '该曲目版权方未开放下载，仅可试听' });
      return;
    }
    DownloadService.start(track);
  }

  private taskOf(sourceId: string, trackId: string): DownloadTask | null {
    const task: DownloadTask | undefined = this.taskMap[sourceId + ':' + trackId];
    return task ?? null;
  }

  private clearKeyword() {
    this.keyword = '';
    this.groups = [];
    this.failedSources = [];
    this.bannerText = '';
    this.hasSearched = false;
  }

  private goSourceManage() {
    this.getUIContext().getRouter().pushUrl({ url: RouterPath.SOURCE_MANAGE });
  }

  @Builder
  groupHeader(group: TrackGroup) {
    Row() {
      Text(group.sourceName + '（' + group.tracks.length + '）')
        .fontSize(13)
        .fontColor($r('app.color.text_sub'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
    .backgroundColor($r('app.color.bg_gray'))
  }

  build() {
    Column() {
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
          TextInput({ text: this.keyword, placeholder: '搜索在线音乐' })
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

        Text('音源')
          .fontSize(14)
          .fontColor($r('app.color.primary'))
          .margin({ left: 8, right: 12 })
          .onClick(() => this.goSourceManage())
      }
      .width('100%')
      .height(56)
      .padding({ left: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Divider().color($r('app.color.divider'))

      if (this.hasSearched && this.bannerText.length > 0) {
        Row() {
          Text('⚠')
            .fontSize(13)
            .fontColor('#E6942B')
            .margin({ right: 6 })
          Text(this.bannerText)
            .fontSize(12)
            .fontColor($r('app.color.text_sub'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('去配置 >')
            .fontSize(12)
            .fontColor($r('app.color.primary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FFF7E8')
        .onClick(() => this.goSourceManage())
      }

      if (!this.hasSearched) {
        Column() {
          Text('⌕')
            .fontSize(48)
          Text('输入关键词搜索在线音乐')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.searching && this.groups.length === 0) {
        Column() {
          Text('搜索中...')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.groups.length === 0) {
        Column() {
          Text('网络不可用或所有音源暂不可用')
            .fontSize(15)
            .fontColor($r('app.color.text_sub'))
          Text('去音源设置')
            .fontSize(14)
            .fontColor($r('app.color.primary'))
            .margin({ top: 12 })
            .padding({ left: 20, top: 6, right: 20, bottom: 6 })
            .border({ width: 1, color: $r('app.color.primary'), radius: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.goSourceManage())
      } else {
        List({ space: 0 }) {
          ForEach(this.groups, (group: TrackGroup) => {
            ListItem() {
              this.groupHeader(group)
            }

            ForEach(group.tracks, (track: OnlineTrack) => {
              ListItem() {
                OnlineTrackItem({
                  track: track,
                  task: this.taskOf(track.sourceId, track.id),
                  isPlaying: this.currentSong?.id === buildOnlineSongId(track.sourceId, track.id),
                  onPlay: (t: OnlineTrack) : void => this.playTrack(t),
                  onDownload: (t: OnlineTrack) : void => this.requestDownload(t)
                })
              }
            }, (track: OnlineTrack) => track.sourceId + ':' + track.id)
          }, (group: TrackGroup) => group.sourceId)
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
