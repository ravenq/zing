import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Song } from '../models';
import { StorageName } from '../common/Constants';

const KEY_FAVORITE_IDS = 'favorite_ids';

/**
 * 收藏管理仓库：基于 preferences 持久化收藏的歌曲ID列表，内存缓存以支持同步查询。
 */
class FavoriteRepositoryImpl {
  private pref: preferences.Preferences | null = null;
  private favoriteIds: string[] = [];

  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, StorageName.FAVORITE);
      const stored: string = await this.pref.get(KEY_FAVORITE_IDS, '') as string;
      if (stored.length > 0) {
        const parsed: object = JSON.parse(stored) as object;
        if (Array.isArray(parsed)) {
          this.favoriteIds = parsed as string[];
        }
      }
    } catch (err) {
      console.error(`FavoriteRepository init failed: ${JSON.stringify(err)}`);
      this.favoriteIds = [];
    }
  }

  /**
   * 切换某首歌曲的收藏状态，返回切换后的新状态。
   */
  async toggle(songId: string): Promise<boolean> {
    try {
      const idx: number = this.favoriteIds.indexOf(songId);
      if (idx >= 0) {
        this.favoriteIds.splice(idx, 1);
      } else {
        this.favoriteIds.push(songId);
      }
      await this.persist();
      return this.hasId(songId);
    } catch (err) {
      console.error(`FavoriteRepository toggle failed: ${JSON.stringify(err)}`);
      return this.hasId(songId);
    }
  }

  /**
   * 判断歌曲是否已收藏。
   */
  async isFavorite(songId: string): Promise<boolean> {
    return this.hasId(songId);
  }

  /**
   * 获取全部收藏的歌曲ID列表。
   */
  async getFavoriteIds(): Promise<string[]> {
    return this.favoriteIds.slice();
  }

  /**
   * 从全部歌曲中筛选出已收藏的歌曲。使用内存缓存，支持同步调用。
   */
  getFavoriteSongs(allSongs: Song[]): Song[] {
    const result: Song[] = [];
    for (let i = 0; i < allSongs.length; i++) {
      if (this.hasId(allSongs[i].id)) {
        result.push(allSongs[i]);
      }
    }
    return result;
  }

  private hasId(songId: string): boolean {
    return this.favoriteIds.indexOf(songId) >= 0;
  }

  private async persist(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_FAVORITE_IDS, JSON.stringify(this.favoriteIds));
      await this.pref.flush();
    } catch (err) {
      console.error(`FavoriteRepository persist failed: ${JSON.stringify(err)}`);
    }
  }
}

export const FavoriteRepository = new FavoriteRepositoryImpl();
