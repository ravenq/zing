import { MusicSourceConfig, OnlineTrack } from '../../models/OnlineTypes';
import { IMusicSource } from './IMusicSource';
import { HttpUtil } from './HttpUtil';
import { parseRss, RssItem } from './XmlMiniParser';

function parseDurationMs(text: string): number {
  const value: string = text.trim();
  if (value.length === 0) {
    return 0;
  }
  if (value.indexOf(':') >= 0) {
    const parts: string[] = value.split(':');
    let total: number = 0;
    let valid: boolean = true;
    for (let i = 0; i < parts.length; i++) {
      const n: number = Number(parts[i]);
      if (isNaN(n)) {
        valid = false;
        break;
      }
      total = total * 60 + n;
    }
    if (valid) {
      return total * 1000;
    }
  }
  const seconds: number = Number(value);
  if (!isNaN(seconds)) {
    return Math.floor(seconds) * 1000;
  }
  return 0;
}

function splitTitleArtist(title: string, author: string): string[] {
  if (author.trim().length > 0) {
    return [title, author];
  }
  const dash: number = title.indexOf(' - ');
  if (dash > 0) {
    return [title.substring(0, dash).trim(), title.substring(dash + 3).trim()];
  }
  return [title, ''];
}

export class RssSourceAdapter implements IMusicSource {
  config: MusicSourceConfig;

  constructor(config: MusicSourceConfig) {
    this.config = config;
  }

  isReady(): boolean {
    return !!this.config.url && this.config.url.trim().length > 0;
  }

  async search(keyword: string): Promise<OnlineTrack[]> {
    const feedUrl: string = (this.config.url as string).trim();
    const xml: string = await HttpUtil.getText(feedUrl, this.config.headers);
    const items: RssItem[] = parseRss(xml);
    const kw: string = keyword.trim().toLowerCase();
    const tracks: OnlineTrack[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: RssItem = items[i];
      if (item.enclosureUrl.length === 0) {
        continue;
      }
      if (kw.length > 0 &&
        item.title.toLowerCase().indexOf(kw) < 0 &&
        item.author.toLowerCase().indexOf(kw) < 0) {
        continue;
      }
      const parts: string[] = splitTitleArtist(item.title, item.author);
      const trackId: string = item.guid.length > 0 ? item.guid : item.enclosureUrl;
      tracks.push({
        id: trackId,
        sourceId: this.config.id,
        sourceName: this.config.name,
        title: parts[0],
        artist: parts[1],
        duration: parseDurationMs(item.durationText),
        streamUrl: item.enclosureUrl,
        coverUrl: item.imageUrl.length > 0 ? item.imageUrl : undefined,
        downloadUrl: item.enclosureUrl,
        downloadable: true
      });
    }
    return tracks;
  }
}
