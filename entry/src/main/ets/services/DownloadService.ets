import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DownloadTask, OnlineTrack } from '../models/OnlineTypes';
import { MediaDurationResolver } from './MediaDurationResolver';

const DL_DOMAIN: number = 0xA001;
const DL_TAG: string = 'ZingDl';
const DL_USER_AGENT: string = 'Mozilla/5.0 (compatible; ZingPlayer/1.0)';
const DL_CONNECT_TIMEOUT_MS: number = 15000;
const DL_READ_TIMEOUT_MS: number = 60000;

type TasksListener = (tasks: DownloadTask[]) => void;

function inferExtension(url: string): string {
  const queryIdx: number = url.indexOf('?');
  const path: string = queryIdx >= 0 ? url.substring(0, queryIdx) : url;
  const dotIdx: number = path.lastIndexOf('.');
  if (dotIdx >= 0) {
    const ext: string = path.substring(dotIdx);
    if (ext.length > 1 && ext.length <= 6) {
      return ext;
    }
  }
  return '.mp3';
}

class DownloadServiceImpl {
  private tasks: DownloadTask[] = [];
  private listeners: TasksListener[] = [];

  start(track: OnlineTrack): void {
    const key: string = this.keyOf(track.sourceId, track.id);
    for (let i = 0; i < this.tasks.length; i++) {
      const existing = this.tasks[i];
      if (this.keyOf(existing.sourceId, existing.trackId) === key) {
        if (existing.status === 'pending' || existing.status === 'running') {
          return;
        }
        this.tasks.splice(i, 1);
        break;
      }
    }

    const task: DownloadTask = {
      trackId: track.id,
      title: track.title,
      sourceId: track.sourceId,
      sourceName: track.sourceName,
      artist: track.artist,
      duration: track.duration,
      coverUrl: track.coverUrl,
      status: 'pending',
      progress: 0
    };
    this.tasks.push(task);
    this.emit();

    this.runDownload(track, task);
  }

  getTasks(): DownloadTask[] {
    return this.tasks.slice();
  }

  onTasksChange(listener: TasksListener): () => void {
    this.listeners.push(listener);
    listener(this.tasks.slice());
    return (): void => {
      const idx: number = this.listeners.indexOf(listener);
      if (idx >= 0) {
        this.listeners.splice(idx, 1);
      }
    };
  }

  private async runDownload(track: OnlineTrack, task: DownloadTask): Promise<void> {
    try {
      hilog.info(DL_DOMAIN, DL_TAG, 'start tid=%{public}s url=%{public}s', track.id,
        (track.downloadUrl && track.downloadUrl.length > 0 ? track.downloadUrl as string : track.streamUrl));
      const context: common.UIAbilityContext | undefined =
        AppStorage.get<common.UIAbilityContext>('context');
      if (!context) {
        throw new Error('上下文不可用');
      }
      const baseDir: string = context.filesDir + '/online';
      hilog.info(DL_DOMAIN, DL_TAG, 'baseDir=%{public}s', baseDir);
      try {
        fs.mkdirSync(baseDir, true);
        hilog.info(DL_DOMAIN, DL_TAG, 'mkdir ok');
      } catch (mkdirErr) {
        const mkdirMsg: string = String(mkdirErr);
        if (mkdirMsg.indexOf('exist') >= 0) {
          hilog.info(DL_DOMAIN, DL_TAG, 'mkdir already exists');
        } else {
          hilog.error(DL_DOMAIN, DL_TAG, 'mkdir err: %{public}s', mkdirMsg);
          throw new Error('创建目录失败: ' + mkdirMsg);
        }
      }
      const extension: string = inferExtension(track.downloadUrl && track.downloadUrl.length > 0
        ? track.downloadUrl as string : track.streamUrl);
      const fileName: string = track.id + extension;
      const targetPath: string = baseDir + '/' + fileName;
      try {
        fs.unlinkSync(targetPath);
        hilog.info(DL_DOMAIN, DL_TAG, 'removed stale file');
      } catch (unlinkErr) {
        hilog.info(DL_DOMAIN, DL_TAG, 'no stale file');
      }

      task.status = 'running';
      this.emit();

      const downloadUrl: string = track.downloadUrl && track.downloadUrl.length > 0
        ? track.downloadUrl as string : track.streamUrl;
      const headers: Record<string, string> = { 'User-Agent': DL_USER_AGENT };
      if (track.streamHeaders) {
        const headerKeys = Object.keys(track.streamHeaders);
        for (let i = 0; i < headerKeys.length; i++) {
          headers[headerKeys[i]] = (track.streamHeaders as Record<string, string>)[headerKeys[i]];
        }
      }

      const headerDumpKeys = Object.keys(headers);
      let headerDump: string = '';
      for (let h = 0; h < headerDumpKeys.length; h++) {
        headerDump += headerDumpKeys[h] + '=' + headers[headerDumpKeys[h]] + ' | ';
      }
      hilog.info(DL_DOMAIN, DL_TAG, 'sending headers: %{public}s', headerDump);

      const httpRequest = http.createHttp();
      try {
        hilog.info(DL_DOMAIN, DL_TAG, 'before http request');
        task.progress = 10;
        this.emit();

        const response = await httpRequest.request(downloadUrl, {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: DL_CONNECT_TIMEOUT_MS,
          readTimeout: DL_READ_TIMEOUT_MS,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        });
        hilog.info(DL_DOMAIN, DL_TAG, 'http resolved code=%{public}d', response.responseCode);

        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error('HTTP ' + response.responseCode);
        }

        const buffer = response.result as ArrayBuffer;
        hilog.info(DL_DOMAIN, DL_TAG, 'response bytes=%{public}d', buffer.byteLength);
        if (buffer.byteLength <= 0) {
          throw new Error('下载内容为空');
        }

        task.progress = 80;
        this.emit();

        const file = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        try {
          fs.writeSync(file.fd, buffer);
          fs.fsyncSync(file.fd);
        } finally {
          fs.closeSync(file);
        }

        hilog.info(DL_DOMAIN, DL_TAG, 'download complete path=%{public}s', targetPath);
        const resolvedDuration: number = await MediaDurationResolver.resolveMs(targetPath);
        if (resolvedDuration > 0) {
          task.duration = resolvedDuration;
          hilog.info(DL_DOMAIN, DL_TAG, 'resolved duration ms=%{public}d', resolvedDuration);
        }
        task.status = 'completed';
        task.progress = 100;
        task.localPath = 'file://' + targetPath;
        this.emit();
      } catch (e) {
        try {
          fs.unlinkSync(targetPath);
        } catch (cleanErr) {
          hilog.error(DL_DOMAIN, DL_TAG, 'clean err: %{public}s', String(cleanErr));
        }
        hilog.error(DL_DOMAIN, DL_TAG, 'http download err: %{public}s', String(e));
        task.status = 'failed';
        task.error = String(e);
        this.emit();
        return;
      } finally {
        httpRequest.destroy();
      }
    } catch (e) {
      hilog.error(DL_DOMAIN, DL_TAG, 'runDownload catch: %{public}s', String(e));
      task.status = 'failed';
      task.error = String(e);
      this.emit();
    }
  }

  private keyOf(sourceId: string, trackId: string): string {
    return sourceId + ':' + trackId;
  }

  private emit(): void {
    const snapshot: DownloadTask[] = this.tasks.slice();
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i](snapshot);
    }
  }
}

export const DownloadService = new DownloadServiceImpl();
