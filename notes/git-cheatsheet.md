# Git 速查（W2）

## 三个区域

```
工作区（你编辑的文件）
   │ git add
   ▼
暂存区（准备提交的快照）
   │ git commit
   ▼
本地仓库（.git/ 里的历史）
   │ git push
   ▼
远端仓库（GitHub）
```

## 每天都会用的 6 条

| 命令 | 作用 |
|---|---|
| `git status` | 现在哪些文件改了、哪些已暂存 |
| `git diff` | 具体改了哪几行（`q` 退出） |
| `git add <文件>` / `git add -A` | 把改动放进暂存区 |
| `git commit -m "说明"` | 给暂存区拍快照 |
| `git log --oneline --graph` | 看历史 |
| `git push` | 推到 GitHub |

## 第一次配仓库（做过一次就够）

```bash
git init -b main
git remote add origin https://github.com/<用户名>/<仓库>.git
git push -u origin main
```

## 撤销

| 场景 | 命令 |
|---|---|
| 丢弃工作区改动（没 add 过） | `git restore <文件>` |
| 取消暂存（add 错了） | `git restore --staged <文件>` |
| 撤销最近一次提交，改动保留 | `git reset --soft HEAD~1` |
| 修改最近一次提交（消息/漏文件） | `git add <漏的>` → `git commit --amend` |

> 已经 push 的提交不要随便 reset，会坑到别人（现在只有你一个人，问题不大）。

## 分支

```bash
git switch -c feature   # 新建并切换
git switch main         # 切回
git merge feature       # 合并
git branch -d feature   # 删除已合并分支
```

## 提交信息约定（以后写代码也用得上）

| 前缀 | 用途 |
|---|---|
| `feat:` | 新功能/新内容 |
| `fix:` | 修正错误 |
| `notes:` | 学习笔记 |
| `docs:` | 文档 |
| `chore:` | 杂务（初始化、配置） |

例子：`notes: bandit level 2 writeup`
