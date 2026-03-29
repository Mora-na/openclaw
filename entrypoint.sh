#!/bin/bash
set -e

has_max_old_space_size() {
  case " ${NODE_OPTIONS:-} " in
    *" --max-old-space-size="*|*" --max-old-space-size "*|*" --max_old_space_size="*|*" --max_old_space_size "*)
      return 0
      ;;
  esac

  return 1
}

read_file_trimmed() {
  local file_path="$1"

  if [ ! -r "$file_path" ]; then
    return 1
  fi

  tr -d '[:space:]' < "$file_path"
}

get_host_memory_bytes() {
  awk '/MemTotal:/ { printf "%.0f\n", $2 * 1024; exit }' /proc/meminfo 2>/dev/null
}

get_cgroup_memory_limit_bytes() {
  local value

  for file_path in \
    /sys/fs/cgroup/memory.max \
    /sys/fs/cgroup/memory/memory.limit_in_bytes \
    /sys/fs/cgroup/memory.limit_in_bytes
  do
    value=$(read_file_trimmed "$file_path") || continue

    case "$value" in
      ""|max)
        continue
        ;;
    esac

    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
      echo "$value"
      return 0
    fi
  done

  return 1
}

calculate_node_old_space_mb() {
  local total_mb="$1"
  local reserve_mb
  local target_mb
  local ratio_target_mb
  local reserve_target_mb

  if [ "$total_mb" -lt 512 ]; then
    target_mb=$(( total_mb * 60 / 100 ))
    if [ "$target_mb" -lt 128 ]; then
      target_mb=128
    fi
    if [ "$target_mb" -ge "$total_mb" ]; then
      target_mb=$(( total_mb - 64 ))
    fi
    if [ "$target_mb" -lt 128 ]; then
      target_mb=128
    fi
    echo "$target_mb"
    return 0
  fi

  if [ "$total_mb" -ge 2048 ]; then
    reserve_mb=512
  elif [ "$total_mb" -ge 1024 ]; then
    reserve_mb=384
  else
    reserve_mb=256
  fi

  ratio_target_mb=$(( total_mb * 70 / 100 ))
  reserve_target_mb=$(( total_mb - reserve_mb ))
  target_mb="$ratio_target_mb"

  if [ "$reserve_target_mb" -lt "$target_mb" ]; then
    target_mb="$reserve_target_mb"
  fi

  if [ "$target_mb" -lt 256 ]; then
    target_mb=256
  fi

  if [ "$target_mb" -ge "$total_mb" ]; then
    target_mb=$(( total_mb - 64 ))
  fi

  echo "$target_mb"
}

configure_node_memory_limit() {
  local host_memory_bytes
  local cgroup_memory_bytes
  local effective_memory_bytes
  local effective_memory_mb
  local node_old_space_mb

  if has_max_old_space_size; then
    echo "Detected existing --max-old-space-size in NODE_OPTIONS, skipping auto configuration."
    return 0
  fi

  if [ -n "${OPENCLAW_NODE_MAX_OLD_SPACE_SIZE:-}" ]; then
    export NODE_OPTIONS="--max-old-space-size=${OPENCLAW_NODE_MAX_OLD_SPACE_SIZE}${NODE_OPTIONS:+ ${NODE_OPTIONS}}"
    echo "Using OPENCLAW_NODE_MAX_OLD_SPACE_SIZE=${OPENCLAW_NODE_MAX_OLD_SPACE_SIZE}MB"
    return 0
  fi

  host_memory_bytes=$(get_host_memory_bytes || true)
  cgroup_memory_bytes=$(get_cgroup_memory_limit_bytes || true)

  if [[ "${host_memory_bytes:-}" =~ ^[0-9]+$ ]] && [[ "${cgroup_memory_bytes:-}" =~ ^[0-9]+$ ]]; then
    if [ "$cgroup_memory_bytes" -lt "$host_memory_bytes" ]; then
      effective_memory_bytes="$cgroup_memory_bytes"
    else
      effective_memory_bytes="$host_memory_bytes"
    fi
  elif [[ "${cgroup_memory_bytes:-}" =~ ^[0-9]+$ ]]; then
    effective_memory_bytes="$cgroup_memory_bytes"
  elif [[ "${host_memory_bytes:-}" =~ ^[0-9]+$ ]]; then
    effective_memory_bytes="$host_memory_bytes"
  else
    echo "Unable to detect available memory, leaving NODE_OPTIONS unchanged."
    return 0
  fi

  effective_memory_mb=$(( effective_memory_bytes / 1024 / 1024 ))
  node_old_space_mb=$(calculate_node_old_space_mb "$effective_memory_mb")

  export NODE_OPTIONS="--max-old-space-size=${node_old_space_mb}${NODE_OPTIONS:+ ${NODE_OPTIONS}}"
  echo "Detected memory limit: ${effective_memory_mb}MB, configured Node old space: ${node_old_space_mb}MB"
}

# 默认 CONFIG_PATH
CONFIG_PATH="${OPENCLAW_HOME:-$HOME}"

# CONFIG_DIR 优先 OPENCLAW_CONFIG_PATH，否则使用 CONFIG_PATH/.openclaw/openclaw.json 的目录
CONFIG_DIR="${OPENCLAW_CONFIG_PATH:-$CONFIG_PATH/.openclaw/openclaw.json}"
CONFIG_DIR=$(dirname "$CONFIG_DIR")  # 保证 CONFIG_DIR 是目录
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

mkdir -p "$CONFIG_DIR"

configure_node_memory_limit

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
echo "NODE_OPTIONS=${NODE_OPTIONS}"
echo "Starting OpenClaw gateway..."
exec openclaw gateway run
