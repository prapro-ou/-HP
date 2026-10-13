import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
const here = path.dirname(fileURLToPath(import.meta.url));
const read = name => readFile(path.join(here, name), 'utf8');
const catalog = JSON.parse(await read('catalog.json'));
const editorial = JSON.parse(await read('editorial.json'));
const genres = [...new Set(catalog.games.map(g => g.genre))];
const lenses = new Map(catalog.principles.map(p => [p.id, p]));
const ids = new Set();
const required = ['id','title','genre','feature','idea','watch','prototype','effort','source'];
for (const game of catalog.games) {
  for (const field of required) if (!game[field]) throw new Error(`${game.id}: missing ${field}`);
  if (ids.has(game.id)) throw new Error(`Duplicate id: ${game.id}`);
  ids.add(game.id);
  if (!Number.isInteger(game.priority) || game.priority < 1 || game.priority > 5) throw new Error(`Invalid priority: ${game.id}`);
  if (!['低','中','高'].includes(game.effort)) throw new Error(`Invalid effort: ${game.id}`);
  for (const tag of game.principles) if (!lenses.has(tag)) throw new Error(`Unknown lens: ${tag}`);
  if (!game.mood.length || !game.needs.length) throw new Error(`No tags: ${game.id}`);
  for (const url of [game.source,...(game.media?.screenshots || []).flatMap(s => [s.full,s.thumbnail])]) if (new URL(url).protocol !== 'https:') throw new Error(`Non-HTTPS URL: ${url}`);
  game.idea = game.idea.replace('角色','役割');
}
for (const article of editorial.articles) if (!ids.has(article.game) || new URL(article.url).protocol !== 'https:') throw new Error(`Invalid article: ${article.id}`);
for (const recipe of editorial.recipes) for (const id of recipe.games) if (!ids.has(id)) throw new Error(`Invalid recipe game: ${id}`);
const template = await read('template.html');
const safeJson = data => JSON.stringify(data).replace(/</g, '\\u003c');
const html = template.replace('__CATALOG__',safeJson(catalog)).replace('__EDITORIAL__',safeJson(editorial));
const app = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].at(-1)[1];
new vm.Script(app, { filename: 'idea-pool-app.js' });
await writeFile(path.join(here,'index.html'),html);
await writeFile(path.join(here,'catalog.json'),JSON.stringify(catalog,null,2)+'\n');
// Keep provenance metadata, without redistributing full publisher descriptions.
try { const records=JSON.parse(await read('sources.json')); await writeFile(path.join(here,'sources.json'),JSON.stringify(records.map(({description,summary,...record})=>({...record,verified:catalog.updated})),null,2)+'\n'); } catch(error) { if(error.code!=='ENOENT') throw error; }
const mdLink = (label,url) => `[${label}](${url})`;
const cell = text => String(text).replace(/\|/g,'\\|').replace(/\r?\n/g,' ');
const tags = game => [...game.needs,...game.mood].map(t=>'#'+t).join(' ');
const refs = game => [mdLink(game.appId?'動画・紹介（公式ストア）':'動画・画像・紹介（公式）',game.source),...(game.videos||[]).map(v=>mdLink('公式掲載動画',v.url)),game.media?.screenshots?.[0]?mdLink('公式画像',game.media.screenshots[0].full):'',...editorial.articles.filter(a=>a.game===game.id).map(a=>mdLink('記事：'+a.title,a.url))].filter(Boolean).join('<br>');
const md = [
  '# ゲーム・アイデアプール — COUNTER CORE',
  '',
  `更新：${catalog.updated} ／ ${catalog.games.length}作品・${genres.length}ジャンル・公式動画の視点${catalog.principles.length}本・開発者／公式記事${editorial.articles.length}件。`,
  '',
  '敵弾を奪うシューティングを中心に、見た目・システム・演出・緊張・協力のアイデアを横断して探すためのプール。ジャンルを限定しない。',
  '',
  '**タグを組み合わせて探すときは [検索できるHTML版](index.html)** を開く。このMarkdownでは `Ctrl+F` で `#可愛い`、`#パーティ`、`#ホラー`、`#画像`、`#システム`、`#ボス` などを検索できる。',
  '',
  '参考度 ★★★★★ は現行のパリィ解析・主兵装＋性質2枠・部位破壊・手動COUNTERとの相性が特に高い候補。星は作品そのものの評価ではない。試作負荷は、ここに書いた小さな案の相対的な目安。',
  '',
  '## このチャットの土台：「桜井政博のゲーム作るには」',
  '',
  mdLink('公式チャンネル',catalog.channel)+' を主要な参照軸にする。作品を見てから、何が面白さを生んでいるかを分解する。下の問い・応用・ゲームとの対応づけは本資料の編集提案であり、桜井さんによる個々のゲームや試作案への推薦ではない。',
  '',
  '| 公式動画 | 考える問い（編集提案） | COUNTER COREへの応用 |',
  '| --- | --- | --- |',
  ...catalog.principles.map(p=>`| ${mdLink(p.title,p.url)} | ${cell(p.question)} | ${cell(p.application)} |`),
  '',
  '## まず比べたい組み合わせ',
  '',
  '| 欲しい体験 | 参考作品 | 組み合わせ案（編集提案） | プレイで確認すること |',
  '| --- | --- | --- | --- |',
  ...editorial.recipes.map(r=>`| ${cell(r.title)} | ${r.games.map(id=>catalog.games.find(g=>g.id===id).title).join(' × ')} | ${cell(r.idea)} | ${cell(r.test)} |`),
  '',
  '## ジャンル別一覧',
  '',
  ...genres.map((genre,i)=>`- [${genre}（${catalog.games.filter(g=>g.genre===genre).length}作品）](#genre-${i+1})`),
  '',
  '「特徴・魅力」は公式紹介と掲載メディアに基づく要約。「持ち込む案」「観察」「試作」は編集提案。動画リンクは公式プレイヤーのあるページ、画像リンクは公式Steam掲載スクリーンショット。',
  '',
  ...genres.flatMap((genre,i)=>[
    `<a id="genre-${i+1}"></a>`,
    '',
    '### '+genre,
    '',
    '| 作品・参考度 | 特徴・魅力 | 持ち込むなら（編集提案） | 観察・最小試作 | 探すタグ | 動画・画像・記事 |',
    '| --- | --- | --- | --- | --- | --- |',
    ...catalog.games.filter(g=>g.genre===genre).map(g=>`| **${cell(g.title)}**<br>${'★'.repeat(g.priority)}${'☆'.repeat(5-g.priority)}<br>試作負荷：${g.effort} | ${cell(g.feature)} | ${cell(g.idea)}<br>視点：${g.principles.map(id=>mdLink(lenses.get(id).title,lenses.get(id).url)).join(' / ')} | 観察：${cell(g.watch)}<br>試作：${cell(g.prototype)} | ${tags(g)} | ${refs(g)} |`),
    ''
  ]),
  '## 設計理由を読む：開発者・公式記事',
  '',
  '| 作品 | 記事 | 種別・言語 | 読むポイント |',
  '| --- | --- | --- | --- |',
  ...editorial.articles.map(a=>`| ${catalog.games.find(g=>g.id===a.game).title} | ${mdLink(a.title,a.url)} | ${a.type} / ${a.language} | ${cell(a.point)} |`),
  '',
  '## 今後の追加・相談方針',
  '',
  ...editorial.policies.map(p=>'- '+p),
  '',
  '## 出典と編集',
  '',
  '各行の作品紹介・画像リンクが、その作品の出典。Steamの65作品は掲載APIからタイトル・画像・動画の掲載を確認し、任天堂の3作品は公式サイトを参照した。作品の全動画を視聴済みという意味ではない。動画を見るときは各行の「観察」のポイントから始める。',
  '',
  'HTMLは単体で開け、一覧と検索はオフラインで動く。外部画像・リンクには通信が必要。お気に入りはブラウザのローカルストレージに保存する。',
  '',
  '追加・修正方法は [README](README.md) を参照。現在のゲーム仕様は [DESIGN.md](../DESIGN.md) を参照。',
  ''
].join('\n');
await writeFile(path.join(here,'IDEA_POOL.md'),md);
console.log(JSON.stringify({games:catalog.games.length,genres:genres.length,lenses:catalog.principles.length,articles:editorial.articles.length,steamRecords:catalog.games.filter(g=>g.media).length,screenshots:catalog.games.reduce((n,g)=>n+(g.media?.screenshots?.length||0),0),movies:catalog.games.reduce((n,g)=>n+(g.media?.movies?.length||0),0),htmlBytes:Buffer.byteLength(html),markdownBytes:Buffer.byteLength(md)},null,2));
