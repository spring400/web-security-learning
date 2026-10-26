# 环境清单（env-checklist）

> W1 产出物 ｜ 首次检查：2026-10-21 ｜ 最近更新：2026-10-21 晚

## 主机信息

| 项 | 值 |
|---|---|
| 操作系统 | Windows 11（NT 10.0.26200） |
| 系统盘可用空间 | 待填（目标 ≥ 15GB） |
| 物理内存 | 待填（目标 ≥ 8GB） |
| 虚拟化（BIOS/VT-x） | 待确认：任务管理器 → 性能 → CPU → 「虚拟化：已启用」 |

> 注：检查在 DSH 沙箱内执行，WMI 查询被拒绝，内存/磁盘需手动补。

## 工具清单

| 工具 | 用途 | 状态 | 版本 | 备注 |
|---|---|---|---|---|
| Git | 版本控制 | ✅ 已安装 | 2.55.0.windows.5 | 新开终端后 `git --version` 可用 |
| Docker Desktop | 跑靶场容器 | ✅ 已安装 | 29.9.1 | 引擎运行状态待确认 |
| WSL2 | Linux 子系统 | ✅ 已安装 | 2 | `docker-desktop`、`Ubuntu-22.04` 已注册 |
| Ubuntu 22.04 | Linux 练习环境 | ✅ 已安装 | 2 | 首次启动需设 UNIX 用户名 |
| VS Code | 编辑器 | ✅ 已装 | 1.141.2 | 扩展见下 |
| Python | 脚本 / 后续工具开发 | ✅ 已装 | 3.12.12 | |
| Node.js | 非必需（Juice Shop 用容器跑） | ❌ 未安装 | — | 可忽略 |
| Burp Suite Community | 抓包改包 | ⬜ 未装 | — | W27 前装即可 |
| GitHub 账号 | 作品集 / 笔记 | ⬜ 待确认 | — | W1 内注册 |

## VS Code 扩展

| 扩展 | 用途 | 状态 |
|---|---|---|
| Python (`ms-python.python`) | Python 语言支持 | ✅ 已装 |
| Chinese 语言包 | 界面汉化 | ✅ 已装 |
| Even Better TOML (`tamasfe.even-better-toml`) | TOML 语法 | ✅ 已装 |
| Markdown All in One (`yzhang.markdown-all-in-one`) | Markdown 写作 | ✅ 已装 |

## 执行策略问题（已知，用 Bypass 绕过）

- 初始状态：ExecutionPolicy 全部 `Undefined` → 默认 `Restricted`，报“在此系统上禁止运行脚本”。
- 设置 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` 后：仍报“未对文件进行数字签名”；已确认文件没有 Zone.Identifier（MOTW），`Unrestricted` 反而报 `AuthorizationManager check failed`。判断为系统层脚本强制（安全软件 / WDAC 类），**不再折腾系统策略**。
- 已验证可用：`-ExecutionPolicy Bypass`。
  - 靶场统一入口：`.\lab.cmd <动作>`（内部即 `powershell -NoProfile -ExecutionPolicy Bypass -File lab.ps1 %*`）
  - 其他脚本：`powershell -NoProfile -ExecutionPolicy Bypass -File script.ps1`

## 待办（按顺序）

1. [x] 安装 Git（2.55.0，已装于 `C:\Program Files\Git`）
2. [x] Docker Desktop 已运行（Engine running）
3. [x] `wsl -l -v` 显示 Ubuntu-22.04，VERSION=2
4. [ ] `docker run --rm hello-world`（未单独验证，开机 30 秒可补）
5. [x] `.\lab.cmd` 可用，DVWA 容器正常
6. [x] DVWA 已启动，完成 Create / Reset Database
7. [ ] GitHub 注册 + 第一个仓库

## W1 验收清单

- [ ] `git --version` 有输出
- [ ] `docker --version` 有输出
- [ ] `docker compose version` 有输出
- [ ] `wsl -l -v` 显示 `Ubuntu-22.04  Running  2`
- [ ] `docker run --rm hello-world` 打印 `Hello from Docker!`
- [ ] GitHub 账号注册完成，建好第一个仓库
- [ ] 能在 WSL 里不靠鼠标用 `pwd/ls/cd/cat/grep/find` 找到任意文件

## 记录

- 2026-10-21 下午：首次自检。端口 8081/3000/8082/8083 空闲；Docker、Git、WSL 发行版缺失。
- 2026-10-21 晚：重启后复查。WSL2 + Ubuntu-22.04 已注册（Version 2），Docker Desktop 29.9.1 已装，Git 仍缺；ExecutionPolicy 全为 Undefined，脚本被拦。新增 `lab/lab.cmd` 作为免策略入口。
- 2026-10-21 深夜：Git 2.55.0 装好；DVWA 启动成功（http://127.0.0.1:8081 返回 200）。Docker Hub 直连超时，用 `docker.1ms.run` 前缀手动拉取 + 本地 tag 解决；`daemon.json` 里的 registry-mirrors 未被引擎加载（`docker info` 显示 `[]`），待 Docker Desktop GUI 里 Apply & restart 后再确认。
- 2026-10-21 收尾：镜像加速已在 Docker Desktop GUI 中修复并生效；DVWA 登录 + 数据库初始化完成。W1 环境部分达标，剩 GitHub 账号 / 首个仓库与一条 hello-world 冒烟验证。
