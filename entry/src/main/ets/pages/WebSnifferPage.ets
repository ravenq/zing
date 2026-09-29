import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Song } from '../models/index';
import { DownloadTask, OnlineTrack } from '../models/OnlineTypes';
import { DownloadService } from '../services/DownloadService';
import { MusicRepository } from '../data/MusicRepository';
import { PlayerService } from '../services/PlayerService';

type MediaKind = 'audio' | 'hls';

const SNIFF_LOG_DOMAIN: number = 0xA003;
const SNIFF_LOG_TAG: string = 'ZingSniff';

interface SniffedMedia {
  id: string;
  url: string;
  name: string;
  kind: MediaKind;
  headers: Record<string, string>;
}

const SNIFF_SOURCE_ID: string = 'websniff';
const SNIFF_SOURCE_NAME: string = '网页嗅探';

function stripQuery(url: string): string {
  const queryIdx: number = url.indexOf('?');
  return queryIdx >= 0 ? url.substring(0, queryIdx) : url;
}

function isHttpUrl(url: string): boolean {
  return url.startsWith('http://') || url.startsWith('https://');
}

function detectKind(url: string): MediaKind | null {
  if (!isHttpUrl(url)) {
    return null;
  }
  const path: string = stripQuery(url);
  if (/\.(m3u8)$/i.test(path)) {
    return 'hls';
  }
  if (/\.(mp3|m4a|flac|aac|ogg|wav|opus)$/i.test(path)) {
    return 'audio';
  }
  return null;
}

function isHopByHop(key: string): boolean {
  const lower: string = key.toLowerCase();
  return lower === 'range' || lower === 'host' || lower === 'content-length' ||
    lower === 'connection' || lower === 'accept-encoding';
}

function hasHeader(headers: Record<string, string>, name: string): boolean {
  const target: string = name.toLowerCase();
  const keys: string[] = Object.keys(headers);
  for (let i = 0; i < keys.length; i++) {
    if (keys[i].toLowerCase() === target) {
      return true;
    }
  }
  return false;
}

function extractHeaders(raw: Array<Header>): Record<string, string> {
  const result: Record<string, string> = {};
  for (let i = 0; i < raw.length; i++) {
    const item: Header = raw[i];
    if (!item.headerKey || isHopByHop(item.headerKey)) {
      continue;
    }
    result[item.headerKey] = item.headerValue;
  }
  return result;
}

function stableId(url: string): string {
  let hash: number = 0;
  for (let i = 0; i < url.length; i++) {
    hash = (hash * 31 + url.charCodeAt(i)) | 0;
  }
  return 'm' + (hash >>> 0).toString(36);
}

function guessName(url: string): string {
  try {
    const queryIdx: number = url.indexOf('?');
    const path: string = queryIdx >= 0 ? url.substring(0, queryIdx) : url;
    const segments: string[] = path.split('/');
    const last: string = segments[segments.length - 1];
    const dotIdx: number = last.lastIndexOf('.');
    const base: string = dotIdx > 0 ? last.substring(0, dotIdx) : last;
    return decodeURIComponent(base);
  } catch (e) {
    return '未知音频';
  }
}

@Entry
@Component
struct WebSnifferPage {
  @State addressInput: string = 'https://www.maitianyinyue.com/';
  @State medias: SniffedMedia[] = [];
  @State showPanel: boolean = true;
  @State loading: boolean = false;
  @State taskMap: Record<string, DownloadTask> = {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private unsubscribeTasks: (() => void) | null = null;
  private handledCompleted: string[] = [];
  private handledTask: DownloadTask[] = [];

  aboutToAppear(): void {
    this.unsubscribeTasks = DownloadService.onTasksChange((tasks: DownloadTask[]): void => {
      const map: Record<string, DownloadTask> = {};
      for (let i = 0; i < tasks.length; i++) {
        const task = tasks[i];
        map[task.trackId] = task;
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
      if (task.status !== 'completed' || !task.localPath) {
        continue;
      }
      let handled: boolean = false;
      for (let j = 0; j < this.handledCompleted.length; j++) {
        if (this.handledCompleted[j] === task.trackId && this.handledTask[j] === task) {
          handled = true;
          break;
        }
      }
      if (handled) {
        continue;
      }
      const existed: number = this.handledCompleted.indexOf(task.trackId);
      if (existed >= 0) {
        this.handledTask[existed] = task;
      } else {
        this.handledCompleted.push(task.trackId);
        this.handledTask.push(task);
      }
      hilog.info(SNIFF_LOG_DOMAIN, SNIFF_LOG_TAG, 'ready to merge tid=%{public}s duration=%{public}d path=%{public}s',
        task.trackId, task.duration, task.localPath);
      const song: Song = {
        id: 'download:' + SNIFF_SOURCE_ID + ':' + task.trackId,
        title: task.title,
        artist: task.artist,
        album: task.sourceName,
        duration: task.duration,
        filePath: task.localPath as string,
        fileSize: 0,
        coverUri: task.coverUrl,
        favorite: false
      };
      await MusicRepository.mergeAndCache([song]);
      this.getUIContext().getPromptAction().showToast({ message: '已下载并加入本地库' });
    }
  }

  private onSniffed(url: string, headers: Record<string, string>): void {
    const kind: MediaKind | null = detectKind(url);
    if (!kind) {
      return;
    }
    const id: string = stableId(url);
    for (let i = 0; i < this.medias.length; i++) {
      if (this.medias[i].id === id) {
        return;
      }
    }
    const media: SniffedMedia = {
      id: id,
      url: url,
      name: guessName(url),
      kind: kind as MediaKind,
      headers: headers
    };
    this.medias = [media].concat(this.medias);
  }

  private normalizeAddress(raw: string): string {
    let text: string = raw.trim();
    if (text.length === 0) {
      return '';
    }
    if (text.indexOf('://') < 0) {
      text = 'http://' + text;
    }
    return text;
  }

  private loadAddress(): void {
    const url: string = this.normalizeAddress(this.addressInput);
    if (url.length === 0) {
      return;
    }
    this.loading = true;
    try {
      this.controller.loadUrl(url);
    } catch (e) {
      this.loading = false;
      this.getUIContext().getPromptAction().showToast({ message: '无法加载该地址' });
    }
  }

  private buildTrack(media: SniffedMedia): OnlineTrack {
    return {
      id: media.id,
      sourceId: SNIFF_SOURCE_ID,
      sourceName: SNIFF_SOURCE_NAME,
      title: media.name,
      artist: '网页来源',
      duration: 0,
      streamUrl: media.url,
      streamHeaders: media.headers,
      downloadUrl: media.url,
      downloadable: true
    };
  }

  private previewMedia(media: SniffedMedia): void {
    const track: OnlineTrack = this.buildTrack(media);
    const song: Song = {
      id: 'online:' + SNIFF_SOURCE_ID + ':' + media.id,
      title: track.title,
      artist: track.artist,
      album: track.sourceName,
      duration: 0,
      filePath: track.streamUrl,
      fileSize: 0,
      coverUri: undefined,
      favorite: false
    };
    PlayerService.getInstance().playQueue([song], 0);
  }

  private statusText(media: SniffedMedia): string {
    if (media.kind === 'hls') {
      return 'HLS 流媒体 · 可试听，暂不支持保存';
    }
    const task: DownloadTask | undefined = this.taskMap[media.id];
    if (!task) {
      return '已嗅探';
    }
    if (task.status === 'pending') {
      return '等待下载…';
    }
    if (task.status === 'running') {
      return '下载中 ' + Math.round(task.progress) + '%';
    }
    if (task.status === 'failed') {
      return '下载失败 · 可重试';
    }
    return '已加入本地库';
  }

  private saveLabel(media: SniffedMedia): string {
    const task: DownloadTask | undefined = this.taskMap[media.id];
    if (task && task.status === 'failed') {
      return '重试';
    }
    if (task && task.status === 'completed') {
      return '已保存';
    }
    return '保存';
  }

  private saveMedia(media: SniffedMedia): void {
    if (media.kind === 'hls') {
      this.getUIContext().getPromptAction().showToast({ message: 'HLS 分片流暂不支持保存' });
      return;
    }
    const task: DownloadTask | undefined = this.taskMap[media.id];
    if (task && (task.status === 'pending' || task.status === 'running')) {
      return;
    }
    DownloadService.start(this.buildTrack(media));
  }

  private clearMedias(): void {
    this.medias = [];
  }

  @Builder
  saveButton(media: SniffedMedia) {
    if (media.kind === 'hls') {
      Text('不可保存')
        .fontSize(12)
        .fontColor($r('app.color.text_sub'))
        .backgroundColor($r('app.color.bg_gray'))
        .padding({ left: 12, top: 6, right: 12, bottom: 6 })
        .borderRadius(14)
    } else {
      Text(this.saveLabel(media))
        .fontSize(12)
        .fontColor($r('app.color.bg_white'))
        .backgroundColor($r('app.color.primary'))
        .padding({ left: 12, top: 6, right: 12, bottom: 6 })
        .borderRadius(14)
        .opacity(this.saveLabel(media) === '已保存' ? 0.5 : 1)
        .onClick(() => this.saveMedia(media))
    }
  }

  @Builder
  mediaRow(media: SniffedMedia) {
    Row() {
      Column() {
        Text(media.name)
          .fontSize(14)
          .fontColor($r('app.color.text_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.statusText(media))
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('试听')
        .fontSize(12)
        .fontColor($r('app.color.primary'))
        .padding({ left: 12, top: 6, right: 12, bottom: 6 })
        .margin({ right: 8 })
        .onClick(() => this.previewMedia(media))
      this.saveButton(media)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
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
          TextInput({ text: this.addressInput, placeholder: '输入网址' })
            .fontSize(13)
            .fontColor($r('app.color.text_main'))
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.addressInput = value;
            })
            .onSubmit(() => this.loadAddress())
          Text('前往')
            .fontSize(13)
            .fontColor($r('app.color.primary'))
            .margin({ left: 8, right: 10 })
            .onClick(() => this.loadAddress())
        }
        .layoutWeight(1)
        .height(36)
        .backgroundColor($r('app.color.bg_gray'))
        .borderRadius(18)
        .alignItems(VerticalAlign.Center)
        .margin({ left: 8 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.bg_white'))

      Column() {
        Web({ src: this.addressInput, controller: this.controller })
          .domStorageAccess(true)
          .mediaPlayGestureAccess(false)
          .onPageBegin((event?: OnPageBeginEvent) => {
            this.loading = true;
            if (event) {
              this.addressInput = event.url;
            }
          })
          .onPageEnd(() => {
            this.loading = false;
          })
          .onErrorReceive(() => {
            this.loading = false;
          })
          .onInterceptRequest((event: OnInterceptRequestEvent): WebResourceResponse | null => {
            const headers: Record<string, string> = extractHeaders(event.request.getRequestHeader());
            if (!hasHeader(headers, 'Referer')) {
              try {
                headers['Referer'] = this.controller.getUrl();
              } catch (e) {
              }
            }
            this.onSniffed(event.request.getRequestUrl(), headers);
            return null;
          })
      }
      .layoutWeight(1)
      .width('100%')

      Column() {
        Row() {
          Text('嗅探到的音频（' + this.medias.length + '）')
            .fontSize(13)
            .fontColor($r('app.color.text_main'))
          Blank()
          if (this.medias.length > 0) {
            Text('清空')
              .fontSize(12)
              .fontColor($r('app.color.text_sub'))
              .margin({ right: 12 })
              .onClick(() => this.clearMedias())
          }
          Text(this.showPanel ? '▾' : '▸')
            .fontSize(14)
            .fontColor($r('app.color.text_sub'))
            .onClick(() => {
              this.showPanel = !this.showPanel;
            })
        }
        .width('100%')
        .height(40)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        if (this.showPanel) {
          if (this.medias.length === 0) {
            Column() {
              Text('暂无音频，请在网页中播放音乐')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .height(64)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 0 }) {
              ForEach(this.medias, (media: SniffedMedia) => {
                ListItem() {
                  this.mediaRow(media)
                }
              }, (media: SniffedMedia) => media.id)
            }
            .width('100%')
            .height(220)
            .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 16, endMargin: 16 })
          }
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.bg_white'))
      .border({ width: { top: 0.5 }, color: $r('app.color.divider') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_white'))
  }
}
