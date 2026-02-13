FROM node:24-alpine

LABEL org.opencontainers.image.source="https://github.com/jx453331958/docs-share"
LABEL org.opencontainers.image.description="零配置 Markdown 文档站"

RUN apk add --no-cache git openssh-client \
    && git config --global --add safe.directory '*'

WORKDIR /app

COPY package.json server.mjs ./
COPY public ./public
COPY docs ./docs

# docs 目录可以挂载用户自己的文档覆盖
VOLUME /app/docs

# 容器内部固定使用 3457 端口，外部端口通过 docker-compose.yml 映射
EXPOSE 3457

CMD ["node", "server.mjs"]
