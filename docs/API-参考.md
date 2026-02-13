# 🔌 API 参考文档

Docs Share 提供了一套简单的 REST API 用于远程管理文档。

## 认证

所有需要认证的端点都使用 Bearer Token 认证：

```
Authorization: Bearer <your-api-key>
```

API Key 通过环境变量 `API_KEY` 设置（默认：`dev-key-change-in-production`）

## 端点

### GET /api/docs

获取所有文档列表。

**无需认证**

**响应示例：**

```json
[
  {
    "file": "hello.md",
    "title": "Hello World",
    "desc": "这是一个示例文档",
    "mtime": 1707825600000
  },
  {
    "file": "guide.md",
    "title": "使用指南",
    "desc": "快速开始使用 Docs Share",
    "mtime": 1707825500000
  }
]
```

**字段说明：**
- `file`: 文件名
- `title`: 文档标题（从第一个 # 标题提取，或使用文件名）
- `desc`: 文档描述（第一行非标题内容）
- `mtime`: 修改时间（毫秒时间戳）

---

### POST /api/docs

上传或更新文档。

**需要认证**

**请求头：**
```
Content-Type: application/json
Authorization: Bearer <api-key>
```

**请求体（JSON）：**

```json
{
  "filename": "my-doc.md",
  "content": "# 标题\n\n内容..."
}
```

**响应示例（成功）：**

```json
{
  "success": true,
  "filename": "my-doc.md",
  "message": "Document uploaded"
}
```

**响应示例（失败）：**

```json
{
  "error": "Only .md files allowed"
}
```

**cURL 示例：**

```bash
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.md",
    "content": "# Test Document\n\nThis is a test."
  }'
```

**注意事项：**
- 文件名必须以 `.md` 结尾
- 文件名会被清理（特殊字符替换为 `_`）
- 如果文件已存在会被覆盖

---

### DELETE /api/docs/:filename

删除指定文档。

**需要认证**

**请求头：**
```
Authorization: Bearer <api-key>
```

**URL 参数：**
- `filename`: 要删除的文件名（需 URL 编码）

**响应示例（成功）：**

```json
{
  "success": true,
  "message": "Document deleted"
}
```

**cURL 示例：**

```bash
curl -X DELETE http://localhost:3457/api/docs/test.md \
  -H "Authorization: Bearer your-api-key"
```

---

### POST /api/webhook

Git webhook 处理端点。接收 push 事件并执行 `git pull`。

**仅在 `ENABLE_WEBHOOK=true` 时可用**

**请求体：** GitHub/GitLab webhook payload（自动发送）

**响应示例（成功）：**

```json
{
  "success": true,
  "message": "Updated from git",
  "output": "Already up to date."
}
```

**手动触发：**

```bash
curl -X POST http://localhost:3457/api/webhook
```

---

## 错误码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 204 | 成功（无内容） |
| 400 | 请求错误（如文件格式不对） |
| 401 | 未授权（API Key 错误或缺失） |
| 404 | 未找到（文件不存在或端点禁用） |
| 500 | 服务器错误 |

## 速率限制

当前版本没有内置速率限制，建议在生产环境通过反向代理（如 Nginx）配置：

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

location /api/ {
    limit_req zone=api burst=20;
    proxy_pass http://localhost:3457;
}
```

## CORS

API 端点已配置 CORS，允许跨域访问：

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

生产环境建议修改 `server.mjs` 限制允许的域名。

## 使用示例

### JavaScript/Node.js

```javascript
const API_URL = 'http://localhost:3457';
const API_KEY = 'your-api-key';

// 上传文档
async function uploadDoc(filename, content) {
  const response = await fetch(`${API_URL}/api/docs`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ filename, content }),
  });
  return response.json();
}

// 获取文档列表
async function listDocs() {
  const response = await fetch(`${API_URL}/api/docs`);
  return response.json();
}

// 删除文档
async function deleteDoc(filename) {
  const response = await fetch(`${API_URL}/api/docs/${filename}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
    },
  });
  return response.json();
}

// AI 集成示例：使用 Claude 4.6 生成并上传文档
import Anthropic from '@anthropic-ai/sdk';

async function aiGenerateAndUpload(topic) {
  // 1. 使用 Claude 4.6 生成文档
  const anthropic = new Anthropic({ apiKey: 'your-anthropic-key' });
  const message = await anthropic.messages.create({
    model: 'claude-opus-4-6',  // 最强大的 Claude 模型
    max_tokens: 8192,
    messages: [
      { role: 'user', content: `写一篇关于${topic}的技术文档，使用 Markdown 格式` }
    ],
  });
  const content = message.content[0].text;

  // 2. 自动上传到 Docs Share
  const filename = `${topic.replace(/\s+/g, '-')}.md`;
  return uploadDoc(filename, content);
}
```

### Python

```python
import requests

API_URL = 'http://localhost:3457'
API_KEY = 'your-api-key'

# 上传文档
def upload_doc(filename, content):
    response = requests.post(
        f'{API_URL}/api/docs',
        headers={'Authorization': f'Bearer {API_KEY}'},
        json={'filename': filename, 'content': content}
    )
    return response.json()

# 获取文档列表
def list_docs():
    response = requests.get(f'{API_URL}/api/docs')
    return response.json()

# 删除文档
def delete_doc(filename):
    response = requests.delete(
        f'{API_URL}/api/docs/{filename}',
        headers={'Authorization': f'Bearer {API_KEY}'}
    )
    return response.json()

# AI 集成示例：使用 Claude 4.6 生成并上传文档
import anthropic

def ai_generate_and_upload(topic):
    # 1. 使用 Claude 4.6 生成文档
    client = anthropic.Anthropic(api_key='your-anthropic-key')
    message = client.messages.create(
        model='claude-opus-4-6',
        max_tokens=8192,
        messages=[
            {'role': 'user', 'content': f'写一篇关于{topic}的技术文档，使用 Markdown 格式'}
        ]
    )
    content = message.content[0].text

    # 2. 自动上传到 Docs Share
    filename = f'{topic.replace(" ", "-")}.md'
    return upload_doc(filename, content)
```

### Shell

```bash
API_URL="http://localhost:3457"
API_KEY="your-api-key"

# 上传文档
upload_doc() {
    local filename=$1
    local content=$(cat $filename)
    curl -X POST "$API_URL/api/docs" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"filename\":\"$filename\",\"content\":\"$content\"}"
}

# 列出文档
list_docs() {
    curl "$API_URL/api/docs" | jq
}

# 删除文档
delete_doc() {
    local filename=$1
    curl -X DELETE "$API_URL/api/docs/$filename" \
        -H "Authorization: Bearer $API_KEY"
}
```

---

💡 **提示**：使用 CLI 工具 (`npx docs-share`) 可以更方便地调用这些 API！
