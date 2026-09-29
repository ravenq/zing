import { http } from '@kit.NetworkKit';

const TIMEOUT_MS: number = 10000;
const RETRY_DELAY_MS: number = 800;
const USER_AGENT: string = 'Mozilla/5.0 (compatible; ZingPlayer/1.0)';

function delay(ms: number): Promise<void> {
  return new Promise((resolve: () => void): void => {
    setTimeout(resolve, ms);
  });
}

async function requestOnce(url: string, headers?: Record<string, string>): Promise<string> {
  const httpRequest = http.createHttp();
  try {
    const finalHeaders: Record<string, string> = { 'User-Agent': USER_AGENT };
    if (headers) {
      const keys = Object.keys(headers);
      for (let i = 0; i < keys.length; i++) {
        finalHeaders[keys[i]] = headers[keys[i]];
      }
    }
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: finalHeaders,
      connectTimeout: TIMEOUT_MS,
      readTimeout: TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING
    });
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`HTTP ${response.responseCode}`);
    }
    return response.result as string;
  } catch (e) {
    const err = e as Error;
    console.error(`HttpUtil request failed: url=${url} code=${(e as Record<string, Object>)['code']} msg=${err.message}`);
    throw err;
  } finally {
    httpRequest.destroy();
  }
}

function isRetryable(error: Error): boolean {
  const msg = error.message;
  if (msg.startsWith('HTTP ')) {
    const code = Number(msg.substring(5));
    return code >= 500 && code < 600;
  }
  return true;
}

async function requestWithRetry(url: string, headers?: Record<string, string>): Promise<string> {
  try {
    return await requestOnce(url, headers);
  } catch (e) {
    const error = e as Error;
    if (isRetryable(error)) {
      await delay(RETRY_DELAY_MS);
      return await requestOnce(url, headers);
    }
    throw error;
  }
}

export class HttpUtil {
  static async getText(url: string, headers?: Record<string, string>): Promise<string> {
    return await requestWithRetry(url, headers);
  }

  static async getJson(url: string, headers?: Record<string, string>): Promise<Object> {
    const text = await requestWithRetry(url, headers);
    return JSON.parse(text) as Object;
  }
}
