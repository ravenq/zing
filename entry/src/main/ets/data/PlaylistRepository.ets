import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Playlist } from '../models';
import { StorageName } from '../common/Constants';
import { generateId } from '../common/Theme';

const KEY_PLAYLISTS = 'playlists';

/**
 * 歌单仓库：整个歌单数组以 JSON 形式存入 preferences，支持完整 CRUD。
 */
class PlaylistRepositoryImpl {
  private pref: preferences.Preferences | null = null;
  private playlists: Playlist[] = [];

  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, StorageName.PLAYLIST);
      const stored: string = await this.pref.get(KEY_PLAYLISTS, '') as string;
      if (stored.length > 0) {
        const parsed: object = JSON.parse(stored) as object;
        if (Array.isArray(parsed)) {
          this.playlists = parsed as Playlist[];
        }
      }
    } catch (err) {
      console.error(`PlaylistRepository init failed: ${JSON.stringify(err)}`);
      this.playlists = [];
    }
  }

  /**
   * 新建歌单，返回创建后的 Playlist 对象。
   */
  async create(name: string): Promise<Playlist> {
    const now: number = Date.now();
    const playlist: Playlist = {
      id: generateId(),
      name: name,
      coverUri: undefined,
      songIds: [],
      createdAt: now,
      updatedAt: now
    };
    try {
      this.playlists.push(playlist);
      await this.persist();
    } catch (err) {
      console.error(`PlaylistRepository create failed: ${JSON.stringify(err)}`);
    }
    return playlist;
  }

  /**
   * 删除指定歌单。
   */
  async delete(id: string): Promise<void> {
    try {
      const idx: number = this.findIndex(id);
      if (idx >= 0) {
        this.playlists.splice(idx, 1);
        await this.persist();
      }
    } catch (err) {
      console.error(`PlaylistRepository delete failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 重命名指定歌单。
   */
  async rename(id: string, name: string): Promise<void> {
    try {
      const idx: number = this.findIndex(id);
      if (idx >= 0) {
        this.playlists[idx].name = name;
        this.playlists[idx].updatedAt = Date.now();
        await this.persist();
      }
    } catch (err) {
      console.error(`PlaylistRepository rename failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 向歌单添加歌曲（已存在则跳过）。
   */
  async addSong(playlistId: string, songId: string): Promise<void> {
    try {
      const idx: number = this.findIndex(playlistId);
      if (idx >= 0) {
        const songIds: string[] = this.playlists[idx].songIds;
        if (songIds.indexOf(songId) < 0) {
          songIds.push(songId);
          this.playlists[idx].updatedAt = Date.now();
          await this.persist();
        }
      }
    } catch (err) {
      console.error(`PlaylistRepository addSong failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 从歌单移除歌曲。
   */
  async removeSong(playlistId: string, songId: string): Promise<void> {
    try {
      const idx: number = this.findIndex(playlistId);
      if (idx >= 0) {
        const songIds: string[] = this.playlists[idx].songIds;
        const sIdx: number = songIds.indexOf(songId);
        if (sIdx >= 0) {
          songIds.splice(sIdx, 1);
          this.playlists[idx].updatedAt = Date.now();
          await this.persist();
        }
      }
    } catch (err) {
      console.error(`PlaylistRepository removeSong failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 获取全部歌单。
   */
  async getAll(): Promise<Playlist[]> {
    return this.playlists.slice();
  }

  /**
   * 按 id 获取单个歌单，不存在返回 null。
   */
  async getById(id: string): Promise<Playlist | null> {
    const idx: number = this.findIndex(id);
    if (idx >= 0) {
      return this.playlists[idx];
    }
    return null;
  }

  private findIndex(id: string): number {
    for (let i = 0; i < this.playlists.length; i++) {
      if (this.playlists[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  private async persist(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_PLAYLISTS, JSON.stringify(this.playlists));
      await this.pref.flush();
    } catch (err) {
      console.error(`PlaylistRepository persist failed: ${JSON.stringify(err)}`);
    }
  }
}

export const PlaylistRepository = new PlaylistRepositoryImpl();
