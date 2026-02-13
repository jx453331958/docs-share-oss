import { createServer } from 'http';
import { readdir, readFile, stat, writeFile, unlink, access } from 'fs/promises';
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
const USERS_FILE = join(__dirname, 'users.json');
const API_KEY = process.env.API_KEY || generateApiKey();
const ENABLE_WEBHOOK = process.env.ENABLE_WEBHOOK === 'true';
const GIT_REPO_PATH = process.env.GIT_REPO_PATH || __dirname;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || randomBytes(32).toString('hex');

// 访问鉴权配置
const ENABLE_AUTH = process.env.ENABLE_AUTH === 'true';
const SESSION_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 天

// 用户数据（从文件加载或从环境变量初始化）
let AUTH_USERS = new Map();
let ADMIN_USER = null;

// Session 管理（内存 Map）
const SESSIONS = new Map(); // token → { username, role, createdAt }

// 首次启动时保存生成的 API Key
const isFirstRun = !process.env.API_KEY;

// 加载用户数据
async function loadUsers() {
  try {
    await access(USERS_FILE);
    const data = await readFile(USERS_FILE, 'utf-8');
    const users = JSON.parse(data);
    AUTH_USERS = new Map();
    for (const [username, info] of Object.entries(users)) {
      AUTH_USERS.set(username, info);
      if (info.role === 'admin') {
        ADMIN_USER = username;
      }
    }
    console.log(`[Auth] Loaded ${AUTH_USERS.size} users from ${USERS_FILE}`);
  } catch {
    // 文件不存在，从环境变量初始化
    AUTH_USERS = parseAuthUsers(process.env.AUTH_USERS);
    // 保存到文件
    await saveUsers();
  }
}

// 保存用户数据
async function saveUsers() {
  const usersObj = {};
  for (const [username, info] of AUTH_USERS) {
    usersObj[username] = info;
  }
  await writeFile(USERS_FILE, JSON.stringify(usersObj, null, 2), 'utf-8');
  console.log(`[Auth] Saved ${AUTH_USERS.size} users to ${USERS_FILE}`);
}

// 解析用户列表：格式 "user1:pass1,user2:pass2"
// 兼容旧格式（仅密码）和新格式（带角色信息）
function parseAuthUsers(usersStr) {
  if (!usersStr) {
    const defaultUsers = new Map();
    defaultUsers.set('admin', { password: 'admin', role: 'admin' });
    ADMIN_USER = 'admin';
    return defaultUsers;
  }

  const users = new Map();
  const pairs = usersStr.split(',');

  pairs.forEach((pair, index) => {
    const [user, pass] = pair.split(':');
    if (user && pass) {
      const username = user.trim();
      // 第一个用户是管理员
      const role = index === 0 ? 'admin' : 'user';
      users.set(username, { password: pass.trim(), role });
      if (role === 'admin') {
        ADMIN_USER = username;
      }
    }
  });

  if (users.size === 0) {
    users.set('admin', { password: 'admin', role: 'admin' });
    ADMIN_USER = 'admin';
  }

  return users;
}

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
function createSession(username, role) {
  const token = randomBytes(32).toString('hex');
  SESSIONS.set(token, { username, role, createdAt: Date.now() });
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

// ── Session 鉴权（替代 Basic Auth）──
// 优先 Cookie session，兼容 Basic Auth（API 向后兼容）
// 返回用户信息对象或 null
// options.redirect: 未登录时是否 302 重定向（默认 true，API 调用设为 false）
function requireSession(req, res, options = {}) {
  if (!ENABLE_AUTH) return { username: 'anonymous', role: 'user' };

  const { redirect = true } = options;

  // 1. 尝试从 Cookie 读取 session
  const cookies = parseCookies(req);
  if (cookies.session) {
    const session = SESSIONS.get(cookies.session);
    if (session && (Date.now() - session.createdAt < SESSION_MAX_AGE)) {
      // 确保用户仍然存在
      const userInfo = AUTH_USERS.get(session.username);
      if (userInfo) {
        return { username: session.username, role: userInfo.role };
      }
      // 用户已被删除，清除 session
      SESSIONS.delete(cookies.session);
    }
  }

  // 2. 兼容 Basic Auth（保持 API 向后兼容）
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Basic ')) {
    try {
      const base64Credentials = authHeader.split(' ')[1];
      const credentials = Buffer.from(base64Credentials, 'base64').toString('utf-8');
      const [username, password] = credentials.split(':');
      const userInfo = AUTH_USERS.get(username);
      if (userInfo && userInfo.password === password) {
        return { username, role: userInfo.role };
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

  // 3. No signature header provided
  console.warn('[Webhook] No signature header found (expected X-Hub-Signature-256 or X-Gitlab-Token)');
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

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'Updated from git', output: stdout }));
  } catch (error) {
    console.error('[Webhook] Error:', error);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── GET /api/users - 获取用户列表（仅管理员）──
async function handleGetUsers(req, res) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  if (user.role !== 'admin') {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Forbidden: Admin access required' }));
    return;
  }

  const users = [];
  for (const [username, info] of AUTH_USERS) {
    users.push({ username, role: info.role });
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(users));
}

// ── POST /api/users - 添加用户（仅管理员）──
async function handleAddUser(req, res) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  if (user.role !== 'admin') {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Forbidden: Admin access required' }));
    return;
  }

  try {
    const body = await parseBody(req);
    const { username, password } = body;

    if (!username || !password) {
      throw new Error('Username and password are required');
    }

    if (AUTH_USERS.has(username)) {
      throw new Error('User already exists');
    }

    AUTH_USERS.set(username, { password, role: 'user' });
    await saveUsers();

    console.log(`[Auth] User added: ${username}`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'User added successfully' }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── DELETE /api/users/:username - 删除用户（仅管理员）──
async function handleDeleteUser(req, res, username) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  if (user.role !== 'admin') {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Forbidden: Admin access required' }));
    return;
  }

  try {
    if (!AUTH_USERS.has(username)) {
      throw new Error('User not found');
    }

    const userInfo = AUTH_USERS.get(username);
    if (userInfo.role === 'admin') {
      throw new Error('Cannot delete admin user');
    }

    AUTH_USERS.delete(username);
    await saveUsers();

    console.log(`[Auth] User deleted: ${username}`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: 'User deleted successfully' }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
}

// ── POST /api/login ──
async function handleLogin(req, res) {
  try {
    const body = await parseBody(req);
    const { username, password } = body;

    if (!username || !password) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '用户名和密码不能为空' }));
      return;
    }

    const userInfo = AUTH_USERS.get(username);
    if (!userInfo || userInfo.password !== password) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '用户名或密码错误' }));
      return;
    }

    const token = createSession(username, userInfo.role);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Set-Cookie': `session=${token}; HttpOnly; Path=/; SameSite=Lax; Max-Age=${SESSION_MAX_AGE / 1000}`,
    });
    res.end(JSON.stringify({ success: true, username, role: userInfo.role }));
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
    res.end(JSON.stringify({ username: 'anonymous', role: 'user', authEnabled: false }));
    return;
  }

  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ username: user.username, role: user.role, authEnabled: true }));
}

// ── PUT /api/users/:username/password ──
async function handleChangePassword(req, res, targetUsername) {
  const user = requireSession(req, res, { redirect: false });
  if (!user) return;

  try {
    const body = await parseBody(req);
    const { oldPassword, newPassword } = body;

    if (!newPassword) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '新密码不能为空' }));
      return;
    }

    if (!AUTH_USERS.has(targetUsername)) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: '用户不存在' }));
      return;
    }

    // 管理员可修改任意用户密码；普通用户只能改自己的，且需验证旧密码
    if (user.role !== 'admin') {
      if (user.username !== targetUsername) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: '无权修改其他用户的密码' }));
        return;
      }
      const userInfo = AUTH_USERS.get(targetUsername);
      if (!oldPassword || userInfo.password !== oldPassword) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: '旧密码错误' }));
        return;
      }
    }

    const targetInfo = AUTH_USERS.get(targetUsername);
    targetInfo.password = newPassword;
    AUTH_USERS.set(targetUsername, targetInfo);
    await saveUsers();

    console.log(`[Auth] Password changed for: ${targetUsername} (by ${user.username})`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, message: '密码修改成功' }));
  } catch (error) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: error.message }));
  }
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
  const isPublicFile = pathname === '/index.html' || pathname === '/users.html';
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
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', timestamp: Date.now() }));
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

  // User management API
  if (pathname === '/api/users' && req.method === 'GET') {
    return handleGetUsers(req, res);
  }

  if (pathname === '/api/users' && req.method === 'POST') {
    return handleAddUser(req, res);
  }

  if (pathname.startsWith('/api/users/') && pathname.endsWith('/password') && req.method === 'PUT') {
    const parts = pathname.replace('/api/users/', '').replace('/password', '');
    const username = decodeURIComponent(parts);
    return handleChangePassword(req, res, username);
  }

  if (pathname.startsWith('/api/users/') && req.method === 'DELETE') {
    const username = decodeURIComponent(pathname.replace('/api/users/', ''));
    return handleDeleteUser(req, res, username);
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
  // 加载用户数据
  if (ENABLE_AUTH) {
    await loadUsers();
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
WEBHOOK_SECRET=${WEBHOOK_SECRET}
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

  console.log(`🔗 Webhook:   ${ENABLE_WEBHOOK ? '✓ Enabled' : '✗ Disabled'}${ENABLE_WEBHOOK ? ` (Secret: ${process.env.WEBHOOK_SECRET ? '✓ From env' : '⚠ Auto-generated'})` : ''}`);
  console.log(`🔒 Auth:      ${ENABLE_AUTH ? `✓ Enabled (${AUTH_USERS.size} user${AUTH_USERS.size > 1 ? 's' : ''})` : '✗ Disabled (Public access)'}`);
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
    console.log(`  GET    /api/users         - List users (admin only)`);
    console.log(`  POST   /api/users         - Add user (admin only)`);
    console.log(`  DELETE /api/users/:user   - Delete user (admin only)`);
    console.log(`  PUT    /api/users/:user/password - Change password`);
  }
  console.log();
});
