# Git 协作指南

本项目使用 Git 管理 Godot 游戏项目。所有协作者都应保持提交清晰、分支短小，并通过 Pull Request 合并代码。

## 分支结构

- `main` 是稳定主分支，提交必须能够正常打开和运行项目。
- `feature/<功能名>` 用于开发新功能，例如 `feature/player-movement`。
- `fix/<问题名>` 用于修复缺陷，例如 `fix/exit-dialog`。
- `refactor/<范围>` 用于重构代码或目录结构，例如 `refactor/ui-layout`。
- `docs/<主题>` 用于文档修改，例如 `docs/git-guide`。
- `archive/*` 只用于保存历史分支和整理前的备份，不参与日常开发。

分支名称使用小写英文、数字和短横线，避免使用空格、中文和含义不清的缩写。

## 开始工作

开始新任务前先同步主分支：

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/<功能名>
```

每个任务使用独立分支。不要直接在 `main` 上开发，也不要多人长期共用同一个功能分支。

## 提交规范

一次提交只完成一个完整的小变更。提交信息使用简短、明确的中文或英文动词开头，例如：

```text
feat: 添加玩家移动
fix: 修复退出弹窗无法关闭
refactor: 整理 UI 场景目录
docs: 更新 Git 协作指南
chore: 更新 Godot 配置
```

提交前检查变更内容：

```bash
git status
git diff
git diff --check
```

确认只包含当前任务相关文件后再提交：

```bash
git add <文件或目录>
git commit -m "feat: 添加玩家移动"
```

不要提交 `.godot/`、编辑器个人配置、临时导出文件、密码、密钥或本机路径。提交 Godot 资源时，应一并提交项目实际需要的 `.import` 或 `.uid` 文件。

## 同步与冲突处理

功能开发期间定期同步 `main`。推荐使用 rebase 保持分支历史简洁：

```bash
git fetch origin
git rebase origin/main
```

发生冲突时，先查看冲突文件，手动保留正确内容，然后继续：

```bash
git status
git add <已解决的文件>
git rebase --continue
```

如果确认不应继续本次 rebase，可以安全退出：

```bash
git rebase --abort
```

不要直接覆盖他人的修改。对场景、脚本、输入映射和项目设置发生冲突时，应与相关作者确认最终行为，并在本地运行验证。

## 推送和 Pull Request

首次推送功能分支：

```bash
git push -u origin feature/<功能名>
```

后续推送使用：

```bash
git push
```

创建 Pull Request 前确认：

- 分支已基于最新的 `origin/main`。
- 提交只包含一个功能或问题的相关改动。
- Godot 项目可以正常导入、运行和保存。
- 场景路径、脚本路径、节点路径、输入动作和 Autoload 配置均已检查。
- 没有提交 `.godot/`、个人编辑器配置或敏感信息。
- PR 描述说明了改动内容、验证方式和需要特别关注的地方。

合并优先使用仓库设置的 Pull Request 合并方式。合并完成后删除已完成的远程功能分支，避免分支长期堆积。

## Godot 项目检查

提交前建议在 Godot 编辑器中打开项目并检查：

1. 文件系统面板没有丢失资源或脚本。
2. 主场景能够运行，关键界面和交互正常。
3. 重命名后的 `res://` 路径和节点路径全部更新。
4. 场景实例、信号连接、输入动作和 Autoload 仍然有效。
5. 修改项目设置后，确认改动确实属于当前任务。

如果项目有自动化检查，应在提交和创建 PR 前执行完整检查。

## 文档维护

设计文档与代码同属仓库内容，同样走分支和 PR。

- `README.md` 是唯一的文档索引，新增分册要同时更新“当前状态”和“文档”两张表。
- `docs/` 下每个子系统一篇，文件名用中文主题名（见 `docs/Godot项目命名规则.md`）；改机制时同步改对应分册，不要只改代码。
- 设计未定稿的内容写进 `docs/资源需求.md` 并标优先级，不要在分册里把草案写成定稿。
- 纯文档改动用 `docs:` 前缀和 `docs/<主题>` 分支，PR 描述里列出改动的文档路径。

## 禁止操作

- 不要对共享的 `main` 分支执行 `git push --force`。
- 不要改写已经合并到 `main` 的公共提交历史。
- 不要使用 `git add .` 代替检查变更内容。
- 不要把多个无关功能、格式化修改和资源移动混在一个提交中。
- 不要删除仍被其他协作者使用的远程分支。

确实需要强制推送时，只能对自己独占的功能分支使用 `--force-with-lease`，并在团队沟通后执行：

```bash
git push --force-with-lease origin feature/<功能名>
```

## 常用命令

```bash
# 查看工作区和分支状态
git status
git branch -vv

# 查看提交历史
git log --graph --decorate --oneline --all

# 查看某个文件的修改历史
git log --follow -- <文件路径>

# 暂存当前工作，切换去处理其他任务
git stash push -m "说明暂存原因"
git stash list
git stash pop

# 放弃未提交的单个文件修改，执行前确认文件路径
git restore -- <文件路径>
```

遇到不确定的 Git 操作时，先保留当前分支和工作区状态，再咨询维护者。涉及删除分支、重写历史或批量移动资源时，应先创建可追溯的备份分支。
