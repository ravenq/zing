import { picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Song, Artist, Album } from '../models';
import { AppStorageKey, StorageName } from '../common/Constants';
import { MediaDurationResolver } from '../services/MediaDurationResolver';

const KEY_SONGS = 'songs_cache';
const REPO_DOMAIN: number = 0xA002;
const REPO_TAG: string = 'ZingRepo';

/**
 * 歌曲元数据仓库：
 * - 扫描系统媒体库音频文件
 * - 通过文件选择器导入
 * - 缓存读取 / 按歌手或专辑分组 / 关键词搜索
 */
class MusicRepositoryImpl {
  private pref: preferences.Preferences | null = null;
  private context: common.Context | null = null;

  async init(context: common.Context): Promise<void> {
    try {
      this.context = context;
      this.pref = await preferences.getPreferences(context, StorageName.MUSIC_CACHE);
    } catch (err) {
      console.error(`MusicRepository init failed: ${JSON.stringify(err)}`);
    }
  }

  private ensureContext(): common.Context | null {
    if (this.context) {
      return this.context;
    }
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('context');
      return ctx ? ctx : null;
    } catch (e) {
      return null;
    }
  }

  private async ensurePref(): Promise<preferences.Preferences | null> {
    if (this.pref) {
      return this.pref;
    }
    try {
      const ctx = this.ensureContext();
      if (!ctx) {
        return null;
      }
      this.pref = await preferences.getPreferences(ctx, StorageName.MUSIC_CACHE);
      return this.pref;
    } catch (err) {
      console.error(`MusicRepository ensurePref failed: ${JSON.stringify(err)}`);
      return null;
    }
  }

  /**
   * 扫描系统媒体库音频文件。API 26 未提供枚举音频库的公开接口，保留空实现。
   */
  async scanFromMediaLibrary(): Promise<Song[]> {
    return [];
  }

  /**
   * 通过文件选择器导入音频文件，返回 Song 数组。
   */
  async importFromPicker(): Promise<Song[]> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 100;
      documentSelectOptions.fileSuffixFilters = ['.mp3', '.flac', '.wav', '.aac', '.ogg'];
      const documentPicker = new picker.DocumentViewPicker();
      const uris: string[] = await documentPicker.select(documentSelectOptions);
      if (!uris || uris.length === 0) {
        return [];
      }
      const songs: Song[] = [];
      for (let i = 0; i < uris.length; i++) {
        const uri: string = uris[i];
        const song: Song = {
          id: uri,
          title: this.extractFileName(uri),
          artist: '未知歌手',
          album: '未知专辑',
          duration: 0,
          filePath: uri,
          fileSize: 0,
          coverUri: undefined,
          favorite: false
        };
        songs.push(song);
      }
      return songs;
    } catch (err) {
      console.error(`importFromPicker failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 获取全部歌曲：优先从缓存读取，缓存为空时扫描媒体库。
   */
  async getAllSongs(): Promise<Song[]> {
    try {
      const cached = await this.loadCachedSongs();
      if (cached.length > 0) {
        return cached;
      }
      return await this.scanFromMediaLibrary();
    } catch (err) {
      console.error(`getAllSongs failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 按歌手分组返回 Artist 列表。
   */
  async getSongsByArtist(): Promise<Artist[]> {
    try {
      const songs: Song[] = await this.getAllSongs();
      const map: Map<string, Artist> = new Map<string, Artist>();
      for (let i = 0; i < songs.length; i++) {
        const song: Song = songs[i];
        const key: string = (song.artist && song.artist.length > 0) ? song.artist : '未知歌手';
        let artist: Artist | undefined = map.get(key);
        if (!artist) {
          artist = {
            name: key,
            songCount: 0,
            coverUri: undefined,
            songIds: []
          };
          map.set(key, artist);
        }
        artist.songIds.push(song.id);
        artist.songCount = artist.songIds.length;
        if (!artist.coverUri && song.coverUri) {
          artist.coverUri = song.coverUri;
        }
      }
      const result: Artist[] = [];
      map.forEach((artist: Artist) => {
        result.push(artist);
      });
      return result;
    } catch (err) {
      console.error(`getSongsByArtist failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 按专辑分组返回 Album 列表。
   */
  async getSongsByAlbum(): Promise<Album[]> {
    try {
      const songs: Song[] = await this.getAllSongs();
      const map: Map<string, Album> = new Map<string, Album>();
      for (let i = 0; i < songs.length; i++) {
        const song: Song = songs[i];
        const key: string = (song.album && song.album.length > 0) ? song.album : '未知专辑';
        let album: Album | undefined = map.get(key);
        if (!album) {
          album = {
            name: key,
            artist: (song.artist && song.artist.length > 0) ? song.artist : '未知歌手',
            coverUri: undefined,
            songCount: 0,
            songIds: []
          };
          map.set(key, album);
        }
        album.songIds.push(song.id);
        album.songCount = album.songIds.length;
        if (!album.coverUri && song.coverUri) {
          album.coverUri = song.coverUri;
        }
      }
      const result: Album[] = [];
      map.forEach((album: Album) => {
        result.push(album);
      });
      return result;
    } catch (err) {
      console.error(`getSongsByAlbum failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 搜索歌曲：匹配标题/歌手/专辑（不区分大小写）。
   */
  async search(keyword: string): Promise<Song[]> {
    try {
      if (!keyword || keyword.trim().length === 0) {
        return [];
      }
      const kw: string = keyword.toLowerCase();
      const songs: Song[] = await this.getAllSongs();
      const result: Song[] = [];
      for (let i = 0; i < songs.length; i++) {
        const song: Song = songs[i];
        if (song.title.toLowerCase().includes(kw) ||
          song.artist.toLowerCase().includes(kw) ||
          song.album.toLowerCase().includes(kw)) {
          result.push(song);
        }
      }
      return result;
    } catch (err) {
      console.error(`search failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 缓存歌曲列表。
   */
  async cacheSongs(songs: Song[]): Promise<void> {
    try {
      const pref = await this.ensurePref();
      if (!pref) {
        return;
      }
      await pref.put(KEY_SONGS, JSON.stringify(songs));
      await pref.flush();
    } catch (err) {
      console.error(`cacheSongs failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 按 id 去重合并歌曲到本地库：更新 AppStorage 并写入缓存。
   */
  async mergeAndCache(songs: Song[]): Promise<Song[]> {
    let base: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
    if (base.length === 0) {
      base = await this.loadCachedSongs();
    }
    const merged: Song[] = base.slice();
    for (let i = 0; i < songs.length; i++) {
      hilog.info(REPO_DOMAIN, REPO_TAG, 'merge incoming id=%{public}s duration=%{public}d',
        songs[i].id, songs[i].duration);
      let existsIndex: number = -1;
      for (let j = 0; j < merged.length; j++) {
        if (merged[j].id === songs[i].id) {
          existsIndex = j;
          break;
        }
      }
      if (existsIndex < 0) {
        merged.push(songs[i]);
      } else {
        const previous: Song = merged[existsIndex];
        merged[existsIndex] = {
          id: songs[i].id,
          title: songs[i].title,
          artist: songs[i].artist,
          album: songs[i].album,
          duration: songs[i].duration,
          filePath: songs[i].filePath,
          fileHeaders: songs[i].fileHeaders,
          fileSize: songs[i].fileSize,
          coverUri: songs[i].coverUri,
          favorite: previous.favorite,
          lyrics: songs[i].lyrics ? songs[i].lyrics : previous.lyrics
        };
      }
      hilog.info(REPO_DOMAIN, REPO_TAG, 'merge result idx=%{public}d duration=%{public}d',
        existsIndex, merged[existsIndex >= 0 ? existsIndex : merged.length - 1].duration);
    }
    AppStorage.setOrCreate(AppStorageKey.ALL_SONGS, merged);
    await this.cacheSongs(merged);
    hilog.info(REPO_DOMAIN, REPO_TAG, 'merge done total=%{public}d', merged.length);
    return merged;
  }

  /**
   * 启动时为时长缺失（duration<=0）的本地歌曲批量回填真实时长。
   * 仅处理应用沙箱内的本地文件（file:// 或绝对路径），跳过 http 链接与
   * 文件选择器授予的 datashare:// URI。
   */
  async backfillMissingDurations(): Promise<void> {
    try {
      let songs: Song[] = AppStorage.get<Song[]>(AppStorageKey.ALL_SONGS) || [];
      if (songs.length === 0) {
        songs = await this.loadCachedSongs();
      }
      if (songs.length === 0) {
        return;
      }
      let updatedCount: number = 0;
      const updated: Song[] = songs.slice();
      for (let i = 0; i < updated.length; i++) {
        const song: Song = updated[i];
        if (song.duration > 0) {
          continue;
        }
        if (!this.isLocalFilePath(song.filePath)) {
          continue;
        }
        const resolved: number = await MediaDurationResolver.resolveMs(song.filePath);
        if (resolved > 0) {
          updated[i] = {
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: resolved,
            filePath: song.filePath,
            fileHeaders: song.fileHeaders,
            fileSize: song.fileSize,
            coverUri: song.coverUri,
            favorite: song.favorite,
            lyrics: song.lyrics
          };
          updatedCount++;
          hilog.info(REPO_DOMAIN, REPO_TAG, 'backfill id=%{public}s duration=%{public}d',
            song.id, resolved);
        }
      }
      if (updatedCount > 0) {
        AppStorage.setOrCreate(AppStorageKey.ALL_SONGS, updated);
        await this.cacheSongs(updated);
      }
      hilog.info(REPO_DOMAIN, REPO_TAG, 'backfill done updated=%{public}d', updatedCount);
    } catch (err) {
      hilog.info(REPO_DOMAIN, REPO_TAG, 'backfill failed: %{public}s', String(err));
    }
  }

  private isLocalFilePath(filePath: string): boolean {
    if (!filePath || filePath.length === 0) {
      return false;
    }
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return false;
    }
    if (filePath.startsWith('datashare://') || filePath.startsWith('file://datashare')) {
      return false;
    }
    if (filePath.startsWith('content://')) {
      return false;
    }
    if (filePath.startsWith('file://')) {
      return true;
    }
    return filePath.startsWith('/');
  }

  /**
   * 加载缓存的歌曲列表。
   */
  async loadCachedSongs(): Promise<Song[]> {
    try {
      const pref = await this.ensurePref();
      if (!pref) {
        return [];
      }
      const stored: string = await pref.get(KEY_SONGS, '') as string;
      if (stored.length === 0) {
        return [];
      }
      const parsed: object = JSON.parse(stored) as object;
      if (Array.isArray(parsed)) {
        return parsed as Song[];
      }
      return [];
    } catch (err) {
      console.error(`loadCachedSongs failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  private extractFileName(uri: string): string {
    try {
      const segments: string[] = uri.split('/');
      const last: string = segments[segments.length - 1];
      const dotIdx: number = last.lastIndexOf('.');
      if (dotIdx > 0) {
        return last.substring(0, dotIdx);
      }
      return last;
    } catch (e) {
      return '未知歌曲';
    }
  }
}

export const MusicRepository = new MusicRepositoryImpl();
