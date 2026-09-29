import { MusicSourceConfig, OnlineTrack, JsonFieldMapping } from '../../models/OnlineTypes';
import { IMusicSource } from './IMusicSource';
import { HttpUtil } from './HttpUtil';
import { getPath, getString, fillTemplate } from './JsonPath';

export class JsonApiSourceAdapter implements IMusicSource {
  config: MusicSourceConfig;

  constructor(config: MusicSourceConfig) {
    this.config = config;
  }

  isReady(): boolean {
    if (!this.config.url || this.config.url.trim().length === 0 || !this.config.mapping) {
      return false;
    }
    const mapping: JsonFieldMapping = this.config.mapping;
    return mapping.listPath.trim().length > 0 &&
      mapping.id.trim().length > 0 &&
      mapping.title.trim().length > 0 &&
      mapping.artist.trim().length > 0 &&
      mapping.streamUrl.trim().length > 0;
  }

  async search(keyword: string): Promise<OnlineTrack[]> {
    const mapping: JsonFieldMapping = this.config.mapping as JsonFieldMapping;
    const url: string = fillTemplate((this.config.url as string).trim(), keyword);
    const json: Object = await HttpUtil.getJson(url, this.config.headers);
    const listValue: Object | undefined = getPath(json, mapping.listPath.trim());
    const tracks: OnlineTrack[] = [];
    if (!Array.isArray(listValue)) {
      return tracks;
    }
    const list: Object[] = listValue as Object[];
    for (let i = 0; i < list.length; i++) {
      const item: Object = list[i];
      const streamUrl: string = getString(item, mapping.streamUrl);
      if (streamUrl.length === 0) {
        continue;
      }
      let duration: number = 0;
      if (mapping.duration && mapping.duration.trim().length > 0) {
        const seconds: number = Number(getString(item, mapping.duration));
        if (!isNaN(seconds)) {
          duration = Math.floor(seconds) * 1000;
        }
      }
      const downloadUrl: string = mapping.downloadUrl ? getString(item, mapping.downloadUrl) : '';
      const licenseName: string = mapping.licenseName ? getString(item, mapping.licenseName) : '';
      const licenseUrl: string = mapping.licenseUrl ? getString(item, mapping.licenseUrl) : '';
      const coverUrl: string = mapping.coverUrl ? getString(item, mapping.coverUrl) : '';
      tracks.push({
        id: getString(item, mapping.id),
        sourceId: this.config.id,
        sourceName: this.config.name,
        title: getString(item, mapping.title),
        artist: getString(item, mapping.artist),
        duration: duration,
        streamUrl: streamUrl,
        streamHeaders: this.config.headers,
        coverUrl: coverUrl.length > 0 ? coverUrl : undefined,
        licenseName: licenseName.length > 0 ? licenseName : undefined,
        licenseUrl: licenseUrl.length > 0 ? licenseUrl : undefined,
        downloadUrl: downloadUrl.length > 0 ? downloadUrl : undefined,
        downloadable: downloadUrl.length > 0
      });
    }
    return tracks;
  }
}
