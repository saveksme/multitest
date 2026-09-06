// Одноразовый статик-сервер: смотреть прототип плашки спонсора в браузере.
const http = require('http'), fs = require('fs'), path = require('path');
const root = __dirname;
http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(req.url.split('?')[0]) === '/' ? 'index.html' : req.url.split('?')[0]);
  fs.readFile(p, (e, d) => {
    if (e) { res.writeHead(404); return res.end('404'); }
    const t = { '.html': 'text/html', '.svg': 'image/svg+xml', '.png': 'image/png', '.js': 'text/javascript' }[path.extname(p)] || 'text/plain';
    res.writeHead(200, { 'content-type': t, 'cache-control': 'no-store' });
    res.end(d);
  });
}).listen(8099, () => console.log('preview on http://localhost:8099'));
