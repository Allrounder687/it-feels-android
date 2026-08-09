export class DeezerProvider {
  static baseUrl = 'https://api.deezer.com';

  static async proxy(path: string, queryParams: URLSearchParams) {
    const url = `${this.baseUrl}/${path}?${queryParams.toString()}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Deezer API error: ${response.status} - ${await response.text()}`);
    }
    return await response.json();
  }
}
