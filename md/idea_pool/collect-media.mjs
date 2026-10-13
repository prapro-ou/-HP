import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const here = path.dirname(fileURLToPath(import.meta.url));
const catalog = JSON.parse(await readFile(path.join(here, 'catalog.json'), 'utf8'));
const sources = [];
let cursor = 0;
async function worker() {
  while (cursor < catalog.games.length) {
    const game = catalog.games[cursor++];
    if (!game.appId) continue;
    const url = `https://store.steampowered.com/api/appdetails?appids=${game.appId}&l=english`;
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const payload = (await response.json())[String(game.appId)];
      if (!payload?.success) throw new Error('No app details');
      const d = payload.data;
      game.media = { name: d.name, header: d.header_image, screenshots: (d.screenshots || []).slice(0, 3).map(s => ({ thumbnail: s.path_thumbnail, full: s.path_full })), movies: (d.movies || []).slice(0, 2).map(m => ({ name: m.name, thumbnail: m.thumbnail, mp4: m.mp4?.max || m.mp4?.['480'] || null, webm: m.webm?.max || null, hls: m.hls_h264 || null })) };
      game.verified = catalog.updated;
      sources.push({ id: game.id, title: d.name, url, website: d.website, verified: catalog.updated, screenshots: game.media.screenshots.length, movies: game.media.movies.length });
      console.log(`OK ${game.id}: ${d.name} / images=${game.media.screenshots.length} videos=${game.media.movies.length}`);
    } catch (error) {
      game.mediaError = String(error.message);
      console.log(`FAILED ${game.id}: ${error.message}`);
    }
  }
}
await Promise.all([worker(), worker(), worker(), worker()]);
await writeFile(path.join(here, 'catalog.json'), JSON.stringify(catalog, null, 2) + '\n');
await writeFile(path.join(here, 'sources.json'), JSON.stringify(sources, null, 2) + '\n');
console.log(`DONE ${sources.length}/${catalog.games.filter(g => g.appId).length} Steam records`);
