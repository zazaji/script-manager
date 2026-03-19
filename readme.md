
<div align="center">

<img src="https://raw.githubusercontent.com/your-username/ScriptManager/main/Assets.xcassets/AppIcon.appiconset/icon_256pt.png" width="128" alt="ScriptManager Logo">

# 🚀 ScriptManager

**Turn your CLI scripts into beautiful native macOS apps instantly. Support bash , python, ruby, js  scripts.**  
*No UI code required. Just add comments.*

[![macOS](https://img.shields.io/badge/macOS-13.0+-000000.svg?style=for-the-badge&logo=apple&logoColor=white)](#)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-blue.svg?style=for-the-badge&logo=swift&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge)](#)

[English](./README.md) | [简体中文](./README_zh.md)

</div>

---

## 💡 The "Aha!" Moment

Stop writing boilerplate UI code or building complex web dashboards just to share your scripts with your team. With **ScriptManager**, you just write your script, add a few magic comments, and boom—you get a native macOS GUI.

**Before (Your Script):**
```python
#!/usr/bin/env python3
# @Name: Database Exporter
# @Desc: Export production database to local CSV securely.
# @Param: target_db | choice | true | users | Select Database | users, orders, logs
# @Param: output_dir | path | true | | Export Destination
# @Param: verbose | bool | false | false | Enable verbose logging

import sys
# ... your awesome logic here ...
```

**After (ScriptManager Auto-Generated UI):**

> 📸 *[Place a high-quality GIF here showing the script code on the right and the auto-generated UI with dropdowns, file pickers, and toggles on the left]*

---

## ✨ Features

- 🪄 **Auto UI Generation**: Parses `@Param` comments to automatically generate TextFields, Dropdowns, File Pickers, and Toggles.
- 💻 **Interactive PTY Terminal**: Built-in console with full Pseudo-Terminal (PTY) support. It handles interactive commands like `mysql`, `ssh`, or `npm init` flawlessly.
- 📁 **Workspace Management**: Organize your scripts in folders. Real-time file monitoring keeps your UI in sync with your file system.
- 📝 **Built-in Code Editor**: Edit scripts on the fly with syntax highlighting (Python, Bash, Node.js, Ruby), auto-indentation, and standard shortcuts (`Cmd+S`, `Cmd+/`, `Cmd+F`).
- 🌍 **Environment Variables**: Inject custom environment variables per script without messing up your global `~/.zshrc`.
- 🔒 **Privacy First & Native**: 100% native SwiftUI. Runs locally. No electron bloat, no cloud sync, your scripts stay on your machine.

---

## 📦 Installation

### Option 1: Homebrew (Recommended)
```bash
brew install --cask scriptmanager
```

### Option 2: Direct Download
Download the latest `.dmg` file from the [Releases](https://github.com/your-username/ScriptManager/releases) page and drag it to your Applications folder.

### Option 3: Build from Source
```bash
git clone https://github.com/your-username/ScriptManager.git
cd ScriptManager
open ScriptManager.xcodeproj
# Hit Cmd + R in Xcode to build and run
```

---

## 🚀 Quick Start

1. Open **ScriptManager** and click **"Open Workspace"** to select a folder.
2. Click the **"+"** button to create a new script (e.g., `hello.py`).
3. Paste the following code into the built-in editor:

```python
#!/usr/bin/env python3
# @Name: Hello World Generator
# @Param: name | string | true | Developer | Who to greet?
# @Param: enthusiastic | bool | false | true | Add exclamation marks?

import sys

name = sys.argv[1] if len(sys.argv) > 1 else "World"
enthusiastic = "--enthusiastic" in sys.argv

greeting = f"Hello, {name}"
if enthusiastic:
    greeting += "!!!"

print(greeting)
```
4. Press `Cmd + S` to save.
5. Switch to the **Config** tab, fill in the generated form, and click **Run**!

---

## 📖 Syntax Guide

ScriptManager uses a simple contract in your script's header comments to generate the UI.

### Metadata Tags
| Tag | Description | Example |
|-----|-------------|---------|
| `@Name:` | Display name of the script | `# @Name: Deploy Server` |
| `@Desc:` | Short description | `# @Desc: Deploys the app to AWS` |
| `@Author:` | Author name | `# @Author: John Doe` |
| `@Version:`| Script version | `# @Version: 1.0.0` |
| `@Example:`| Usage example | `# @Example: Run with verbose mode` |

### Parameter Tag (`@Param`)
The `@Param` tag is the core of ScriptManager. It follows this strict format separated by `|`:

```text
@Param: name | type | required | default_value | description | options (for choice)
```

#### Supported Types:
1. **`string`**: Generates a standard text input field.
   ```bash
   # @Param: api_key | string | true | | Enter your API Key
   ```
2. **`bool`**: Generates a toggle switch. Passes `--name` to the script if true.
   ```bash
   # @Param: dry_run | bool | false | true | Run without making changes
   ```
3. **`path`**: Generates a text field with a "Select File/Folder" button.
   ```bash
   # @Param: input_csv | path | true | | Select the data file
   ```
4. **`choice`**: Generates a dropdown menu. Requires the 6th parameter (comma-separated options).
   ```bash
   # @Param: env | choice | true | dev | Target Environment | dev, staging, prod
   ```

---

## 🛠️ Architecture Highlights

For developers interested in the codebase:
- **Multi-Probe FDA Detection**: Advanced Full Disk Access detection bypassing macOS sandbox caching bugs.
- **PTY Allocation**: Uses `posix_openpt` and `grantpt` to allocate real pseudo-terminals, capturing ANSI color codes and supporting interactive stdin.
- **Security-Scoped Bookmarks**: Persists workspace access across app restarts without violating App Sandbox rules.
- **Stream Parsing**: Asynchronously reads only the first few kilobytes of files to extract metadata, ensuring zero lag even with massive log files.

---

## 🤝 Contributing

We love contributions! If you'd like to help make ScriptManager even better, please check out our [Contributing Guide](CONTRIBUTING.md).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
<div align="center">
Made with ❤️ by [Your Name/Organization]. 
If you find this project helpful, please consider giving it a ⭐️!
</div>
```

---

### 第三部分：如何让这个 README 发挥最大效用（给您的建议）

1. **制作高质量的 GIF（最重要的一步）**：
   - 10k Star 的项目，第一眼视觉冲击力决定了 80% 的转化率。
   - 建议使用[Cleanshot X](https://cleanshot.com/) 或 [Screen Studio](https://www.screen.studio/) 录制一个 10-15 秒的演示 GIF。
   - **GIF 内容设计**：左边放一个空白的表单，右边在代码编辑器里敲入 `# @Param: env | choice | true | dev | Env | dev, prod`，敲完按下 `Cmd+S`，左边瞬间弹出一个精美的下拉框。这个画面极具极客美感，能瞬间抓住开发者的心。
2. **替换占位符**：
   - 将 `your-username` 替换为您的 GitHub 用户名。
   - 将 Logo 路径替换为真实的图床路径。
3. **多渠道分发**：
   - 带着这个 README 和 GIF，去 **Hacker News (Show HN)**、**Reddit (r/macapps, r/programming, r/swift)**、**Product Hunt** 以及 **V2EX** 发帖。
   - 标题示例："*Show HN: I built a native macOS app that turns any bash/python script into a GUI tool instantly using comments*"。这种标题在 HN 上极易爆火。