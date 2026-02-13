FROM node:22-alpine

LABEL org.opencontainers.image.source="https://github.com/jx453331958/docs-share"
LABEL org.opencontainers.image.description="零配置 Markdown 文档站"

WORKDIR /app

COPY package.json server.mjs ./
COPY docs/index.html ./docs/index.html

# docs 目录挂载用户自己的文档
VOLUME /app/docs

EXPOSE 3457

CMD ["node", "server.mjs"]
