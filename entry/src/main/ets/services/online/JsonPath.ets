export function getPath(obj: Object, path: string): Object | undefined {
  if (!path || path.length === 0) {
    return obj;
  }
  let current: Object | undefined = obj;
  const segments: string[] = path.split('.');
  for (let i = 0; i < segments.length; i++) {
    if (current === undefined || current === null) {
      return undefined;
    }
    const record = current as Record<string, Object>;
    current = record[segments[i]];
  }
  return current;
}

export function getString(obj: Object, path: string): string {
  const value = getPath(obj, path);
  if (value === undefined || value === null) {
    return '';
  }
  return String(value);
}

export function fillTemplate(tpl: string, keyword: string): string {
  return tpl.split('{keyword}').join(encodeURIComponent(keyword));
}

export function buildOnlineSongId(sourceId: string, trackId: string): string {
  return `online:${sourceId}:${trackId}`;
}

export function buildDownloadSongId(sourceId: string, trackId: string): string {
  return `download:${sourceId}:${trackId}`;
}
