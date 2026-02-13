import { createServer } from 'http';
import { readdir, readFile, stat, writeFile, unlink, access } from 'fs/promises';
import { join, extname } from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';
import { randomBytes } from 'crypto';

const execAsync = promisify(exec);

// 自动生成 API Key（如果未设置）
function generateApiKey() {
  return randomBytes(32).toString('base64');
}

const PORT = process.env.PORT || 3457;
const DOCS_DIR = join(import.meta.dirname, 'docs');
const USERS_FILE = join(import.meta.dirname, 'users.json');
const API_KEY = process.env.API_KEY || generateApiKey();
const ENABLE_WEBHOOK = process.env.ENABLE_WEBHOOK === 'true';
const GIT_REPO_PATH = process.env.GIT_REPO_PATH || import.meta.dirname;

// 访问鉴权配置
const ENABLE_AUTH = process.env.ENABLE_AUTH === 'true';

// 用户数据（从文件加载或从环境变量初始化）
let AUTH_USERS = new Map();
let ADMIN_USER = null;

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

// ── HTTP Basic Auth (前端访问鉴权) ──
// 返回用户信息对象或 null
function requireBasicAuth(req, res) {
  if (!ENABLE_AUTH) return { username: 'anonymous', role: 'user' };

  const authHeader = req.headers.authorization;

  // 如果没有认证信息，返回 401 并要求认证
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    res.writeHead(401, {
      'WWW-Authenticate': 'Basic realm="Docs Share - Protected Area"',
      'Content-Type': 'text/html; charset=utf-8'
    });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>认证required</title>
        <style>
          body { font-family: sans-serif; padding: 50px; text-align: center; }
          h1 { color: #333; }
        </style>
      </head>
      <body>
        <h1>🔒 需要登录</h1>
        <p>此文档站受保护，请输入用户名和密码。</p>
      </body>
      </html>
    `);
    return null;
  }

  // 解析 Basic Auth 凭证
  try {
    const base64Credentials = authHeader.split(' ')[1];
    const credentials = Buffer.from(base64Credentials, 'base64').toString('utf-8');
    const [username, password] = credentials.split(':');

    // 验证用户名和密码
    const userInfo = AUTH_USERS.get(username);
    if (userInfo && userInfo.password === password) {
      return { username, role: userInfo.role };
    }

    // 认证失败
    res.writeHead(401, {
      'WWW-Authenticate': 'Basic realm="Docs Share - Protected Area"',
      'Content-Type': 'text/html; charset=utf-8'
    });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>认证失败</title>
        <style>
          body { font-family: sans-serif; padding: 50px; text-align: center; }
          h1 { color: #e74c3c; }
        </style>
      </head>
      <body>
        <h1>❌ 认证失败</h1>
        <p>用户名或密码错误。</p>
      </body>
      </html>
    `);
    return null;
  } catch (error) {
    res.writeHead(401, {
      'WWW-Authenticate': 'Basic realm="Docs Share - Protected Area"'
    });
    res.end('Unauthorized');
    return null;
  }
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

async function handleApiDocs(req, res) {
  // 支持两种认证方式：
  // 1. Bearer Token（用于 API 调用）
  // 2. Basic Auth（用于前端访问）
  const hasApiAuth = requireAuth(req);
  if (!hasApiAuth) {
    const user = requireBasicAuth(req, res);
    if (!user) {
      return; // requireBasicAuth 已经返回 401
    }
  }

  const files = await readdir(DOCS_DIR);
  const mdFiles = files.filter(f => f.endsWith('.md'));
  const docs = await Promise.all(mdFiles.map(f => extractMeta(join(DOCS_DIR, f), f)));
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

// ── POST /api/webhook - Git webhook ──
async function handleWebhook(req, res) {
  if (!ENABLE_WEBHOOK) {
    res.writeHead(404);
    res.end('Webhook disabled');
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
  const user = requireBasicAuth(req, res);
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
  const user = requireBasicAuth(req, res);
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
  const user = requireBasicAuth(req, res);
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

async function serveStatic(req, res) {
  // 前端访问需要 Basic Auth 鉴权
  const user = requireBasicAuth(req, res);
  if (!user) {
    return;
  }

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
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // CORS headers for API endpoints
  if (pathname.startsWith('/api/')) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }
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

  if (pathname.startsWith('/api/users/') && req.method === 'DELETE') {
    const username = decodeURIComponent(pathname.replace('/api/users/', ''));
    return handleDeleteUser(req, res, username);
  }

  // Static files
  return serveStatic(req, res);
});

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
    const envPath = join(import.meta.dirname, '.env');
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

  console.log(`🔗 Webhook:   ${ENABLE_WEBHOOK ? '✓ Enabled' : '✗ Disabled'}`);
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
    console.log(`  GET    /api/users         - List users (admin only)`);
    console.log(`  POST   /api/users         - Add user (admin only)`);
    console.log(`  DELETE /api/users/:user   - Delete user (admin only)`);
  }
  console.log();
});
