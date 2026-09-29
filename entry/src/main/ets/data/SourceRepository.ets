import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MusicSourceConfig } from '../models/OnlineTypes';
import { StorageName } from '../common/Constants';

const KEY_CONFIGS = 'source_configs';
const KEY_JAMENDO_ID = 'jamendo_client_id';
const KEY_AUTO_ADD = 'auto_add_to_library';

function defaultBuiltins(): MusicSourceConfig[] {
  return [
    {
      id: 'ccmixter',
      name: 'ccMixter',
      kind: 'builtin',
      enabled: true,
      builtin: true
    },
    {
      id: 'jamendo',
      name: 'Jamendo',
      kind: 'builtin',
      enabled: true,
      builtin: true
    }
  ];
}

class SourceRepositoryImpl {
  private pref: preferences.Preferences | null = null;
  private configs: MusicSourceConfig[] = defaultBuiltins();

  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, StorageName.SOURCE);
      const stored: string = await this.pref.get(KEY_CONFIGS, '') as string;
      let list: MusicSourceConfig[] = [];
      if (stored.length > 0) {
        const parsed: Object = JSON.parse(stored) as Object;
        if (Array.isArray(parsed)) {
          list = (parsed as Object[]) as MusicSourceConfig[];
        }
      }
      this.configs = this.mergeBuiltins(list);
    } catch (err) {
      console.error(`SourceRepository init failed: ${JSON.stringify(err)}`);
      this.configs = defaultBuiltins();
    }
  }

  private mergeBuiltins(stored: MusicSourceConfig[]): MusicSourceConfig[] {
    const defaults: MusicSourceConfig[] = defaultBuiltins();
    const finalList: MusicSourceConfig[] = [];
    for (let i = 0; i < defaults.length; i++) {
      let found: MusicSourceConfig | null = null;
      for (let j = 0; j < stored.length; j++) {
        if (stored[j].id === defaults[i].id) {
          found = stored[j];
          break;
        }
      }
      finalList.push(found === null ? defaults[i] : found);
    }
    for (let i = 0; i < stored.length; i++) {
      let isBuiltin: boolean = false;
      for (let j = 0; j < defaults.length; j++) {
        if (stored[i].id === defaults[j].id) {
          isBuiltin = true;
          break;
        }
      }
      if (!isBuiltin) {
        finalList.push(stored[i]);
      }
    }
    return finalList;
  }

  getConfigs(): MusicSourceConfig[] {
    return this.configs.slice();
  }

  async getConfig(id: string): Promise<MusicSourceConfig | null> {
    for (let i = 0; i < this.configs.length; i++) {
      if (this.configs[i].id === id) {
        return this.configs[i];
      }
    }
    return null;
  }

  async saveConfig(config: MusicSourceConfig): Promise<void> {
    let found: boolean = false;
    for (let i = 0; i < this.configs.length; i++) {
      if (this.configs[i].id === config.id) {
        this.configs[i] = config;
        found = true;
        break;
      }
    }
    if (!found) {
      this.configs.push(config);
    }
    await this.persistConfigs();
  }

  async deleteConfig(id: string): Promise<void> {
    for (let i = 0; i < this.configs.length; i++) {
      if (this.configs[i].id === id) {
        this.configs.splice(i, 1);
        break;
      }
    }
    await this.persistConfigs();
  }

  generateCustomId(): string {
    return `custom_${Date.now()}`;
  }

  async getJamendoClientId(): Promise<string> {
    if (!this.pref) {
      return '';
    }
    return await this.pref.get(KEY_JAMENDO_ID, '') as string;
  }

  async setJamendoClientId(clientId: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(KEY_JAMENDO_ID, clientId);
    await this.pref.flush();
  }

  async getAutoAdd(): Promise<boolean> {
    if (!this.pref) {
      return true;
    }
    return await this.pref.get(KEY_AUTO_ADD, true) as boolean;
  }

  async setAutoAdd(value: boolean): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(KEY_AUTO_ADD, value);
    await this.pref.flush();
  }

  private async persistConfigs(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_CONFIGS, JSON.stringify(this.configs));
      await this.pref.flush();
    } catch (err) {
      console.error(`SourceRepository persist failed: ${JSON.stringify(err)}`);
    }
  }
}

export const SourceRepository = new SourceRepositoryImpl();
