#!/usr/bin/env bash

set -euo pipefail

readonly SITE_HOST="kana.kevinlau.cn"
readonly SSH_TARGET="${DEPLOY_SSH_TARGET:-tencent-cloud}"
readonly REMOTE_ROOT="/www/wwwroot/${SITE_HOST}"
readonly RELEASE_ID="$(date -u +%Y%m%d%H%M%S)"

for command_name in pnpm rsync ssh; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "错误：缺少命令 ${command_name}。"
    exit 1
  fi
done

echo "运行测试并构建生产版本..."
pnpm test
pnpm build

echo "上传 ${SITE_HOST} 发布版本 ${RELEASE_ID}..."
ssh "${SSH_TARGET}" "mkdir -p '${REMOTE_ROOT}/incoming/${RELEASE_ID}'"
rsync -az --delete dist/ "${SSH_TARGET}:${REMOTE_ROOT}/incoming/${RELEASE_ID}/"
rsync -az deploy/nginx.conf scripts/deploy-remote.sh "${SSH_TARGET}:${REMOTE_ROOT}/incoming/"

ssh "${SSH_TARGET}" \
  "bash '${REMOTE_ROOT}/incoming/deploy-remote.sh' '${SITE_HOST}' '${REMOTE_ROOT}' '${RELEASE_ID}'"

echo "检查线上站点..."
curl --fail --silent --show-error --retry 3 --retry-delay 2 \
  "https://${SITE_HOST}/" >/dev/null

echo "部署完成：https://${SITE_HOST}"
