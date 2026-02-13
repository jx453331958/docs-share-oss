import { createServer } from 'http';
import { readdir, readFile, stat } from 'fs/promises';
import { join, extname } from 'path';

const PORT = 3457;
const DOCS_DIR = join(import.meta.dirname, 'docs');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.md': 'text/plain; charset=utf-8',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
};

// Title extraction: first # heading or filename
async function extractMeta(filepath, filename) {
  try {
    const content = await readFile(filepath, 'utf-8');
    const titleMatch = content.match(/^#\s+(.+)/m);
    const title = titleMatch ? titleMatch[1].replace(/[*_`]/g, '') : filename;
    // Extract first few meaningful lines for desc
    const lines = content.split('\n').filter(l => l.trim() && !l.startsWith('#') && !l.startsWith('>'));
    const desc = lines[0]?.slice(0, 80) || '';
    const s = await stat(filepath);
    return { file: filename, title, desc, mtime: s.mtimeMs };
  } catch {
    return { file: filename, title: filename, desc: '', mtime: 0 };
  }
}

async function handleApiDocs(res) {
  const files = await readdir(DOCS_DIR);
  const mdFiles = files.filter(f => f.endsWith('.md'));
  const docs = await Promise.all(mdFiles.map(f => extractMeta(join(DOCS_DIR, f), f)));
  docs.sort((a, b) => b.mtime - a.mtime); // newest first
  res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(docs));
}

async function serveStatic(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/') pathname = '/index.html';

  const filepath = join(DOCS_DIR, pathname);
  // Security: ensure within DOCS_DIR
  if (!filepath.startsWith(DOCS_DIR)) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  try {
    const data = await readFile(filepath);
    const ext = extname(filepath);
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
    });
    res.end(data);
  } catch {
    res.writeHead(404); res.end('Not Found');
  }
}

const server = createServer(async (req, res) => {
  if (req.url === '/api/docs') return handleApiDocs(res);
  return serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`docs-share running on http://0.0.0.0:${PORT}`);
});
