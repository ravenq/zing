import { LyricLine } from '../models/index';

export class LrcParser {
  /**
   * 解析 LRC 文本为歌词行数组
   * 支持格式：[mm:ss.xx]歌词文本
   * 支持多时间标签：[00:01.00][00:15.00]同一句歌词
   */
  static parse(lrcText: string): LyricLine[] {
    if (!lrcText) return [];
    const lines = lrcText.split('\n');
    const result: LyricLine[] = [];
    const timeRegex = /\[(\d{2}):(\d{2})(?:\.(\d{1,3}))?\]/g;

    for (const line of lines) {
      const text = line.replace(timeRegex, '').trim();
      timeRegex.lastIndex = 0;
      let match: RegExpExecArray | null;
      while ((match = timeRegex.exec(line)) !== null) {
        const min = parseInt(match[1], 10);
        const sec = parseInt(match[2], 10);
        const ms = match[3] ? parseInt(match[3].padEnd(3, '0'), 10) : 0;
        const time = (min * 60 + sec) * 1000 + ms;
        result.push({ time, text });
      }
    }
    result.sort((a, b) => a.time - b.time);
    return result;
  }

  /**
   * 根据当前时间返回高亮行索引
   */
  static match(lyrics: LyricLine[], currentTime: number): number {
    if (lyrics.length === 0) return -1;
    if (currentTime < lyrics[0].time) return -1;
    let index = 0;
    for (let i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= currentTime) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  /**
   * 判断是否为纯音乐（无有效歌词行）
   */
  static isEmpty(lyrics: LyricLine[]): boolean {
    return lyrics.length === 0 || lyrics.every((l: LyricLine) => !l.text);
  }
}
