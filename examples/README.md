# 📚 示例代码

这个目录包含 Docs Share 的 AI 集成和 API 使用示例。

## AI 集成示例

演示如何将 AI 生成的内容自动发布到 Docs Share。

### ai-integration.js (Node.js)

**使用：**

```bash
# 使用默认主题
node examples/ai-integration.js

# 指定主题
node examples/ai-integration.js "React Hooks 详解"

# 查看帮助
node examples/ai-integration.js --help
```

**集成真实 AI：**

修改 `generateWithAI()` 函数，调用 OpenAI、Anthropic 等 API：

```javascript
// OpenAI 示例
import OpenAI from 'openai';
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function generateWithAI(topic) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',  // 或 'o1-preview' 等最新模型
    messages: [
      { role: 'user', content: `写一篇关于${topic}的详细技术文档` }
    ],
  });
  return response.choices[0].message.content;
}

// Anthropic Claude 示例（推荐使用最新 Claude 4.6）
import Anthropic from '@anthropic-ai/sdk';
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

async function generateWithAI(topic) {
  const message = await anthropic.messages.create({
    model: 'claude-opus-4-6',  // 最强大的 Claude 模型
    max_tokens: 8192,
    messages: [
      { role: 'user', content: `写一篇关于${topic}的详细技术文档` }
    ],
  });
  return message.content[0].text;
}
```

### ai-integration.py (Python)

**安装依赖：**

```bash
pip install requests
```

**使用：**

```bash
# 使用默认主题
python examples/ai-integration.py

# 指定主题
python examples/ai-integration.py "FastAPI 最佳实践"

# 查看帮助
python examples/ai-integration.py --help
```

**集成真实 AI：**

```python
# OpenAI 示例
import openai
openai.api_key = os.getenv('OPENAI_API_KEY')

def generate_with_ai(topic):
    response = openai.ChatCompletion.create(
        model='gpt-4o',  # 或 'o1-preview' 等最新模型
        messages=[
            {'role': 'user', 'content': f'写一篇关于{topic}的详细技术文档'}
        ]
    )
    return response.choices[0].message.content

# Anthropic Claude 示例（推荐使用最新 Claude 4.6）
import anthropic
client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))

def generate_with_ai(topic):
    message = client.messages.create(
        model='claude-opus-4-6',  # 最强大的 Claude 模型
        max_tokens=8192,
        messages=[
            {'role': 'user', 'content': f'写一篇关于{topic}的详细技术文档'}
        ]
    )
    return message.content[0].text
```

## 批量上传示例

### 场景：整理本地笔记并上传

```bash
#!/bin/bash

# 批量上传所有笔记
for file in ~/Documents/notes/*.md; do
  npx docs-share upload "$file"
  sleep 0.5  # 避免频繁请求
done

echo "所有笔记已上传！"
```

### 场景：定时同步

```bash
#!/bin/bash

# 添加到 crontab
# 每小时同步一次新笔记

# 0 * * * * /path/to/sync-notes.sh

cd ~/Documents/notes

# 找出最近1小时修改的文件
find . -name "*.md" -mmin -60 | while read file; do
  npx docs-share upload "$file"
done
```

## Webhook 示例

### GitHub Actions 自动部署

创建 `.github/workflows/deploy-docs.yml`:

```yaml
name: Deploy Docs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**/*.md'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Upload changed docs
        env:
          DOCS_SERVER: ${{ secrets.DOCS_SERVER }}
          DOCS_API_KEY: ${{ secrets.DOCS_API_KEY }}
        run: |
          # 创建配置
          echo "{\"server\":\"$DOCS_SERVER\",\"apiKey\":\"$DOCS_API_KEY\"}" > .docsrc.json

          # 上传所有文档
          for file in docs/*.md; do
            npx docs-share upload "$file"
          done
```

### GitLab CI 自动部署

创建 `.gitlab-ci.yml`:

```yaml
deploy-docs:
  image: node:18
  only:
    changes:
      - docs/**/*.md
  script:
    - echo "{\"server\":\"$DOCS_SERVER\",\"apiKey\":\"$DOCS_API_KEY\"}" > .docsrc.json
    - for file in docs/*.md; do npx docs-share upload "$file"; done
```

## API 调用示例

### cURL

```bash
# 上传文档
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "my-doc.md",
    "content": "# My Document\n\nContent here..."
  }'

# 列出文档
curl http://localhost:3457/api/docs | jq

# 删除文档
curl -X DELETE http://localhost:3457/api/docs/my-doc.md \
  -H "Authorization: Bearer your-api-key"
```

### JavaScript (Fetch)

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

// 使用
await uploadDoc('test.md', '# Test\n\nHello World!');
```

### Python (Requests)

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

# 使用
result = upload_doc('test.md', '# Test\n\nHello World!')
print(result)
```

## 高级用例

### 监听文件变化自动上传

使用 `chokidar-cli` 监听文件变化：

```bash
# 安装
npm install -g chokidar-cli

# 监听 docs 目录，文件变化时自动上传
chokidar "docs/**/*.md" -c "npx docs-share upload {path}"
```

### 从其他系统导入

```bash
#!/bin/bash

# 从 Notion 导出后批量上传
# 假设导出到 notion-export/ 目录

find notion-export -name "*.md" | while read file; do
  # 清理文件名（移除 Notion ID）
  filename=$(basename "$file" | sed 's/ [a-f0-9]\{32\}//g')

  # 上传
  npx docs-share upload "$file"
done
```

## 故障排查

### 测试配置

```bash
# 测试服务器连接
curl http://localhost:3457/api/docs

# 测试认证
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer $(cat .docsrc.json | jq -r '.apiKey')" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.md","content":"test"}'
```

### Debug 模式

```bash
# Node.js
DEBUG=* node examples/ai-integration.js

# Python
python -v examples/ai-integration.py
```

## 贡献示例

欢迎提交更多示例！提交 PR 到 GitHub 仓库。

---

💡 **提示**：所有示例代码都可以根据你的需求修改和定制！
