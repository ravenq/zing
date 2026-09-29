import { MusicSourceConfig, OnlineTrack } from '../../models/OnlineTypes';

export interface IMusicSource {
  config: MusicSourceConfig;
  isReady(): boolean;
  search(keyword: string): Promise<OnlineTrack[]>;
}
