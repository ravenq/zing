import { MusicSourceConfig, OnlineTrack } from '../../models/OnlineTypes';
import { IMusicSource } from './IMusicSource';
import { HttpUtil } from './HttpUtil';
import { getPath, getString } from './JsonPath';

export class JamendoSourceAdapter implements IMusicSource {
  config: MusicSourceConfig;
  private clientId: string;

  constructor(config: MusicSourceConfig, clientId: string) {
    this.config = config;
    this.clientId = clientId;
  }

  isReady(): boolean {
    return this.clientId.trim().length > 0;
  }

  async search(keyword: string): Promise<OnlineTrack[]> {
    const url: string =
      `https://api.jamendo.com/v3.0/tracks/?client_id=${encodeURIComponent(this.clientId)}` +
      `&format=json&limit=30&namesearch=${encodeURIComponent(keyword)}`;
    const json = await HttpUtil.getJson(url);
    const status: string = getString(json, 'headers.status');
    if (status === 'failed' || status === 'error') {
      const code: string = getString(json, 'headers.code');
      const errorMessage: string = getString(json, 'headers.error_message');
      if (code === '5' || code === '6' || code === '7' || code === '8' ||
        errorMessage.indexOf('client_id') >= 0 || errorMessage.indexOf('credentials') >= 0) {
        throw new Error('凭证无效，请检查 client_id');
      }
      throw new Error('请求失败: ' + (errorMessage.length > 0 ? errorMessage : code));
    }
    const resultsValue = getPath(json, 'results');
    const tracks: OnlineTrack[] = [];
    if (!Array.isArray(resultsValue)) {
      return tracks;
    }
    const results = resultsValue as Object[];
    for (let i = 0; i < results.length; i++) {
      const item = results[i];
      const streamUrl: string = getString(item, 'audio');
      if (streamUrl.length === 0) {
        continue;
      }
      const durationSec: number = Number(getString(item, 'duration'));
      const downloadUrl: string = getString(item, 'audiodownload');
      const allowedValue = getPath(item, 'audiodownload_allowed');
      tracks.push({
        id: getString(item, 'id'),
        sourceId: this.config.id,
        sourceName: this.config.name,
        title: getString(item, 'name'),
        artist: getString(item, 'artist_name'),
        duration: isNaN(durationSec) ? 0 : durationSec * 1000,
        streamUrl: streamUrl,
        coverUrl: getString(item, 'image'),
        licenseName: getString(item, 'license_name'),
        licenseUrl: getString(item, 'license_ccurl'),
        downloadUrl: downloadUrl,
        downloadable: allowedValue === true && downloadUrl.length > 0
      });
    }
    return tracks;
  }
}
