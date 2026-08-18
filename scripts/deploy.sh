#!/usr/bin/env bash

set -euo pipefail

readonly SITE_HOST="kana.kevinlau.cn"
readonly REMOTE_ROOT="/www/wwwroot/${SITE_HOST}"
readonly SSH_TARGET="${DEPLOY_SSH_TARGET:-tencent-cloud}"
readonly SSH_PORT="${SERVER_PORT:-}"
readonly COMMIT_SHA="${DEPLOY_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || true)}"
readonly SHORT_SHA="${COMMIT_SHA:0:12}"
readonly RELEASE_ID="$(date -u +%Y%m%d%H%M%S)-${SHORT_SHA}"

if [[ ! "${COMMIT_SHA}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "错误：无法取得合法的 Git commit SHA。"
  exit 1
fi

if [[ ! -f "dist/index.html" && "${DEPLOY_SKIP_BUILD:-0}" == "1" ]]; then
  echo "错误：跳过构建时必须存在 dist/index.html。"
  exit 1
fi

for command_name in rsync ssh curl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "错误：缺少命令 ${command_name}。"
    exit 1
  fi
done

if [[ "${DEPLOY_SKIP_BUILD:-0}" != "1" ]]; then
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "错误：缺少命令 pnpm。"
    exit 1
  fi

  echo "运行测试并构建生产版本..."
  pnpm test
  pnpm build
fi

ssh_command=(ssh -o BatchMode=yes -o StrictHostKeyChecking=yes)
rsync_ssh="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"
if [[ -n "${SSH_PORT}" ]]; then
  if [[ ! "${SSH_PORT}" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
    echo "错误：SERVER_PORT 必须是 1 到 65535 的整数。"
    exit 1
  fi
  ssh_command+=(-p "${SSH_PORT}")
  rsync_ssh+=" -p ${SSH_PORT}"
fi

echo "上传 ${SITE_HOST} 发布版本 ${RELEASE_ID}..."
"${ssh_command[@]}" "${SSH_TARGET}" "mkdir -p '${REMOTE_ROOT}/incoming/${RELEASE_ID}'"
rsync -az --delete -e "${rsync_ssh}" dist/ "${SSH_TARGET}:${REMOTE_ROOT}/incoming/${RELEASE_ID}/"
rsync -az -e "${rsync_ssh}" deploy/nginx.conf scripts/deploy-remote.sh "${SSH_TARGET}:${REMOTE_ROOT}/incoming/"

"${ssh_command[@]}" "${SSH_TARGET}" \
  "bash '${REMOTE_ROOT}/incoming/deploy-remote.sh' '${SITE_HOST}' '${REMOTE_ROOT}' '${RELEASE_ID}' '${COMMIT_SHA}'"

echo "检查线上站点..."
curl --fail --silent --show-error --location --max-time 15 \
  --retry 3 --retry-delay 2 --retry-all-errors \
  "https://${SITE_HOST}/" >/dev/null

echo "部署完成：https://${SITE_HOST}"
