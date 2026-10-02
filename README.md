# Umbraco Docs Screenshots Tool

This tool automatically finds outdated backoffice screenshots in the [UmbracoDocs](https://github.com/umbraco/UmbracoDocs) repository, captures fresh ones from a real running Umbraco instance, and opens a pull request to replace them.

This guide assumes no prior experience with these tools. Follow it top to bottom and you'll have a working setup.

## Pre-requisites

You'll need five things on your machine before this works:

| Tool | What it's for |
|---|---|
| **.NET SDK** | Runs the local demo Umbraco CMS instances |
| **Node.js** | Runs the browser automation (Playwright) |
| **Git** | Version control, and lets Claude Code run the shell scripts this tool relies on |
| **GitHub CLI (`gh`)** | Opens the pull request automatically at the end of a run |
| **Claude Code** | The AI agent that actually drives the whole workflow |

## Part 1: One-time setup

### 1. Install Git for Windows

Download and install from [git-scm.com/downloads/win](https://git-scm.com/downloads/win). Accept the default options during install.

> **Why this matters:** this tool's automation scripts are written as `.sh` (bash) scripts. Without Git installed, Claude Code falls back to PowerShell, which can't run them correctly.

### 2. Install the .NET SDK

Download the **.NET 10 SDK** from [dotnet.microsoft.com/download](https://dotnet.microsoft.com/download). Run the installer.

Open a **new** PowerShell window and run:

```powershell
dotnet --version
```

You should see a version number starting with `10.`.

### 3. Install Node.js

Download the **LTS version** from [nodejs.org](https://nodejs.org). Run the installer, accepting defaults.

Verifyby running the following commands:

```powershell
node --version
npm --version
```

### 4. Install the GitHub CLI (`gh`)

```powershell
winget install --id GitHub.cli
```

**Close and reopen your terminal** after this (installers update settings that only apply to new terminal windows).

Verify:

```powershell
gh --version
```

Now sign in:

```powershell
gh auth login
```

- Choose **GitHub.com**
- Choose **HTTPS**
- Choose **Login with a web browser**
- Follow the on-screen code and browser prompt.

Then run this one extra command. It prevents a known issue where Git can freeze waiting for a login popup that never appears:

```powershell
gh auth setup-git
```

### 5. Install Claude Code

```powershell
irm https://claude.ai/install.ps1 | iex
```

The installer will likely tell you it needs to be added to your `PATH`. If so:

1. Press `Win`, type **"Environment Variables"**, open **"Edit environment variables for your account"**
2. Under **User variables**, select `Path` → **Edit** → **New**
3. Paste in the path the installer showed you (typically `C:\Users\<you>\.local\bin`)
4. Click OK on everything
5. **Close and reopen your terminal**

Verify:

```powershell
claude --version
```

## Part 2: Get the two repositories

You need **two separate folders**, sitting next to each other:

```cs
D:\Documentation\Umbraco-Docs-Screenshots-Tool\
├── umbraco-docs-screenshots\   ← the tool itself
└── UmbracoDocs\                ← your own copy of the docs
```

Keeping them as siblings like this matters. The tool automatically looks for the docs folder right next to itself.

### 1. Clone this tool

```powershell
cd D:\Documentation\Umbraco-Docs-Screenshots-Tool
git clone https://github.com/hifi-phil/umbraco-docs-screenshots.git
cd umbraco-docs-screenshots
npm install
npx playwright install chromium
```

### 2. Fork and clone UmbracoDocs

This tool opens pull requests from **your own copy** (a "fork") of the docs repo, not the original directly.

**Create your fork:**

```powershell
gh repo fork umbraco/UmbracoDocs --clone=false
```

**Clone it as a sibling folder:**

```powershell
cd D:\Documentation\Umbraco-Docs-Screenshots-Tool
git clone https://github.com/<your-github-username>/UmbracoDocs.git UmbracoDocs
```

**Connect it back to the original repo**, so it can stay up to date:

```powershell
cd UmbracoDocs
git remote add upstream https://github.com/umbraco/UmbracoDocs.git
git fetch upstream
```

Confirm both remotes are set up correctly:

```powershell
git remote -v
```

You should see **`origin`** pointing to your fork, and **`upstream`** pointing to `umbraco/UmbracoDocs`.

---

## Part 3: Test it manually first

Before letting the AI agent drive everything, it's worth confirming the basic pieces work.

### Start a demo Umbraco instance

Open a terminal and run:

```powershell
cd D:\Documentation\Umbraco-Docs-Screenshots-Tool\umbraco-docs-screenshots\demo
dotnet run --project v18
```

Leave this running. Wait until you see `Now listening on:` in the output. The first boot takes a little while and installs itself automatically. You can log into the backoffice at `https://localhost:44327/umbraco` using:

- **Email:** `admin@admin.com`
- **Password:** `1234567890`

### Run a test capture

In a **new** terminal (leave the instance running in the first one):

```powershell
cd D:\Documentation\Umbraco-Docs-Screenshots-Tool\umbraco-docs-screenshots
npm run test:v18
```

If it says `1 passed`, everything is wired up correctly. Check the `screenshots\` folder for the images it captured.

You can stop the demo instance now (click into its terminal, press `Ctrl+C`).

## Part 4: Run the AI agent tool

This is where the tool actually does its job automatically: finding an outdated screenshot, capturing a fresh one, and opening a pull request.

### Start Claude Code

```powershell
cd D:\Documentation\Umbraco-Docs-Screenshots-Tool\umbraco-docs-screenshots
claude
```

Wait for it to load. You'll see a banner and a `>` prompt at the bottom. **Type commands into this prompt, not into PowerShell.**

### Run the tool

For your very first run, target a **specific** image rather than letting it search on its own. It's easier to follow along:

```cs
/update-docs-screenshots 18/umbraco-cms/<path-to-an-outdated-image>.png
```

Not sure which image to pick? Just ask it in plain language instead:

```cs
/update-docs-screenshots
```

This makes it search the docs on its own for something outdated.

**The first time you run this**, it may ask you a few questions. For example, where your `UmbracoDocs` folder is (even though it's set up correctly, auto-detection doesn't always find it. Just paste the full path if asked: `D:\Documentation\Umbraco-Docs-Screenshots-Tool\UmbracoDocs`).

Just answer its questions as they come up. When it finishes, it'll give you a link to the pull request it opened. Go take a look and review the screenshot it captured.

## Part 5 (optional): Connect Slack

If your team uses a Slack channel to request specific screenshot updates, you can connect it:

1. Inside Claude Code, type: `/mcp`
2. Find **Slack** in the list and select it
3. Follow the browser sign-in prompt
4. Once it shows **"connected,"** you're done

> **Note:** this connection can occasionally expire and need to be redone. See Troubleshooting below if a run suddenly starts failing with a Slack-related error.

## Troubleshooting

- **`claude` or `gh` isn't recognized as a command**
You installed it, but your terminal doesn't know about it yet. Close the terminal completely and open a fresh one. If it still doesn't work, the install location wasn't added to your PATH. See the [Environment Variables steps in Part 1](#5-install-claude-code).

- **A Git push hangs forever/a login window seems to be missing**
Run `gh auth setup-git` (Part 1, step 4). This is the most common fix. Also make sure your computer isn't locked/asleep during a scheduled run, since a login prompt can't be answered by no one.

- **"OAuth session expired and could not be refreshed" (Slack)**
Your Slack connection needs to be redone. In Claude Code, type `/mcp`, select Slack, choose **Reconnect**, and sign in again.

- **A scheduled run shows as "succeeded" but no pull request appeared, and the log file is empty**
Check that the `logs` folder actually exists (Windows doesn't create it automatically). If it's missing, create it manually once:

```powershell
mkdir "D:\Documentation\Umbraco-Docs-Screenshots-Tool\logs"
```

- **"No MCP servers configured" when you run `/mcp`, even though it worked before**
You've likely been logged out (often after an update). Check the bottom-right corner of the Claude Code window. If it says "Not logged in," type `/login` and sign back in.

- **A run seems stuck with no output for several minutes**
This can be normal. Capturing a screenshot involves booting a full CMS instance and driving a browser, which takes a few minutes. Check whether it's still doing real work:

```powershell
Get-Process | Where-Object { $_.ProcessName -match "claude|node|dotnet" }
```

If those processes are actively using CPU, it's working. Just wait. If it's been stuck for a long time with no progress, press `Ctrl+C` and try again, this time adding `--verbose` to the command so you can watch what it's doing:

```powershell
claude -p "/update-docs-screenshots" --dangerously-skip-permissions --verbose
```

## What this tool can and can't do

- ✅ Works for **Umbraco CMS** backoffice screenshots (versions 17 and 18)
- ❌ Does **not** work for Umbraco Cloud, Commerce, Engage, Forms, Deploy, or other add-on products. The local setup only has a plain CMS to capture from
- ✅ One run of the tool = one pull request. It won't try to fix multiple screenshots in a single run.

If you have questions about extending this to other products, or run into an issue not covered here, reach out to the repo owner or open an issue at [github.com/hifi-phil/umbraco-docs-screenshots/issues](https://github.com/hifi-phil/umbraco-docs-screenshots/issues).
