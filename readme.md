
# 🚀 ScriptManager

**Turn your CLI scripts into beautiful native macOS GUI apps instantly. Support bash , python, ruby, js  scripts.**  
*No UI code required. Just add magic comments. Built with 100% SwiftUI.*

[![macOS](https://img.shields.io/badge/macOS-13.0+-000000.svg?style=for-the-badge&logo=apple&logoColor=white)](#)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-blue.svg?style=for-the-badge&logo=swift&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge)](#)

[English](./README.md) | [简体中文](./README_zh.md)

</div>

---

## 💡 The "Aha!" Moment

Stop writing boilerplate UI code or building complex web dashboards just to share your scripts with your team. With **ScriptManager**, you just write your script (Bash, Python, Node.js, Ruby), add a few magic comments, and boom—you get a native macOS GUI instantly.

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

> ![](/Users/ou/project/pc_project/ScriptManager/images/scriptmanager2.png)
>
> ![](/Users/ou/project/pc_project/ScriptManager/images/scriptmanager1.png)

---

## ✨ Features

- 🪄 **Auto UI Generation**: Parses `@Param` comments to automatically generate TextFields, Dropdowns, File Pickers, and Toggles.
- 💻 **Interactive PTY Terminal**: Built-in console with full Pseudo-Terminal (PTY) support. It handles interactive commands like `sudo`, `mysql`, `ssh`, or `npm init` flawlessly.
- 📁 **Workspace Management**: Organize your scripts in folders. Real-time file monitoring keeps your UI in sync with your file system.
- 📝 **Built-in Code Editor**: Edit scripts on the fly with syntax highlighting (Python, Bash, Node.js, Ruby), auto-indentation, and standard shortcuts (`Cmd+S`, `Cmd+/`, `Cmd+F`).
- 🌍 **Environment Variables**: Inject custom environment variables per script without messing up your global `~/.zshrc`.
- 🔒 **Privacy First & Native**: 100% native SwiftUI. Runs locally. No Electron bloat, no cloud sync, your scripts stay on your machine.

---

## 📦 Installation

### Option 1: Direct Download
Download the latest `.dmg` file from the [Releases](https://github.com/your-username/ScriptManager/releases) page and drag it to your Applications folder.

### Option 2: Build from Source
```bash
git clone https://github.com/your-username/ScriptManager.git
cd ScriptManager
open ScriptManager.xcodeproj
# Hit Cmd + R in Xcode to build and run
```

---

## ⚠️ Troubleshooting: App is damaged and can't be opened?

Since ScriptManager runs **outside the macOS Sandbox** to provide full terminal execution capabilities and might not be signed with an Apple Developer certificate, macOS Gatekeeper might block it.

If you see an error saying the app is damaged, cannot be opened, or is from an unidentified developer, run the following commands in your Terminal:

```bash
# 1. Allow apps from anywhere (optional but recommended for unsigned apps)
sudo spctl --master-disable

# 2. Remove the quarantine attribute from the app (Crucial Step)
sudo xattr -r -d com.apple.quarantine /Applications/ScriptManager.app
```
*Note: Make sure you have moved the app to the `/Applications` folder before running the second command.*

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
- **PTY Allocation**: Uses `posix_openpt` and `grantpt` to allocate real pseudo-terminals, capturing ANSI color codes and supporting interactive stdin (like `sudo` password prompts).
- **Security-Scoped Bookmarks**: Persists workspace access across app restarts without violating App Sandbox rules.
- **Stream Parsing**: Asynchronously reads only the first few kilobytes of files to extract metadata, ensuring zero lag even with massive log files.

---

## 🤝 Contributing

We love contributions! If you'd like to help make ScriptManager even better, please check out our[Contributing Guide](CONTRIBUTING.md).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
