// node misc/fliper/rasterizar.cjs entrada.svg saida.png largura altura  (Chromium do Playwright, fundo transparente)
const fs = require('fs'); const { chromium } = require('playwright');
(async () => { const [, , ent, sai, w, h] = process.argv; const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: +w, height: +h } });
  await p.setContent(`<html><body style="margin:0;background:transparent">${fs.readFileSync(ent, 'utf8').replace('<svg ', `<svg style="display:block;width:${w}px;height:${h}px" `)}</body></html>`);
  await p.screenshot({ path: sai, omitBackground: true, clip: { x: 0, y: 0, width: +w, height: +h } }); await b.close(); })();
