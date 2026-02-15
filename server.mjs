import { createServer } from 'http';
import { readdir, readFile, stat, writeFile, unlink } from 'fs/promises';
import { join, extname, dirname } from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';
import { randomBytes, createHmac, timingSafeEqual } from 'crypto';

const execAsync = promisify(exec);

// Node 18+ 兼容：获取当前文件所在目录
const __dirname = dirname(fileURLToPath(import.meta.url));

// 自动生成 API Key（如果未设置）
function generateApiKey() {
  return randomBytes(32).toString('base64');
}

const PORT = process.env.PORT || 3457;
const DOCS_DIR = join(__dirname, 'docs');
const PUBLIC_DIR = join(__dirname, 'public');
const API_KEY = process.env.API_KEY || generateApiKey();
const ENABLE_WEBHOOK = process.env.ENABLE_WEBHOOK === 'true';
const GIT_REPO_PATH = process.env.GIT_REPO_PATH || __dirname;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || '';

// Git version tracker (updated on webhook pull)
let gitVersion = Date.now();

// 访问鉴权配置
const ENABLE_AUTH = process.env.ENABLE_AUTH === 'true';
const SESSION_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 天

// 从旧 AUTH_USERS 环境变量提取密码（兼容迁移）
function extractPasswordFallback(authUsersStr) {
  if (!authUsersStr) return null;
  const first = authUsersStr.split(',')[0];
  const parts = first.split(':');
  return parts.length >= 2 ? parts.slice(1).join(':').trim() : null;
}

// 单密码鉴权
const AUTH_PASSWORD = process.env.AUTH_PASSWORD
  || extractPasswordFallback(process.env.AUTH_USERS)
  || 'admin';

// Session 管理（内存 Map）
const SESSIONS = new Map(); // token → { createdAt }

// 首次启动时保存生成的 API Key
const isFirstRun = !process.env.API_KEY;

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

// ── API Auth (Bearer Token) ──
function requireAuth(req) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  return token === API_KEY;
}

// ── Cookie 解析 ──
function parseCookies(req) {
  const cookies = {};
  const header = req.headers.cookie;
  if (!header) return cookies;
  header.split(';').forEach(pair => {
    const [name, ...rest] = pair.trim().split('=');
    if (name) cookies[name] = decodeURIComponent(rest.join('='));
  });
  return cookies;
}

// ── Session 创建 ──
function createSession() {
  const token = randomBytes(32).toString('hex');
  SESSIONS.set(token, { createdAt: Date.now() });
  return token;
}

// ── Session 清理（过期） ──
function cleanExpiredSessions() {
  const now = Date.now();
  for (const [token, session] of SESSIONS) {
    if (now - session.createdAt > SESSION_MAX_AGE) {
      SESSIONS.delete(token);
    }
  }
}

// ── Session 鉴权 ──
// 优先 Cookie session，兼容 Basic Auth（API 向后兼容）
// 返回 { authenticated: true } 或 null
// options.redirect: 未登录时是否 302 重定向（默认 true，API 调用设为 false）
function requireSession(req, res, options = {}) {
  if (!ENABLE_AUTH) return { authenticated: true };

  const { redirect = true } = options;

  // 1. 尝试从 Cookie 读取 session
  const cookies = parseCookies(req);
  if (cookies.session) {
    const session = SESSIONS.get(cookies.session);
    if (session && (Date.now() - session.createdAt < SESSION_MAX_AGE)) {
      return { authenticated: true };
    }
  }

  // 2. 兼容 Basic Auth（保持 API 向后兼容）
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Basic ')) {
    try {
      const base64Credentials = authHeader.split(' ')[1];
      const credentials = Buffer.from(base64Credentials, 'base64').toString('utf-8');
      // 只验证密码部分（忽略用户名）
      const colonIndex = credentials.indexOf(':');
      const password = colonIndex >= 0 ? credentials.slice(colonIndex + 1) : credentials;
      if (password === AUTH_PASSWORD) {
        return { authenticated: true };
      }
    } catch {
      // Basic Auth 解析失败，继续到未认证处理
    }
  }

  // 3. 未认证
  if (redirect) {
    res.writeHead(302, { 'Location': '/login' });
    res.end();
  } else {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
  }
  return null;
}

// ── XHS API ──
async function handleApiXhsList(req, res) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  try {
    const entries = await readdir(GIT_REPO_PATH, { withFileTypes: true });
    const xhsDirs = entries.filter(e => e.isDirectory() && e.name.startsWith('xhs-'));
    const articles = [];

    for (const dir of xhsDirs) {
      const readmePath = join(GIT_REPO_PATH, dir.name, 'README.md');
      try {
        const content = await readFile(readmePath, 'utf-8');
        const meta = parseXhsReadme(content, dir.name);
        if (meta) {
          const s = await stat(readmePath);
          meta.updatedAt = toISO(s.mtime);
          articles.push(meta);
        }
      } catch { /* skip */ }
    }

    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    });
    res.end(JSON.stringify(articles));
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  }
}

async function handleApiXhsDetail(req, res, slug) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  try {
    const dirName = slug.startsWith('xhs-') ? slug : `xhs-${slug}`;
    const readmePath = join(GIT_REPO_PATH, dirName, 'README.md');
    const content = await readFile(readmePath, 'utf-8');
    const meta = parseXhsReadme(content, dirName);
    if (!meta) { res.writeHead(404); res.end('Not Found'); return; }
    const rs = await stat(readmePath);
    meta.updatedAt = toISO(rs.mtime);

    // Get image list with mtimes
    const imagesDir = join(GIT_REPO_PATH, 'images', dirName);
    let images = [];
    try {
      const files = await readdir(imagesDir);
      const imageFiles = files.filter(f => /\.(png|jpg|jpeg|webp|gif)$/i.test(f)).sort((a, b) => {
        const na = parseInt(a.match(/(\d+)/)?.[1] || '0');
        const nb = parseInt(b.match(/(\d+)/)?.[1] || '0');
        return na - nb;
      });
      for (const f of imageFiles) {
        try {
          const s = await stat(join(imagesDir, f));
          images.push({ name: f, mtime: Math.floor(s.mtimeMs) });
        } catch {
          images.push({ name: f, mtime: 0 });
        }
      }
    } catch { /* no images */ }

    // Get latest publish draft
    let publishContent = '';
    try {
      const allFiles = await readdir(GIT_REPO_PATH);
      const drafts = allFiles.filter(f => f.startsWith(dirName + '-') && f.endsWith('.md')).sort();
      if (drafts.length > 0) {
        publishContent = await readFile(join(GIT_REPO_PATH, drafts[drafts.length - 1]), 'utf-8');
      }
    } catch { /* no draft */ }

    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    });
    res.end(JSON.stringify({ ...meta, images, publishContent }));
  } catch (e) {
    if (e.code === 'ENOENT') { res.writeHead(404); res.end('Not Found'); }
    else { res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: e.message })); }
  }
}

function toISO(d) {
  return d.toISOString();
}

function parseXhsReadme(content, dirName) {
  const get = (key) => {
    const m = content.match(new RegExp(`\\*\\*${key}\\*\\*:\\s*(.+)`, 'i'));
    return m ? m[1].trim() : '';
  };
  const slug = get('slug') || dirName.replace(/^xhs-/, '');
  const title = get('标题') || slug;
  const date = get('创建日期') || '';
  const status = get('状态') || '📝 草稿';
  const style = get('风格') || 'light';
  const slides = parseInt(get('Slides') || '0');
  return { slug, dirName, title, date, status, style, slides };
}

// ── Parse JSON body ──
async function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => body += chunk.toString());
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

// ── Parse multipart form data (simple) ──
async function parseMultipart(req) {
  const boundary = req.headers['content-type']?.match(/boundary=(.+)$/)?.[1];
  if (!boundary) throw new Error('No boundary in multipart');

  return new Promise((resolve, reject) => {
    let buffer = Buffer.alloc(0);
    req.on('data', chunk => buffer = Buffer.concat([buffer, chunk]));
    req.on('end', () => {
      try {
        const parts = buffer.toString('binary').split(`--${boundary}`);
        const files = {};

        for (const part of parts) {
          const match = part.match(/name="([^"]+)"(?:; filename="([^"]+)")?\r?\n(?:Content-Type: ([^\r\n]+))?\r?\n\r?\n([\s\S]*?)(?:\r?\n)?$/);
          if (match) {
            const [, name, filename, , content] = match;
            if (filename) {
              files[name] = { filename, content: content.trim() };
            }
          }
        }
        resolve(files);
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

// ── Git file times: use git log instead of fs mtime ──
async function getGitFileTimes(dir) {
  try {
    // Get path prefix within the git repo (e.g. "docs/" or "")
    const { stdout: prefix } = await execAsync('git rev-parse --show-prefix', { cwd: dir });
    const pathPrefix = prefix.trim();

    const { stdout } = await execAsync(
      'git log --format="COMMIT_TS:%at" --name-only --diff-filter=ACMR',
      { cwd: dir, maxBuffer: 10 * 1024 * 1024 }
    );

    const times = new Map();
    let currentTs = 0;

    for (const line of stdout.split('\n')) {
      if (line.startsWith('COMMIT_TS:')) {
        currentTs = parseInt(line.slice(10)) * 1000;
      } else if (line.trim() && currentTs) {
        let filename = line.trim();
        // Strip path prefix to get filename relative to dir
        if (pathPrefix && filename.startsWith(pathPrefix)) {
          filename = filename.slice(pathPrefix.length);
        }
        // Only include files directly in dir (skip subdirectories)
        if (!filename.includes('/') && !times.has(filename)) {
          times.set(filename, currentTs);
        }
      }
    }

    return times.size > 0 ? times : null;
  } catch {
    return null; // Not a git repo or git not available
  }
}

// Title extraction: first # heading or filename
async function extractMeta(filepath, filename, gitMtime) {
  try {
    const content = await readFile(filepath, 'utf-8');
    const titleMatch = content.match(/^#\s+(.+)/m);
    const title = titleMatch ? titleMatch[1].replace(/[*_`]/g, '') : filename;
    // Extract first few meaningful lines for desc
    const lines = content.split('\n').filter(l => l.trim() && !l.startsWith('#') && !l.startsWith('>'));
    const desc = lines[0]?.slice(0, 80) || '';
    const s = await stat(filepath);
    return { file: filename, title, desc, mtime: gitMtime || s.mtimeMs };
  } catch {
    return { file: filename, title: filename, desc: '', mtime: 0 };
  }
}

async function handleApiDocs(req, res) {
  // 支持两种认证方式：
  // 1. Bearer Token（用于 API 调用）
  // 2. Session / Basic Auth（用于前端访问）
  const hasApiAuth = requireAuth(req);
  if (!hasApiAuth) {
    const user = requireSession(req, res, { redirect: false });
    if (!user) return;
  }

  const files = await readdir(DOCS_DIR);
  const mdFiles = files.filter(f => f.endsWith('.md'));

  // Try git commit times (accurate even after git pull), fall back to fs mtime
  const gitTimes = await getGitFileTimes(DOCS_DIR);

  const docs = await Promise.all(
    mdFiles.map(f => extractMeta(join(DOCS_DIR, f), f, gitTimes?.get(f)))
  );
  docs.sort((a, b) => b.mtime - a.mtime); // newest first
  res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(docs));
}

// ── POST /api/docs - Upload document ──
async function handleUploadDoc(req, res) {
  if (!requireAuth(req)) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  try {
    let filename, content;

    if (req.headers['content-type']?.includes('application/json')) {
      const body = await parseBody(req);
      filename = body.filename;
      content = body.content;
    } else if (req.headers['content-type']?.includes('multipart/form-data')) {
      const files = await parseMultipart(req);
      const file = files.file;
      if (!file) throw new Error('No file uploaded');
      filename = file.filename;
      content = file.content;
    } else {
      throw new Error('Unsupported content type');
    }

    if (!filename?.endsWith('.md')) {
      throw new Error('Only .md files allowed');
    }

    // Sanitize filename
    filename = filename.replace(/[^a-zA-Z0-9._\u4e00-\u9fa5-]/g, '_');
    const filepath = join(DOCS_DIR, filename);

    await writeFile(filepath, content, 'utf-8');

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, filename, message: 'Document uploaded' }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── DELETE /api/docs/:filename ──
async function handleDeleteDoc(req, res, filename) {
  if (!requireAuth(req)) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  try {
    if (!filename?.endsWith('.md')) {
      throw new Error('Only .md files can be deleted');
    }

    const filepath = join(DOCS_DIR, filename);
    if (!filepath.startsWith(DOCS_DIR)) {
      throw new Error('Invalid filename');
    }

    await unlink(filepath);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'Document deleted' }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── Read raw body (Buffer) ──
async function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

// ── Verify webhook signature ──
function verifyWebhookSignature(req, rawBody) {
  // If no secret configured, skip verification (backward compatible)
  if (!WEBHOOK_SECRET) {
    console.warn('[Webhook] No WEBHOOK_SECRET configured, skipping signature verification');
    return true;
  }

  // 1. GitHub: X-Hub-Signature-256 (HMAC-SHA256)
  const githubSig = req.headers['x-hub-signature-256'];
  if (githubSig) {
    const expected = 'sha256=' + createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex');
    const expectedBuf = Buffer.from(expected);
    const receivedBuf = Buffer.from(githubSig);
    if (expectedBuf.length === receivedBuf.length && timingSafeEqual(expectedBuf, receivedBuf)) {
      return true;
    }
    console.warn('[Webhook] GitHub signature verification failed');
    return false;
  }

  // 2. GitLab: X-Gitlab-Token (simple token comparison)
  const gitlabToken = req.headers['x-gitlab-token'];
  if (gitlabToken) {
    const expectedBuf = Buffer.from(WEBHOOK_SECRET);
    const receivedBuf = Buffer.from(gitlabToken);
    if (expectedBuf.length === receivedBuf.length && timingSafeEqual(expectedBuf, receivedBuf)) {
      return true;
    }
    console.warn('[Webhook] GitLab token verification failed');
    return false;
  }

  // 3. Secret configured but no signature header provided
  console.warn('[Webhook] WEBHOOK_SECRET is set but no signature header found (expected X-Hub-Signature-256 or X-Gitlab-Token)');
  return false;
}

// ── POST /api/webhook - Git webhook ──
async function handleWebhook(req, res) {
  if (!ENABLE_WEBHOOK) {
    res.writeHead(404);
    res.end('Webhook disabled');
    return;
  }

  // Read raw body for HMAC verification
  const rawBody = await readRawBody(req);

  // Verify webhook secret
  if (!verifyWebhookSignature(req, rawBody)) {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Forbidden: invalid signature' }));
    return;
  }

  try {
    console.log('[Webhook] Received push event, pulling latest changes...');
    const { stdout, stderr} = await execAsync('git pull', { cwd: GIT_REPO_PATH });
    console.log('[Webhook] Git pull output:', stdout);
    if (stderr) console.error('[Webhook] Git pull stderr:', stderr);

    // Bump version so frontends know to refresh
    gitVersion = Date.now();

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'Updated from git', output: stdout }));
  } catch (error) {
    console.error('[Webhook] Error:', error);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── POST /api/login ──
async function handleLogin(req, res) {
  try {
    const body = await parseBody(req);
    const { password } = body;

    if (!password) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '密码不能为空' }));
      return;
    }

    if (password !== AUTH_PASSWORD) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '密码错误' }));
      return;
    }

    const token = createSession();
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Set-Cookie': `session=${token}; HttpOnly; Path=/; SameSite=Lax; Max-Age=${SESSION_MAX_AGE / 1000}`,
    });
    res.end(JSON.stringify({ success: true }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── POST /api/logout ──
function handleLogout(req, res) {
  const cookies = parseCookies(req);
  if (cookies.session) {
    SESSIONS.delete(cookies.session);
  }
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Set-Cookie': 'session=; HttpOnly; Path=/; SameSite=Lax; Max-Age=0',
  });
  res.end(JSON.stringify({ success: true }));
}

// ── GET /api/me ──
function handleMe(req, res) {
  if (!ENABLE_AUTH) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ authenticated: true, authEnabled: false }));
    return;
  }

  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ authenticated: true, authEnabled: true }));
}

async function serveStatic(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/') pathname = '/index.html';

  // 登录页公开访问
  if (pathname === '/login.html' || pathname === '/login') {
    const filepath = join(PUBLIC_DIR, 'login.html');
    try {
      const data = await readFile(filepath);
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache' });
      res.end(data);
    } catch {
      res.writeHead(404); res.end('Not Found');
    }
    return;
  }

  // 其他页面需要认证
  const user = requireSession(req, res);
  if (!user) return;

  // Web UI 静态文件从 public/ 目录提供，文档从 docs/ 目录提供
  const isPublicFile = pathname === '/index.html';
  const baseDir = isPublicFile ? PUBLIC_DIR : DOCS_DIR;
  const filepath = join(baseDir, pathname);

  // Security: ensure within allowed directory
  if (!filepath.startsWith(baseDir)) {
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
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // CORS headers for API endpoints
  if (pathname.startsWith('/api/')) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }
  }

  // Health check endpoint (no auth required)
  if (pathname === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache' });
    res.end(JSON.stringify({ status: 'ok', timestamp: Date.now() }));
    return;
  }

  // XHS API Routes
  if (pathname === '/api/xhs' && req.method === 'GET') {
    return handleApiXhsList(req, res);
  }
  // Version endpoint (no auth, for polling)
  if (pathname === '/api/xhs/version' && req.method === 'GET') {
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    });
    res.end(JSON.stringify({ version: gitVersion }));
    return;
  }
  if (pathname.startsWith('/api/xhs/') && req.method === 'GET') {
    const slug = decodeURIComponent(pathname.replace('/api/xhs/', ''));
    return handleApiXhsDetail(req, res, slug);
  }

  // XHS images (from GIT_REPO_PATH/images/)
  if (pathname.startsWith('/images/xhs-')) {
    const user = requireSession(req, res);
    if (!user) return;
    const filePath = join(GIT_REPO_PATH, decodeURIComponent(pathname.slice(1)));
    if (!filePath.startsWith(join(GIT_REPO_PATH, 'images'))) {
      res.writeHead(403); res.end('Forbidden'); return;
    }
    try {
      const s = await stat(filePath);
      const etag = `"${Math.floor(s.mtimeMs).toString(36)}-${s.size.toString(36)}"`;
      if (req.headers['if-none-match'] === etag) {
        res.writeHead(304); res.end(); return;
      }
      const data = await readFile(filePath);
      const ext = extname(filePath);
      res.writeHead(200, {
        'Content-Type': MIME[ext] || 'application/octet-stream',
        'Cache-Control': 'public, max-age=31536000, immutable',
        'ETag': etag,
      });
      res.end(data);
    } catch {
      res.writeHead(404); res.end('Not Found');
    }
    return;
  }

  // XHS page (SPA)
  if (pathname === '/xhs' || pathname.startsWith('/xhs/')) {
    const user = requireSession(req, res);
    if (!user) return;
    try {
      const data = await readFile(join(PUBLIC_DIR, 'xhs.html'));
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache' });
      res.end(data);
    } catch {
      res.writeHead(404); res.end('Not Found');
    }
    return;
  }

  // API Routes
  if (pathname === '/api/docs' && req.method === 'GET') {
    return handleApiDocs(req, res);
  }

  if (pathname === '/api/docs' && req.method === 'POST') {
    return handleUploadDoc(req, res);
  }

  if (pathname.startsWith('/api/docs/') && req.method === 'DELETE') {
    const filename = decodeURIComponent(pathname.replace('/api/docs/', ''));
    return handleDeleteDoc(req, res, filename);
  }

  if (pathname === '/api/webhook' && req.method === 'POST') {
    return handleWebhook(req, res);
  }

  // Auth API
  if (pathname === '/api/login' && req.method === 'POST') {
    return handleLogin(req, res);
  }

  if (pathname === '/api/logout' && req.method === 'POST') {
    return handleLogout(req, res);
  }

  if (pathname === '/api/me' && req.method === 'GET') {
    return handleMe(req, res);
  }

  // Static files
  return serveStatic(req, res);
});

// 定时清理过期 session（每小时）
setInterval(cleanExpiredSessions, 60 * 60 * 1000);

server.listen(PORT, '0.0.0.0', async () => {
  // 迁移警告：旧 AUTH_USERS 环境变量
  if (ENABLE_AUTH && process.env.AUTH_USERS && !process.env.AUTH_PASSWORD) {
    console.warn(`\n⚠️  [Migration] AUTH_USERS is deprecated. Please switch to AUTH_PASSWORD.`);
    console.warn(`   Current password extracted from AUTH_USERS: ${AUTH_PASSWORD}`);
    console.warn(`   Update your config: AUTH_PASSWORD=${AUTH_PASSWORD}\n`);
  }

  console.log(`\n📚 Docs Share Server`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`🌐 Server:    http://0.0.0.0:${PORT}`);
  console.log(`📁 Docs dir:  ${DOCS_DIR}`);

  if (isFirstRun) {
    console.log(`🔑 API Key:   ${API_KEY}`);
    console.log(`⚠️  AUTO-GENERATED! Please save this key.`);

    // 尝试保存到 .env 文件
    const envPath = join(__dirname, '.env');
    try {
      const envContent = `# Docs Share Configuration
# Auto-generated on first run: ${new Date().toISOString()}

PORT=${PORT}
API_KEY=${API_KEY}
ENABLE_WEBHOOK=false
`;
      await writeFile(envPath, envContent, { flag: 'wx' }); // wx = 只在文件不存在时写入
      console.log(`✓ Saved to: ${envPath}`);
    } catch (err) {
      if (err.code !== 'EEXIST') {
        console.log(`⚠️  Could not save .env file (please save the key manually)`);
      }
    }
  } else {
    console.log(`🔑 API Key:   ✓ Loaded from environment`);
  }

  console.log(`🔗 Webhook:   ${ENABLE_WEBHOOK ? '✓ Enabled' : '✗ Disabled'}${ENABLE_WEBHOOK ? ` (Secret: ${WEBHOOK_SECRET ? '✓ Configured' : '⚠ Not set, verification disabled'})` : ''}`);
  console.log(`🔒 Auth:      ${ENABLE_AUTH ? '✓ Enabled (Password protected)' : '✗ Disabled (Public access)'}`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);
  console.log(`API Endpoints:`);
  console.log(`  GET    /api/docs          - List all documents`);
  console.log(`  POST   /api/docs          - Upload document (requires auth)`);
  console.log(`  DELETE /api/docs/:file    - Delete document (requires auth)`);
  if (ENABLE_WEBHOOK) {
    console.log(`  POST   /api/webhook       - Git webhook handler`);
  }
  if (ENABLE_AUTH) {
    console.log(`  POST   /api/login         - Login`);
    console.log(`  POST   /api/logout        - Logout`);
    console.log(`  GET    /api/me            - Current user info`);
  }
  console.log();
});
