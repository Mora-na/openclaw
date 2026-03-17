#!/bin/bash
set -e

# 默认 CONFIG_PATH
CONFIG_PATH="${OPENCLAW_HOME:-$HOME}"

# CONFIG_DIR 优先 OPENCLAW_CONFIG_PATH，否则使用 CONFIG_PATH/.openclaw/openclaw.json 的目录
CONFIG_DIR="${OPENCLAW_CONFIG_PATH:-$CONFIG_PATH/.openclaw/openclaw.json}"
CONFIG_DIR=$(dirname "$CONFIG_DIR")  # 保证 CONFIG_DIR 是目录
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "First run: initializing OpenClaw..."
  openclaw onboard \
    --non-interactive \
    --accept-risk \
    --mode local \
    --auth-choice openai \
    --gateway-bind lan \
    --skip-skills \
    --skip-health \
    --json
else
  echo "OpenClaw already initialized."
fi

echo "-----------------------------------------------------------------------------------------"
echo "Common commands are as follows："
echo "1、openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:xxxx","http://127.0.0.1:xxxx","your_public_domain"]' # 更新跨域设置"
echo "2、openclaw devices list # 展示设备列表"
echo "3、openclaw devices approve your_request_id # 授权设备连接"
echo "4、openclaw onboard --auth-choice openai-codex # 完整的首次引导流程：包含 OAuth 登录 + 生成/更新基础配置"
echo "5、openclaw models auth login --provider openai-codex 只做模型提供方的 OAuth 登录/刷新"
echo "-----------------------------------------------------------------------------------------"
echo "Starting OpenClaw gateway..."
exec openclaw gateway