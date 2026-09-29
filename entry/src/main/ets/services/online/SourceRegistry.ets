import { Song } from '../../models/index';
import { MusicSourceConfig, OnlineTrack, SourceFailure } from '../../models/OnlineTypes';
import { IMusicSource } from './IMusicSource';
import { buildOnlineSongId } from './JsonPath';
import { CcMixterSourceAdapter } from './CcMixterSourceAdapter';
import { JamendoSourceAdapter } from './JamendoSourceAdapter';
import { RssSourceAdapter } from './RssSourceAdapter';
import { JsonApiSourceAdapter } from './JsonApiSourceAdapter';

export interface SearchResult {
  tracks: OnlineTrack[];
  failedSources: SourceFailure[];
}

function defaultCcMixter(): IMusicSource {
  return new CcMixterSourceAdapter({
    id: 'ccmixter',
    name: 'ccMixter',
    kind: 'builtin',
    enabled: true,
    builtin: true
  });
}

function describeError(e: Object): string {
  const withMessage = e as Record<string, Object>;
  const message = withMessage['message'];
  if (message !== undefined && message !== null) {
    const text: string = String(message);
    if (text.length > 0) {
      return text;
    }
  }
  return String(e);
}

class SourceRegistryImpl {
  private sources: IMusicSource[] = [defaultCcMixter()];

  setSources(list: IMusicSource[]): void {
    this.sources = list.slice();
  }

  getSources(): IMusicSource[] {
    return this.sources.slice();
  }

  configure(configs: MusicSourceConfig[], jamendoClientId: string): void {
    const list: IMusicSource[] = [];
    for (let i = 0; i < configs.length; i++) {
      const config = configs[i];
      if (config.id === 'ccmixter') {
        list.push(new CcMixterSourceAdapter(config));
      } else if (config.id === 'jamendo') {
        list.push(new JamendoSourceAdapter(config, jamendoClientId));
      } else if (config.kind === 'rss') {
        list.push(new RssSourceAdapter(config));
      } else if (config.kind === 'jsonapi') {
        list.push(new JsonApiSourceAdapter(config));
      }
    }
    this.sources = list;
  }

  toPlayableSong(track: OnlineTrack): Song {
    return {
      id: buildOnlineSongId(track.sourceId, track.id),
      title: track.title,
      artist: track.artist,
      album: track.sourceName,
      duration: track.duration,
      filePath: track.streamUrl,
      fileHeaders: track.streamHeaders,
      fileSize: 0,
      coverUri: track.coverUrl,
      favorite: false
    };
  }

  toPlayableSongs(tracks: OnlineTrack[]): Song[] {
    const songs: Song[] = [];
    for (let i = 0; i < tracks.length; i++) {
      songs.push(this.toPlayableSong(tracks[i]));
    }
    return songs;
  }

  async searchAll(keyword: string): Promise<SearchResult> {
    const active: IMusicSource[] = [];
    for (let i = 0; i < this.sources.length; i++) {
      const source = this.sources[i];
      if (source.config.enabled && source.isReady()) {
        active.push(source);
      }
    }

    const settled = await Promise.allSettled(active.map((source: IMusicSource): Promise<OnlineTrack[]> => {
      return source.search(keyword);
    }));

    const tracks: OnlineTrack[] = [];
    const failedSources: SourceFailure[] = [];
    for (let i = 0; i < settled.length; i++) {
      const outcome = settled[i];
      if (outcome.status === 'fulfilled') {
        const list = outcome.value;
        for (let j = 0; j < list.length; j++) {
          tracks.push(list[j]);
        }
      } else {
        failedSources.push({
          sourceId: active[i].config.id,
          sourceName: active[i].config.name,
          reason: describeError(outcome.reason as Object)
        });
      }
    }
    return { tracks, failedSources };
  }
}

export const SourceRegistry = new SourceRegistryImpl();
