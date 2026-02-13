#!/usr/bin/env python3

"""
AI 集成示例 (Python 版本)

演示如何让 AI 生成的内容自动发布到 Docs Share
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path
import requests


def load_config():
    """加载配置"""
    config = {
        'server': os.getenv('DOCS_SERVER', 'http://localhost:3457'),
        'apiKey': os.getenv('DOCS_API_KEY', 'dev-key-change-in-production'),
    }

    if not config['apiKey'] or config['apiKey'] == 'dev-key-change-in-production':
        print('⚠️  Warning: Using default API key. Set DOCS_API_KEY environment variable.')

    return config


def publish_doc(config, filename, content):
    """发布文档到 Docs Share"""
    response = requests.post(
        f"{config['server']}/api/docs",
        headers={
            'Authorization': f"Bearer {config['apiKey']}",
            'Content-Type': 'application/json',
        },
        json={'filename': filename, 'content': content}
    )

    if not response.ok:
        raise Exception(f'发布失败: {response.text}')

    return response.json()


def generate_with_ai(topic):
    """
    模拟 AI 生成内容

    实际使用时，替换为真实的 AI API 调用：
    - OpenAI: openai.ChatCompletion.create()
    - Anthropic: anthropic.messages.create()
    - Google: genai.GenerativeModel()
    """

    timestamp = datetime.now().isoformat()

    return f"""# {topic}

> 本文档由 AI 自动生成于 {timestamp}

## 概述

这是一个关于「{topic}」的技术文档。

## 主要内容

### 1. 背景介绍

在现代软件开发中，{topic} 是一个重要的概念...

### 2. 核心原理

{topic} 的核心原理包括：

- **原理一**: 详细说明...
- **原理二**: 深入分析...
- **原理三**: 实践应用...

### 3. 代码示例

```python
# 示例代码
def example():
    print('这是一个示例')
    return True
```

### 4. 最佳实践

1. 遵循标准规范
2. 注重性能优化
3. 保持代码简洁

### 5. 常见问题

**Q: 如何开始？**

A: 建议从基础概念开始学习...

**Q: 有哪些注意事项？**

A: 注意以下几点...

## 总结

通过本文档，我们了解了 {topic} 的核心概念和应用...

## 参考资源

- 官方文档
- 社区资源
- 最佳实践指南

---

_由 AI 自动生成并发布到 Docs Share_
"""


def main():
    """主程序"""
    print('🤖 AI 集成示例 - Docs Share (Python)\n')

    try:
        # 1. 加载配置
        config = load_config()
        print(f"📝 服务器: {config['server']}\n")

        # 2. AI 生成内容
        topic = sys.argv[1] if len(sys.argv) > 1 else 'Python 异步编程'
        print(f'🎨 AI 生成文档：{topic}')
        content = generate_with_ai(topic)
        print(f'✓ 生成完成 ({len(content)} 字符)\n')

        # 3. 发布到 Docs Share
        filename = f"ai-{topic.replace(' ', '-').lower()}.md"
        print(f'📤 发布文档：{filename}')
        result = publish_doc(config, filename, content)
        print('✓ 发布成功！\n')
        print(json.dumps(result, indent=2, ensure_ascii=False))

        print('\n🎉 完成！访问你的文档站查看新文档。')

    except Exception as error:
        print(f'\n❌ 错误: {error}')
        sys.exit(1)


def print_help():
    """打印帮助信息"""
    print("""
🤖 AI 集成示例 (Python)

用法:
  python ai-integration.py [主题]

环境变量:
  DOCS_SERVER       - 文档服务器地址 (默认: http://localhost:3457)
  DOCS_API_KEY      - API 认证密钥 (必需)
  ANTHROPIC_API_KEY - Anthropic API 密钥 (可选)

示例:
  export DOCS_API_KEY="your-api-key"
  python ai-integration.py "FastAPI 教程"
  python ai-integration.py "机器学习入门"
  python ai-integration.py "数据分析最佳实践"

说明:
  这个脚本演示如何将 AI 生成的内容自动发布到 Docs Share。
  在实际使用中，将 generate_with_ai() 函数替换为真实的 AI API 调用。

集成真实 AI:

  # OpenAI 示例
  import openai
  openai.api_key = 'your-key'

  def generate_with_ai(topic):
      response = openai.ChatCompletion.create(
          model='gpt-4',
          messages=[
              {'role': 'user', 'content': f'写一篇关于{topic}的技术文档'}
          ]
      )
      return response.choices[0].message.content

  # Anthropic Claude 示例（使用最新 Claude 4.6）
  import anthropic
  client = anthropic.Anthropic(api_key='your-key')

  def generate_with_ai(topic):
      message = client.messages.create(
          model='claude-opus-4-6',  # 最新最强大的模型
          max_tokens=8192,
          messages=[
              {'role': 'user', 'content': f'写一篇关于{topic}的技术文档'}
          ]
      )
      return message.content[0].text

  # Google Gemini 示例
  import google.generativeai as genai
  genai.configure(api_key='your-key')

  def generate_with_ai(topic):
      model = genai.GenerativeModel('gemini-pro')
      response = model.generate_content(f'写一篇关于{topic}的技术文档')
      return response.text
    """)


if __name__ == '__main__':
    if '--help' in sys.argv or '-h' in sys.argv:
        print_help()
        sys.exit(0)

    main()
