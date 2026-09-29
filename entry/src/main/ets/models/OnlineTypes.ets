export type SourceKind = 'builtin' | 'rss' | 'jsonapi';

export interface OnlineTrack {
  id: string;
  sourceId: string;
  sourceName: string;
  title: string;
  artist: string;
  duration: number;
  streamUrl: string;
  streamHeaders?: Record<string, string>;
  coverUrl?: string;
  licenseName?: string;
  licenseUrl?: string;
  downloadUrl?: string;
  downloadable: boolean;
}

export interface JsonFieldMapping {
  listPath: string;
  id: string;
  title: string;
  artist: string;
  duration?: string;
  streamUrl: string;
  coverUrl?: string;
  downloadUrl?: string;
  licenseName?: string;
  licenseUrl?: string;
}

export interface MusicSourceConfig {
  id: string;
  name: string;
  kind: SourceKind;
  enabled: boolean;
  url?: string;
  mapping?: JsonFieldMapping;
  headers?: Record<string, string>;
  builtin?: boolean;
}

export type DownloadStatus = 'pending' | 'running' | 'completed' | 'failed';

export interface DownloadTask {
  trackId: string;
  title: string;
  sourceId: string;
  sourceName: string;
  artist: string;
  duration: number;
  coverUrl?: string;
  status: DownloadStatus;
  progress: number;
  localPath?: string;
  error?: string;
}

export interface SourceFailure {
  sourceId: string;
  sourceName: string;
  reason: string;
}
