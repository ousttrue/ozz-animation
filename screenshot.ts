import { category } from './src/data';
import { chromium } from 'playwright';
import fs from 'node:fs';


for (const article of category.articles) {
  console.log(`${article.title}`);
  const browser = await chromium.launch(); // or 'chromium', 'firefox'
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    page.setViewportSize({ "width": 300, "height": 157 });
    await page.goto(`http://localhost:5173/ozz-animation/wasm/${article.title}.html`);
    await page.waitForLoadState('networkidle')
    await page.screenshot({ path: `public/wasm/${article.title}.jpg` });
    await browser.close();
  } catch (ex) {
    console.error(ex);
  }

  // inject html to ogp
  const path = `public/wasm/${article.title}.html`
  if (fs.existsSync(path)) {
    let src = fs.readFileSync(path, 'utf8');
    const replace = `<meta charset=utf-8>
<meta property="og:title" content="${article.title}">
<meta property="og:type" content="website">
<meta property="og:url" content="https://ousttrue.github.io/rowmath/wasm/${article.title}.html">
<meta property="og:image" content="https://ousttrue.github.io/rowmath/wasm/${article.title}.jpg">
<meta property="og:site_name" content="rowmath wasm examples">
<meta property="og:description" content="${article.title}">
`;
    fs.writeFileSync(path, src.replace('<meta charset=utf-8>', replace));
  }
}

process.exit(0);
