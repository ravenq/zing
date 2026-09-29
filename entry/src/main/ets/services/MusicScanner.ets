import { picker } from '@kit.CoreFileKit';
import { Song } from '../models/index';

export class MusicScanner {
  private static instance: MusicScanner | null = null;

  static getInstance(): MusicScanner {
    if (MusicScanner.instance === null) {
      MusicScanner.instance = new MusicScanner();
    }
    return MusicScanner.instance;
  }

  /**
   * 从文件选择器导入音频文件
   */
  async importFromPicker(): Promise<Song[]> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 100;
      documentSelectOptions.fileSuffixFilters = ['.mp3', '.flac', '.wav', '.aac', '.ogg'];
      const documentPicker = new picker.DocumentViewPicker();
      const uris: string[] = await documentPicker.select(documentSelectOptions);
      if (!uris || uris.length === 0) {
        return [];
      }
      const songs: Song[] = [];
      for (let i = 0; i < uris.length; i++) {
        const uri: string = uris[i];
        const song: Song = {
          id: uri,
          title: this.extractFileName(uri),
          artist: '未知歌手',
          album: '本地导入',
          duration: 0,
          filePath: uri,
          fileSize: 0,
          coverUri: undefined,
          favorite: false
        };
        songs.push(song);
      }
      return songs;
    } catch (e) {
      console.error('文件选择器导入失败: ' + e);
      return [];
    }
  }

  private extractFileName(uri: string): string {
    const segments: string[] = uri.split('/');
    const last: string = segments[segments.length - 1];
    const dotIdx: number = last.lastIndexOf('.');
    if (dotIdx > 0) {
      return last.substring(0, dotIdx);
    }
    return last;
  }
}
