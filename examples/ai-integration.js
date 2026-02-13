#!/usr/bin/env node

/**
 * AI 集成示例
 *
 * 演示如何让 AI 生成的内容自动发布到 Docs Share
 */

// ── 配置 ──
const CONFIG = {
  server: process.env.DOCS_SERVER || 'http://localhost:3457',
  apiKey: process.env.DOCS_API_KEY || 'dev-key-change-in-production',
};

function loadConfig() {
  if (!CONFIG.apiKey || CONFIG.apiKey === 'dev-key-change-in-production') {
    console.warn('⚠️  Warning: Using default API key. Set DOCS_API_KEY environment variable.');
  }
  return CONFIG;
}

// ── 上传文档到 Docs Share ──
async function publishDoc(config, filename, content) {
  const response = await fetch(`${config.server}/api/docs`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${config.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ filename, content }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`发布失败: ${error}`);
  }

  return response.json();
}

// ── 模拟 AI 生成内容 ──
function generateWithAI(topic) {
  // 这里是模拟，实际使用时替换为真实的 AI API 调用
  // 例如：OpenAI, Anthropic, Gemini 等

  const timestamp = new Date().toISOString();

  return `# ${topic}

> 本文档由 AI 自动生成于 ${timestamp}

## 概述

这是一个关于「${topic}」的技术文档。

## 主要内容

### 1. 背景

在现代软件开发中，${topic} 是一个重要的概念...

### 2. 核心原理

${topic} 的核心原理包括：

- **原理一**: 详细说明...
- **原理二**: 深入分析...
- **原理三**: 实践应用...

### 3. 最佳实践

\`\`\`javascript
// 示例代码
const example = () => {
  console.log('这是一个示例');
};
\`\`\`

### 4. 常见问题

**Q: 如何开始？**

A: 建议从基础概念开始学习...

## 总结

通过本文档，我们了解了 ${topic} 的核心概念和应用...

---

_由 AI 自动生成并发布到 Docs Share_
`;
}

// ── 主程序 ──
async function main() {
  console.log('🤖 AI 集成示例 - Docs Share\n');

  try {
    // 1. 加载配置
    const config = loadConfig();
    console.log(`📝 服务器: ${config.server}\n`);

    // 2. AI 生成内容
    const topic = process.argv[2] || 'JavaScript 异步编程';
    console.log(`🎨 AI 生成文档：${topic}`);
    const content = generateWithAI(topic);
    console.log(`✓ 生成完成 (${content.length} 字符)\n`);

    // 3. 发布到 Docs Share
    const filename = `ai-${topic.replace(/\s+/g, '-').toLowerCase()}.md`;
    console.log(`📤 发布文档：${filename}`);
    const result = await publishDoc(config, filename, content);
    console.log(`✓ 发布成功！\n`);
    console.log(result);

    console.log('\n🎉 完成！访问你的文档站查看新文档。');

  } catch (error) {
    console.error('\n❌ 错误:', error.message);
    process.exit(1);
  }
}

// ── 帮助信息 ──
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
🤖 AI 集成示例

用法:
  node ai-integration.js [主题]

环境变量:
  DOCS_SERVER     - 文档服务器地址 (默认: http://localhost:3457)
  DOCS_API_KEY    - API 认证密钥 (必需)
  ANTHROPIC_API_KEY - Anthropic API 密钥 (可选)

示例:
  export DOCS_API_KEY="your-api-key"
  node ai-integration.js "React Hooks"
  node ai-integration.js "Docker 容器化"
  node ai-integration.js "数据库优化"

说明:
  这个脚本演示如何将 AI 生成的内容自动发布到 Docs Share。
  在实际使用中，将 generateWithAI() 函数替换为真实的 AI API 调用。

集成真实 AI:

  // OpenAI 示例
  import OpenAI from 'openai';
  const openai = new OpenAI({ apiKey: 'your-key' });

  async function generateWithAI(topic) {
    const response = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'user', content: \`写一篇关于\${topic}的技术文档\` }
      ],
    });
    return response.choices[0].message.content;
  }

  // Anthropic Claude 示例（使用最新 Claude 4.6）
  import Anthropic from '@anthropic-ai/sdk';
  const anthropic = new Anthropic({ apiKey: 'your-key' });

  async function generateWithAI(topic) {
    const message = await anthropic.messages.create({
      model: 'claude-opus-4-6',  // 最新最强大的模型
      max_tokens: 8192,
      messages: [
        { role: 'user', content: \`写一篇关于\${topic}的技术文档\` }
      ],
    });
    return message.content[0].text;
  }
  `);
  process.exit(0);
}

main();
