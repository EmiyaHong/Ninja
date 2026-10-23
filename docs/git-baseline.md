# 本地 Git 基线（2026-10-23）

## 范围与追踪规则

本轮按授权建立本地 main 分支，不设置或发布远程，不修改玩法、美术、参数或刀光。基线命名标签为 `baseline-2026-10-23`；确切提交号在后续记录段给出。提交使用现有 Git 配置身份，未伪造或修改身份。

纳入游戏项目、场景、脚本、着色器、参数、测试、Godot 资源导入配置及 UID；插件源码与 LICENSE/ATTRIBUTIONS 一并保留，因为项目启用该插件和运行时自动加载。保留 PNG 原稿、历史草图、运行分件、枢轴 JSON、素材清单、提示词、处理脚本及截图文档，维持现有目录，不移动源图。当前暂存审阅为 682 文件约 61.19 MiB（加入本说明前），最大单文件约 4.24 MiB，无需本地基线引入 LFS。

忽略 `.godot` 缓存、`.mcp-tools` 工具安装及依赖、node_modules、Python缓存、压缩安装包、日志、临时文件、构建产物、本机 `.mcp.json`、MCP 会话令牌及实例目录、环境文件/私钥和 `.workbuddy` 本机工作记录。`.import` 是源文件导入设置，纳入版本控制；实际导入缓存不纳入。未删除上述本地文件。

主聊天正在写的 `docs/design-journal.md`、`docs/demo-roadmap.md`、`docs/visual-target-art-direction.md`、`assets/art/concepts/` 本次先不暂存，等待完成通知后另行提交；这些路径没有被忽略。基线允许有这些未跟踪/待提交文件，不应据此清理工作目录。

## 本次验证

使用 Godot 4.7.2 console 独立 headless 进程重新运行，而非复用交接结果：

- 战斗：101 项，0 失败。
- A/B 弹反：41 项，0 失败。
- 几何熊：89 项，0 失败。
- 主场景 `scenes/battle.tscn` 启动 60 帧退出，进程成功，日志无脚本错误。
- 刀光：16 项，3 失败。断言为静止轨迹过期、暂停后旧轨迹不复现、松开后轨迹过期。保留原有实现，未为通过测试修改参数或代码。因此本基线可启动，不能称所有测试通过；headless 也未验证 GPU 刀光效果或真人手感。

验证日志在忽略目录 `.mcp-tools/git-baseline-*.log`。编辑器 MCP 连接尝试不稳定，故最终采用独立进程。暂存文本已检查常见私钥、AWS/GitHub/OpenAI token 格式，未发现匹配；属于启发式检查，非完整秘密审计。暂存清单无本机配置/令牌/缓存目录。`git diff --cached --check` 提示原有插件 Markdown 换行空格和三个文件末尾空行；未为格式提示改动第三方和既有文件。

## 查看和恢复

在项目目录运行：

```powershell
git status --short
git log --oneline --decorate -5
git show --stat baseline-2026-10-23
git diff baseline-2026-10-23 -- scripts scenes data shaders
```

安全查看旧版可导出到另一个目录：`git archive --format=zip --output=../Ninja-baseline-2026-10-23.zip baseline-2026-10-23`，解压后用 Godot 4.7.2 导入 project.godot，首次重新生成缓存。确认当前修改已备份后，才针对明确文件使用 `git restore --source baseline-2026-10-23 -- 路径`，这会覆盖该文件当前内容。不要使用 reset --hard 或 clean 清理尚未提交的视觉目标资料。

本地 Git 提供历史版本，不替代异盘备份；没有创建远程仓库或推送。
