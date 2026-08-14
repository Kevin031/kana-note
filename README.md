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

部署命令会先执行测试和生产构建，再通过 SSH 将静态文件原子发布到腾讯云服务器，并检查线上首页：

```bash
pnpm run deploy
```

默认使用 SSH Host `tencent-cloud`。如需覆盖，可在执行时传入：

```bash
DEPLOY_SSH_TARGET=your-ssh-host pnpm run deploy
```

服务器保留最近 5 个发布版本。部署凭据由本机 SSH 配置管理，不写入仓库。
