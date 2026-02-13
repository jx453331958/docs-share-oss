FROM node:24-alpine

LABEL org.opencontainers.image.source="https://github.com/jx453331958/docs-share"
LABEL org.opencontainers.image.description="零配置 Markdown 文档站"

WORKDIR /app

COPY package.json server.mjs ./
COPY docs ./docs

# docs 目录可以挂载用户自己的文档覆盖
VOLUME /app/docs

# 注意：端口通过环境变量 PORT 配置，默认 3457
# 不硬编码 EXPOSE，由 docker-compose.yml 控制端口映射

CMD ["node", "server.mjs"]
