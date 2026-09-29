export class ThemeColor {
  // 主色
  static readonly PRIMARY = '#31C27C';
  static readonly PRIMARY_DARK = '#26A366';
  static readonly PRIMARY_LIGHT = '#5DD99A';
  // 背景
  static readonly BG_WHITE = '#FFFFFF';
  static readonly BG_GRAY = '#F5F6F8';
  // 文字
  static readonly TEXT_MAIN = '#333333';
  static readonly TEXT_SUB = '#999999';
  // 其他
  static readonly DIVIDER = '#EEEEEE';
  static readonly ERROR = '#FF5252';
  static readonly WARNING = '#FF9800';
  static readonly INFO = '#2196F3';
}

export class ThemeSize {
  static readonly FONT_SM = 11;
  static readonly FONT_MD = 13;
  static readonly FONT_LG = 16;
  static readonly FONT_XL = 20;
  static readonly FONT_XXL = 24;
  static readonly RADIUS_SM = 4;
  static readonly RADIUS_MD = 8;
  static readonly RADIUS_LG = 12;
  static readonly RADIUS_XL = 24;
  static readonly SPACING_SM = 8;
  static readonly SPACING_MD = 14;
  static readonly SPACING_LG = 20;
  static readonly AVATAR_SM = 32;
  static readonly AVATAR_MD = 40;
  static readonly AVATAR_LG = 56;
  static readonly COVER_SM = 48;
  static readonly COVER_MD = 120;
  static readonly COVER_LG = 180;
}

// 格式化时长（毫秒 -> mm:ss）
export function formatDuration(ms: number): string {
  if (!ms || ms < 0) return '00:00';
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

// 生成唯一ID
export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}
