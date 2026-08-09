export class ListenBrainzProvider {
  static baseUrl = 'https://api.listenbrainz.org/1';

  static async proxy(path: string, queryParams: URLSearchParams) {
    const url = `${this.baseUrl}/${path}?${queryParams.toString()}`;
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'ITFeelsMusic/1.0.0 ( itfeelsmusic@example.com )'
      }
    });
    if (!response.ok) {
      throw new Error(`ListenBrainz API error: ${response.status} - ${await response.text()}`);
    }
    return await response.json();
  }
}
