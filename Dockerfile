FROM node:22-alpine

LABEL org.opencontainers.image.source="https://github.com/jx453331958/docs-share"
LABEL org.opencontainers.image.description="零配置 Markdown 文档站"

WORKDIR /app

COPY package.json server.mjs ./
COPY docs ./docs

# docs 目录可以挂载用户自己的文档覆盖
VOLUME /app/docs

EXPOSE 3457

CMD ["node", "server.mjs"]
