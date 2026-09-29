import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { StorageName, DefaultValue } from '../common/Constants';

const KEY_HISTORY_IDS = 'history_ids';

/**
 * 最近播放记录仓库：基于 preferences 持久化，最多保留 MAX_HISTORY 条，新记录置顶并去重。
 */
class HistoryRepositoryImpl {
  private pref: preferences.Preferences | null = null;
  private history: string[] = [];

  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, StorageName.HISTORY);
      const stored: string = await this.pref.get(KEY_HISTORY_IDS, '') as string;
      if (stored.length > 0) {
        const parsed: object = JSON.parse(stored) as object;
        if (Array.isArray(parsed)) {
          this.history = parsed as string[];
        }
      }
    } catch (err) {
      console.error(`HistoryRepository init failed: ${JSON.stringify(err)}`);
      this.history = [];
    }
  }

  /**
   * 添加一条播放记录：去重后置顶，超出上限则截断。
   */
  async add(songId: string): Promise<void> {
    try {
      const idx: number = this.history.indexOf(songId);
      if (idx >= 0) {
        this.history.splice(idx, 1);
      }
      this.history.unshift(songId);
      if (this.history.length > DefaultValue.MAX_HISTORY) {
        this.history = this.history.slice(0, DefaultValue.MAX_HISTORY);
      }
      await this.persist();
    } catch (err) {
      console.error(`HistoryRepository add failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 获取最近播放的歌曲ID列表。limit 缺省时返回最近 MAX_RECENT_DISPLAY 条。
   */
  async getRecent(limit?: number): Promise<string[]> {
    try {
      const max: number = (limit !== undefined && limit > 0) ? limit : DefaultValue.MAX_RECENT_DISPLAY;
      return this.history.slice(0, max);
    } catch (err) {
      console.error(`HistoryRepository getRecent failed: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 清空全部播放记录。
   */
  async clear(): Promise<void> {
    try {
      this.history = [];
      await this.persist();
    } catch (err) {
      console.error(`HistoryRepository clear failed: ${JSON.stringify(err)}`);
    }
  }

  private async persist(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_HISTORY_IDS, JSON.stringify(this.history));
      await this.pref.flush();
    } catch (err) {
      console.error(`HistoryRepository persist failed: ${JSON.stringify(err)}`);
    }
  }
}

export const HistoryRepository = new HistoryRepositoryImpl();
