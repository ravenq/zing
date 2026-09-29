import { MusicSourceConfig, OnlineTrack } from '../../models/OnlineTypes';
import { IMusicSource } from './IMusicSource';
import { HttpUtil } from './HttpUtil';
import { getPath, getString } from './JsonPath';

function parsePsToMs(ps: string): number {
  if (!ps) {
    return 0;
  }
  const parts: string[] = ps.split(':');
  if (parts.length === 2) {
    const minutes = Number(parts[0]);
    const seconds = Number(parts[1]);
    if (!isNaN(minutes) && !isNaN(seconds)) {
      return (minutes * 60 + seconds) * 1000;
    }
  }
  return 0;
}

export class CcMixterSourceAdapter implements IMusicSource {
  config: MusicSourceConfig;

  constructor(config: MusicSourceConfig) {
    this.config = config;
  }

  isReady(): boolean {
    return true;
  }

  private pickAudioFile(files: Object[]): Object | null {
    let fallback: Object | null = null;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (getString(file, 'file_format_info.media-type') === 'audio') {
        if (fallback === null) {
          fallback = file;
        }
        if (getString(file, 'file_format_info.default-ext') === 'mp3') {
          return file;
        }
      }
    }
    return fallback;
  }

  async search(keyword: string): Promise<OnlineTrack[]> {
    const url: string =
      `https://ccmixter.org/api/query?f=js&s=${encodeURIComponent(keyword)}&search_type=all&limit=30`;
    const json = await HttpUtil.getJson(url);
    const tracks: OnlineTrack[] = [];
    const list = json as Object[];
    if (!Array.isArray(list)) {
      return tracks;
    }
    for (let i = 0; i < list.length; i++) {
      const upload = list[i];
      const filesValue = getPath(upload, 'files');
      let files: Object[] = [];
      if (Array.isArray(filesValue)) {
        files = filesValue as Object[];
      }
      const file = this.pickAudioFile(files);
      if (!file) {
        continue;
      }
      const streamUrl: string = getString(file, 'download_url');
      tracks.push({
        id: getString(upload, 'upload_id'),
        sourceId: this.config.id,
        sourceName: this.config.name,
        title: getString(upload, 'upload_name'),
        artist: getString(upload, 'user_name'),
        duration: parsePsToMs(getString(file, 'file_format_info.ps')),
        streamUrl: streamUrl,
        streamHeaders: { 'Referer': 'https://ccmixter.org/' },
        licenseName: getString(upload, 'license_name'),
        licenseUrl: getString(upload, 'license_url'),
        downloadUrl: streamUrl,
        downloadable: true
      });
    }
    return tracks;
  }
}
