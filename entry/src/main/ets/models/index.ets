// 歌曲
export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: number;      // 毫秒
  filePath: string;      // 文件URI
  fileHeaders?: Record<string, string>;
  fileSize: number;
  coverUri?: string;
  favorite: boolean;
  lyrics?: string;        // 内嵌歌词文本（LRC格式）
}

// 歌手
export interface Artist {
  name: string;
  songCount: number;
  coverUri?: string;
  songIds: string[];
}

// 专辑
export interface Album {
  name: string;
  artist: string;
  coverUri?: string;
  songCount: number;
  songIds: string[];
}

// 歌单
export interface Playlist {
  id: string;
  name: string;
  coverUri?: string;
  songIds: string[];
  createdAt: number;
  updatedAt: number;
}

// 歌词行
export interface LyricLine {
  time: number;   // 毫秒
  text: string;
}

// 播放模式
export enum PlayMode {
  SEQUENCE = 0,    // 顺序播放
  REPEAT_ONE = 1,  // 单曲循环
  SHUFFLE = 2      // 随机播放
}

// 播放器状态
export enum PlayerState {
  IDLE = 'idle',
  INITIALIZED = 'initialized',
  PREPARED = 'prepared',
  PLAYING = 'playing',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  ERROR = 'error'
}
