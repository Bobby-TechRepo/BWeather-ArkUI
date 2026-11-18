import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export enum FailureKind {
  /** No connection, timeout or an HTTP error. */
  Network = 'network',
  /** The response couldn't be read. */
  Data = 'data',
  /** The request worked but found nothing (e.g. no matching places). */
  NotFound = 'notFound'
}

export class RequestFailure extends Error {
  readonly kind: FailureKind;

  constructor(kind: FailureKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

/** GET requests with a timeout; every failure becomes a [RequestFailure]. */
export class Http {
  static readonly TIMEOUT_MS: number = 15000;

  static async get(url: string, headers?: Record<string, string>, timeoutMs?: number): Promise<string> {
    const request = http.createHttp();
    const timeout = timeoutMs ?? Http.TIMEOUT_MS;
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: timeout,
        readTimeout: timeout,
        expectDataType: http.HttpDataType.STRING
      };
      const response = await request.request(url, options);
      if (response.responseCode !== 200) {
        throw new RequestFailure(FailureKind.Network, `HTTP ${response.responseCode}`);
      }
      return response.result as string;
    } catch (error) {
      if (error instanceof RequestFailure) {
        throw error;
      }
      hilog.warn(0x0000, 'Http', 'Request failed: %{public}s', JSON.stringify(error));
      throw new RequestFailure(FailureKind.Network, 'Request failed');
    } finally {
      request.destroy();
    }
  }

  /** GET for binary data (map tiles). */
  static async getBytes(url: string, headers?: Record<string, string>, timeoutMs?: number): Promise<ArrayBuffer> {
    const request = http.createHttp();
    const timeout = timeoutMs ?? Http.TIMEOUT_MS;
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: timeout,
        readTimeout: timeout,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      const response = await request.request(url, options);
      if (response.responseCode !== 200) {
        throw new RequestFailure(FailureKind.Network, `HTTP ${response.responseCode}`);
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      if (error instanceof RequestFailure) {
        throw error;
      }
      throw new RequestFailure(FailureKind.Network, 'Request failed');
    } finally {
      request.destroy();
    }
  }

  /** "https://host/path?a=1&b=2" with every value URL-encoded. */
  static url(base: string, params: Map<string, string>): string {
    const parts: string[] = [];
    params.forEach((value: string, key: string) => {
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    });
    return parts.length === 0 ? base : `${base}?${parts.join('&')}`;
  }
}
