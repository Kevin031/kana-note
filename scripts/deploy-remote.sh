#!/usr/bin/env bash

set -euo pipefail

readonly SITE_HOST="${1:?缺少站点域名}"
readonly REMOTE_ROOT="${2:?缺少部署目录}"
readonly RELEASE_ID="${3:?缺少发布版本}"
readonly INCOMING_PATH="${REMOTE_ROOT}/incoming/${RELEASE_ID}"
readonly RELEASE_PATH="${REMOTE_ROOT}/releases/${RELEASE_ID}"
readonly NGINX_CONFIG="/www/server/panel/vhost/nginx/${SITE_HOST}.conf"
readonly UPLOADED_CONFIG="${REMOTE_ROOT}/incoming/nginx.conf"

if [[ "${REMOTE_ROOT}" != "/www/wwwroot/${SITE_HOST}" || ! "${RELEASE_ID}" =~ ^[0-9]{14}$ ]]; then
  echo "错误：部署参数不合法。"
  exit 1
fi

if [[ ! -f "${INCOMING_PATH}/index.html" || ! -f "${UPLOADED_CONFIG}" ]]; then
  echo "错误：发布文件不完整。"
  exit 1
fi

mkdir -p "${REMOTE_ROOT}/releases"
mv "${INCOMING_PATH}" "${RELEASE_PATH}"
chown -R www:www "${RELEASE_PATH}"

config_created=0
if [[ ! -f "${NGINX_CONFIG}" ]]; then
  install -m 0644 "${UPLOADED_CONFIG}" "${NGINX_CONFIG}"
  config_created=1
fi

if ! nginx -t; then
  if [[ "${config_created}" -eq 1 ]]; then
    rm -f "${NGINX_CONFIG}"
  fi
  rm -rf "${RELEASE_PATH}"
  exit 1
fi

ln -sfn "${RELEASE_PATH}" "${REMOTE_ROOT}/current.next"
mv -Tf "${REMOTE_ROOT}/current.next" "${REMOTE_ROOT}/current"
chown -h www:www "${REMOTE_ROOT}/current"
nginx -s reload

find "${REMOTE_ROOT}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
  | sort -rn \
  | tail -n +6 \
  | cut -d' ' -f2- \
  | xargs -r rm -rf --

rm -f "${REMOTE_ROOT}/incoming/nginx.conf" "${REMOTE_ROOT}/incoming/deploy-remote.sh"
