# Claude Code Notifier

为 [Claude Code](https://code.claude.com) 打造的 Windows 桌面 Toast 通知工具，支持**点击通知即跳转**到 Claude 终端窗口。

当 Claude 完成任务或需要你确认操作时，桌面右下角会弹出原生 Windows Toast 通知。**点击通知**即可立即将 Claude Code 终端窗口切到前台，全程无命令行闪窗。

## 功能特性

- **零依赖** — 纯 PowerShell 脚本，无需 npm / Python / 第三方模块
- **点击跳转** — 点击通知直接聚焦 Claude Code 终端窗口，不会跳到浏览器
- **无闪窗** — 通过 VBS 桥接 + 自定义协议，激活过程不会闪现命令行窗口
- **三种触发** — 覆盖 `Stop`（任务完成）、`PermissionRequest`（需要确认）、`Notification`（系统消息）
- **智能跳过** — Claude 终端已在前台时不弹通知，避免干扰
- **去重防骚扰** — 每次暂停仅弹一条通知，不会重复弹出

## 快速开始

```powershell
# 1. 克隆或下载本仓库
git clone https://github.com/prism1201/claude-code-notifier.git
cd claude-code-notifier

# 2. 运行安装脚本（注册协议 + 配置 hooks）
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

安装完成。之后 Claude Code 完成任务或需要确认时，就会弹出通知。点击通知即可跳回 Claude 窗口。

## 工作原理

```
Claude Code hook 触发
  → notify.ps1 弹出 Windows Toast（携带 claude-focus:// 协议）
    → 你点击通知
      → wscript.exe 静默运行 focus-claude.vbs
        → focus-claude.ps1 查找并激活 Claude 终端窗口
```

## 文件说明

| 文件 | 作用 |
|------|------|
| `setup.ps1` | 一键安装：注册 claude-focus:// 协议 + 配置 Claude Code hooks |
| `notify.ps1` | 发送 Windows Toast 通知（含前台检测、去重、开关判断） |
| `focus-claude.ps1` | 查找并聚焦 Claude Code 终端窗口 |
| `toggle.ps1` | 命令行开关通知 |
| `toggle-notifier.vbs` | VBS 桥接脚本，桌面快捷方式通过它静默调用 toggle.ps1 |

## 开关通知

桌面双击 `Claude通知开关` 快捷方式即可切换，右下角弹出 Toast 提示当前状态。

也可以用命令行：

```powershell
powershell -File .\toggle.ps1   # 运行一次关闭，再运行开启
```

## 卸载

```powershell
# 删除协议注册
Remove-Item -Path "HKCU:\SOFTWARE\Classes\claude-focus" -Recurse -Force

# 在 ~/.claude/settings.json 中删除 hooks 相关配置（手动编辑即可）
```

## 运行环境

- Windows 10 / 11
- PowerShell 5.1 或更高版本
- 已安装 [Claude Code](https://code.claude.com)

## License

MIT
