# かな帖

基于 Vue 3 和 Vite 的五十音练习站点。

## 本地开发

```bash
pnpm install
pnpm dev
```

## 测试与构建

```bash
pnpm test
pnpm build
```

## 部署

生产地址：<https://kana.kevinlau.cn>

### GitHub Actions 自动发布

代码 push 或合入 `main` 后，`Production Deploy` 工作流会自动执行：

1. 使用固定版本的 Node.js 和 pnpm 安装依赖。
2. 运行 Vitest 和 Vite 生产构建。
3. 通过 SSH/rsync 上传到腾讯云服务器。
4. 将版本目录原子切换为线上 `current`，重载 Nginx。
5. 检查 `https://kana.kevinlau.cn/`，并在 Actions 页面写入发布摘要。

也可以在 GitHub 仓库的 Actions 页面选择 `Production Deploy`，通过 `Run workflow` 手动重跑。自动发布使用固定并发锁，同一时间只会执行一个生产部署。

在仓库 `Settings → Secrets and variables → Actions` 中配置：

| 类型 | 名称 | 内容 |
| --- | --- | --- |
| Repository Secret | `SERVER_HOST` | 服务器 IP 或域名 |
| Repository Secret | `SERVER_USERNAME` | SSH 部署用户名 |
| Repository Secret | `SERVER_SSH_KEY` | 本仓库专用 SSH 私钥的完整内容 |
| Repository Secret | `SERVER_KNOWN_HOSTS` | 经过核验的服务器 SSH host key |
| Repository Variable | `SERVER_PORT` | SSH 端口，未配置时工作流使用 `22` |

建议为本仓库创建独立密钥：

```bash
ssh-keygen -t ed25519 \
  -C "github-actions-kana-note" \
  -f ~/.ssh/kana_note_github_actions
```

将 `~/.ssh/kana_note_github_actions.pub` 追加到服务器部署用户的 `~/.ssh/authorized_keys`，将私钥 `~/.ssh/kana_note_github_actions` 的完整内容写入 `SERVER_SSH_KEY`。从可信终端核对服务器指纹后，将对应的 known_hosts 行写入 `SERVER_KNOWN_HOSTS`；不要在工作流中通过未经核验的 `ssh-keyscan` 动态信任服务器。

部署用户需要写入 `/www/wwwroot/kana.kevinlau.cn`，并能执行远端脚本中的 `chown`、`nginx -t` 和 `nginx -s reload`。应只授予这些发布所需权限，不要配置无范围限制的 sudo。

### 本地应急发布

本地部署命令会先执行测试和生产构建，再通过 SSH 将静态文件原子发布到服务器，并检查线上首页：

```bash
pnpm run deploy
```

默认使用 SSH Host `tencent-cloud`。如需覆盖，可在执行时传入：

```bash
DEPLOY_SSH_TARGET=your-ssh-host pnpm run deploy
```

如 SSH 使用非默认端口：

```bash
DEPLOY_SSH_TARGET=your-ssh-host SERVER_PORT=2222 pnpm run deploy
```

服务器保留最近 5 个发布版本，每个版本的 `.git-commit` 记录对应的完整 commit SHA。部署凭据由本机 SSH 配置或 GitHub Repository Secrets 管理，不写入仓库。

### 故障排查

按以下顺序检查 Actions 日志：

1. `pnpm install --frozen-lockfile`、测试或构建是否失败。
2. `SERVER_HOST`、`SERVER_USERNAME`、`SERVER_PORT` 是否正确。
3. `SERVER_SSH_KEY` 是否为完整私钥，公钥是否已加入部署用户的 `authorized_keys`。
4. `SERVER_KNOWN_HOSTS` 是否与当前服务器和端口匹配。
5. 部署用户是否有目标目录、`chown` 和 Nginx 操作权限。
6. `nginx -t` 是否通过，以及线上 HTTPS 健康检查是否可访问。

### 人工回滚

SSH 登录服务器后先列出版本，并核对目标版本的 commit：

```bash
cd /www/wwwroot/kana.kevinlau.cn
ls -1dt releases/*
cat releases/<目标版本>/.git-commit
test -f releases/<目标版本>/index.html
```

确认无误后原子切换并检查 Nginx：

```bash
ln -sfn "/www/wwwroot/kana.kevinlau.cn/releases/<目标版本>" current.next
mv -Tf current.next current
chown -h www:www current
nginx -t
nginx -s reload
curl --fail --location --max-time 15 https://kana.kevinlau.cn/ >/dev/null
```
