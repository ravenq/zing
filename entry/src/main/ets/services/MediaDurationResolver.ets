import { fileIo as fs } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const RESOLVER_DOMAIN: number = 0xA004;
const RESOLVER_TAG: string = 'ZingDur';

export class MediaDurationResolver {
  static async resolveMs(fileUriOrPath: string): Promise<number> {
    let extractor: media.AVMetadataExtractor | null = null;
    let file: fs.File | null = null;
    let duration: number = 0;
    let filePath: string = fileUriOrPath;
    if (filePath.startsWith('file://')) {
      filePath = filePath.substring('file://'.length);
    }
    try {
      const openedFile: fs.File = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      file = openedFile;
      const metadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      extractor = metadataExtractor;
      metadataExtractor.fdSrc = { fd: openedFile.fd };
      const metadata: media.AVMetadata = await metadataExtractor.fetchMetadata();
      const rawDuration: number = Number(metadata.duration);
      if (!Number.isNaN(rawDuration) && rawDuration > 0) {
        duration = Math.round(rawDuration);
      }
    } catch (err) {
      hilog.info(RESOLVER_DOMAIN, RESOLVER_TAG, 'resolve skipped: %{public}s', String(err));
      duration = 0;
    } finally {
      if (extractor) {
        try {
          await extractor.release();
        } catch (releaseErr) {
          hilog.info(RESOLVER_DOMAIN, RESOLVER_TAG, 'release err: %{public}s', String(releaseErr));
        }
      }
      if (file) {
        try {
          fs.closeSync(file);
        } catch (closeErr) {
          hilog.info(RESOLVER_DOMAIN, RESOLVER_TAG, 'close err: %{public}s', String(closeErr));
        }
      }
    }
    return duration;
  }
}
