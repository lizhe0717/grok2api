# --- Builder ---
FROM python:3.13-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_PROJECT_ENVIRONMENT=/opt/venv

ENV PATH="$UV_PROJECT_ENVIRONMENT/bin:$PATH"

RUN apk add --no-cache \
    ca-certificates \
    build-base \
    linux-headers \
    libffi-dev \
    openssl-dev \
    curl-dev \
    cargo \
    rust

WORKDIR /app

RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-dev --no-install-project \
    && find /opt/venv -type d \( -name "__pycache__" -o -name "tests" -o -name "test" -o -name "testing" \) -prune -exec rm -rf {} + \
    && find /opt/venv -type f -name "*.pyc" -delete \
    && find /opt/venv -type f -name "*.so" -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && rm -rf /root/.cache /tmp/uv-cache

# --- Runtime ---
FROM python:3.13-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    VIRTUAL_ENV=/opt/venv \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8000 \
    SERVER_WORKERS=1

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    libffi \
    openssl \
    libgcc \
    libstdc++

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

# 一次性复制所有文件并给脚本权限
COPY . .
RUN chmod +x /app/scripts/*.sh

EXPOSE 8000

# 直接启动服务，绕过 entrypoint.sh
CMD ["granian", "--interface", "asgi", "--host", "0.0.0.0", "--port", "8000", "main:app"]
