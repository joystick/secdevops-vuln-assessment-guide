# Chapter 5: Exercise — npm Supply Chain Attack

This is your first TADR exercise. You will analyze synthetic artifacts that mimic the March 2026 axios supply chain compromise, where a compromised maintainer account published poisoned versions of `axios` that pulled in a phantom dependency (`plain-crypto-js@4.2.1`) containing a cross-platform RAT dropper.

## Background

In a supply chain attack on npm, the attacker does not need to trick the user directly. Instead, they compromise a popular package (or its maintainer account) and publish a version that silently adds a malicious dependency. When developers run `npm install`, the malicious code executes via lifecycle scripts (`postinstall`, `preinstall`).

The attack chain:

```
Developer runs npm install
    └── axios@1.14.1 is installed
        └── plain-crypto-js@4.2.1 is pulled as a new dependency
            └── postinstall.sh executes automatically
                ├── Downloads a platform-specific RAT binary
                ├── Installs persistence (launch agent / systemd / schtasks)
                ├── Runs the RAT in the background
                └── Erases itself to hide traces
```

## Artifacts

All files are in `exercises/npm-supply-chain/`:

| File | What it represents |
|------|--------------------|
| `package.json` | A normal-looking project that depends on `axios@1.14.1` |
| `package-lock.json` | The resolved dependency tree revealing `plain-crypto-js@4.2.1` |
| `postinstall.sh` | The malicious dropper script from the phantom dependency |

Read the `README.md` in that directory for details on what makes these realistic and what makes them safe.

## Setup

Ensure your lab is ready (Chapter 3):

```bash
# Verify Ollama is running and models are available
ollama list
# Should show: llama3.2:3b, phi3:mini, gemma3:4b, vuln-assessor:1.0

# Build the supply chain model if you haven't already
ollama create supplychain:1.0 -f docs/guide/templates/supplychain.Modelfile
```

---

## Phase 1: Triage

**Goal**: Quickly determine if the dependency tree looks suspicious.

**Model**: `phi3:mini` (fast, code-aware)

**Time**: 5 minutes

### Step 1: Examine the package.json

Open `exercises/npm-supply-chain/package.json` in a text editor. At first glance, it looks like a normal Express + React project. Note the pinned `axios` version: `"axios": "1.14.1"` (exact version, not a range).

### Step 2: Feed the lockfile to the model

**Prompt** (paste into `ollama run phi3:mini`):

```
I am reviewing the dependency tree of an npm project. Examine this
package-lock.json and tell me:

1. Are there any packages that look like they don't belong?
2. Are there any packages with hasInstallScript: true?
3. Is the dependency chain from axios to its sub-dependencies normal?

Focus on anything unexpected. Be specific.

---
<paste the contents of package-lock.json here>
```

### Expected model output

The model should identify:

> **Suspicious findings:**
>
> 1. `plain-crypto-js@4.2.1` appears as a dependency of `axios@1.14.1`. This package
>    is not a known dependency of axios. The legitimate axios package depends on
>    `follow-redirects`, `form-data`, and `proxy-from-env` — not a crypto library.
>
> 2. `plain-crypto-js@4.2.1` has `hasInstallScript: true` and runs a `postinstall`
>    script (`sh ./scripts/postinstall.sh`). Postinstall scripts that run shell
>    commands are a common supply-chain attack vector.
>
> 3. The name `plain-crypto-js` is suspiciously similar to the legitimate
>    `crypto-js` package — this could be typosquatting.
>
> **Verdict**: This dependency tree is highly suspicious. The `plain-crypto-js`
> package should be investigated immediately.

### Triage verdict

**Suspicious.** Proceed to Analyze. The phantom dependency and the postinstall script are the primary concerns.

### What to write down

```
TRIAGE NOTES — 2026-04-XX
Artifact: package-lock.json from acme-web-dashboard
Finding: Unexpected dependency plain-crypto-js@4.2.1 under axios@1.14.1
Red flags: (1) not a known axios dependency, (2) has postinstall script,
           (3) name resembles typosquatting of crypto-js
Verdict: SUSPICIOUS — proceed to Analyze phase
Next: examine postinstall.sh
```

---

## Phase 2: Analyze

**Goal**: Understand exactly what the postinstall script does.

**Model**: `vuln-assessor:1.0` or `supplychain:1.0`

**Time**: 15-20 minutes

### Step 1: Read the script yourself first

Before asking the model, read `exercises/npm-supply-chain/postinstall.sh` in a text editor. Note the five stages: platform detection, payload download, persistence, execution, self-cleaning. This builds your own intuition — the model is a second opinion, not a replacement for your eyes.

### Step 2: Full script analysis

**Prompt** (paste into `ollama run supplychain:1.0`):

```
Analyze this postinstall script from the npm package plain-crypto-js@4.2.1.
For each section of the script, explain:

1. What it does in plain English
2. What artifacts it creates on disk
3. What network activity it generates
4. What persistence mechanism it installs

Then provide an overall assessment: is this malicious? What kind of malware is this?

---
<paste the full contents of postinstall.sh here>
```

### Expected model output

> **Stage-by-stage analysis:**
>
> **Stage 1 — Platform detection:**
> Identifies the OS (macOS/Linux/Windows) and architecture (x64/arm64) using
> `uname`. This is used to download the correct payload binary. Legitimate
> packages sometimes detect the platform, but combined with the following stages,
> this is clearly malicious.
>
> **Stage 2 — Payload download:**
> Downloads a binary from `https://cdn.example.com/packages/<os>/<arch>/update-helper`
> to `/tmp/.not-a-real-payload`. Uses curl with fallback to wget. The hidden
> filename (dot-prefix) is an attempt to avoid casual detection.
>
> - Network IoC: HTTPS connection to `cdn.example.com`
> - File IoC: `/tmp/.not-a-real-payload`
>
> **Stage 3 — Persistence:**
> Installs a platform-specific persistence mechanism:
>
> - macOS: LaunchAgent at `~/Library/LaunchAgents/com.example.update-helper.plist`
>   - Runs at login, auto-restarts (KeepAlive=true)
>   - Logs to `/tmp/.update-helper.log` and `/tmp/.update-helper.err`
> - Linux: systemd user service at `~/.config/systemd/user/update-helper.service`
>   - Restarts every 30 seconds
> - Windows: Scheduled task "UpdateHelper" running at logon with highest privileges
>
> **Stage 4 — Execution:**
> Runs the payload in the background via `nohup`, detached from the terminal.
>
> **Stage 5 — Self-cleaning:**
> Deletes itself (`rm -f "$0"`) and replaces the postinstall.sh with a benign
> stub. This means a post-incident inspection of node_modules would show a clean
> postinstall script — the original malicious version is gone.
>
> **Overall assessment:**
> This is a **cross-platform RAT dropper** delivered via npm supply chain
> compromise. It downloads a remote-access tool, ensures it persists across
> reboots, and erases evidence of the initial infection vector.

### Step 3: Identify specific IoCs

**Prompt**:

```
Based on your analysis, list all Indicators of Compromise (IoCs) in a
structured format. Include:
- File paths (all platforms)
- Network indicators (domains, URLs)
- Process names
- Persistence artifacts (plist names, service names, task names)
- Behavioral indicators
```

### Expected model output

> **IoC List:**
>
> | Type | Indicator | Platform |
> |------|-----------|----------|
> | File | `/tmp/.not-a-real-payload` | All |
> | File | `/tmp/.update-helper.log` | macOS |
> | File | `/tmp/.update-helper.err` | macOS |
> | File | `~/Library/LaunchAgents/com.example.update-helper.plist` | macOS |
> | File | `~/.config/systemd/user/update-helper.service` | Linux |
> | Domain | `cdn.example.com` | All |
> | URL | `https://cdn.example.com/packages/<os>/<arch>/update-helper` | All |
> | Plist label | `com.example.update-helper` | macOS |
> | Systemd unit | `update-helper.service` | Linux |
> | Schtask name | `UpdateHelper` | Windows |
> | Process | `.not-a-real-payload` (dot-prefixed hidden binary) | All |
> | Behavior | Outbound HTTPS on install, self-deleting postinstall script | All |

### What to write down

Add the IoCs and analysis summary to your notes. You will use them in the Detect phase.

---

## Phase 3: Detect

**Goal**: Write detection rules from your analysis.

**Model**: `vuln-assessor:1.0`

**Time**: 15-20 minutes

### Step 1: YARA rule

**Prompt**:

```
Write a YARA rule that detects the postinstall dropper script from
plain-crypto-js@4.2.1. The rule should match on:

- The curl/wget download pattern to cdn.example.com
- The LaunchAgent plist creation (com.example.update-helper)
- The self-deletion pattern (rm -f "$0")

Include rule metadata: name, description, author, date.
Make the rule specific enough to avoid false positives on legitimate
postinstall scripts.
```

### Expected model output

```yara
rule SupplyChain_NPM_PlainCryptoJS_Dropper {
    meta:
        description = "Detects postinstall dropper from plain-crypto-js supply chain attack"
        author = "SecDevOps Exercise"
        date = "2026-04-03"
        reference = "axios@1.14.1 / plain-crypto-js@4.2.1 compromise"

    strings:
        $download1 = "curl -sL" ascii
        $download2 = "cdn.example.com" ascii
        $payload_path = "/tmp/.not-a-real-payload" ascii
        $plist = "com.example.update-helper" ascii
        $systemd = "update-helper.service" ascii
        $self_delete = "rm -f \"$0\"" ascii
        $schtasks = /schtasks\s+\/create.*UpdateHelper/ ascii

    condition:
        filesize < 10KB and
        $download1 and $download2 and
        $payload_path and
        $self_delete and
        any of ($plist, $systemd, $schtasks)
}
```

### Step 2: Sigma rule

**Prompt**:

```
Write a Sigma rule that detects the post-exploitation behavior of this
dropper on macOS: a hidden process in /tmp/ making outbound HTTPS
connections, combined with a new LaunchAgent being created.

Format as valid Sigma YAML with title, status, description, logsource,
detection, and level fields.
```

### Expected model output

```yaml
title: Supply Chain RAT - Hidden Payload Execution (macOS)
id: exercise-npm-supply-chain-001
status: experimental
description: >
    Detects execution of a hidden binary from /tmp/ combined with
    LaunchAgent persistence, consistent with npm supply chain attack
    dropper behavior (plain-crypto-js style).
author: SecDevOps Exercise
date: 2026/04/03
logsource:
    category: process_creation
    product: macos
detection:
    payload_execution:
        Image|startswith: '/tmp/.'
    persistence_creation:
        CommandLine|contains:
            - 'LaunchAgents'
            - 'com.example.update-helper'
    condition: payload_execution or persistence_creation
level: critical
tags:
    - attack.persistence
    - attack.t1543.004
    - attack.execution
    - attack.t1059.004
falsepositives:
    - Legitimate software using hidden temp files (rare)
```

### Step 3: Log detection queries

**Prompt**:

```
Write 3 one-liner shell commands a DevOps engineer can run on macOS to
check if this specific dropper has been active on a system:

1. Check for the payload file
2. Check for the LaunchAgent
3. Check for network connections to the C2 domain
```

### Expected model output

```bash
# 1. Check for payload file (and any dot-prefixed executables in /tmp)
find /tmp -name ".*" -type f -perm +111 -ls 2>/dev/null

# 2. Check for the malicious LaunchAgent
ls -la ~/Library/LaunchAgents/com.example.update-helper.plist 2>/dev/null && \
    echo "FOUND: Malicious LaunchAgent present"

# 3. Check for connections to C2 (adapt domain for real cases)
lsof -i -nP | grep -i "example.com" 2>/dev/null
```

### What to write down

Save your YARA rule, Sigma rule, and log queries. These are the detection artifacts from this exercise.

---

## Phase 4: Remediate

**Goal**: Contain, eradicate, and verify cleanup.

**Model**: `vuln-assessor:1.0`

**Time**: 10-15 minutes

### Step 1: Generate remediation commands

**Prompt**:

```
Given the npm supply chain dropper that:
- Downloads a payload to /tmp/.not-a-real-payload
- Creates persistence via com.example.update-helper LaunchAgent (macOS),
  update-helper.service (Linux), or UpdateHelper scheduled task (Windows)
- Self-deletes the original postinstall script

Provide step-by-step remediation commands for all three platforms.
Include: containment, eradication, and verification for each.
```

### Expected model output

**macOS remediation:**

```bash
# --- Containment ---
# Kill the payload process
pkill -f ".not-a-real-payload" 2>/dev/null

# Block C2 domain at host level
echo "127.0.0.1 cdn.example.com" | sudo tee -a /etc/hosts

# --- Eradication ---
# Unload and remove LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.example.update-helper.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.example.update-helper.plist

# Remove payload binary and logs
rm -f /tmp/.not-a-real-payload
rm -f /tmp/.update-helper.log
rm -f /tmp/.update-helper.err

# Remove compromised npm packages
cd /path/to/project
npm uninstall axios
rm -rf node_modules/plain-crypto-js
# Pin axios to a known-good version
npm install axios@1.7.9

# --- Verification ---
# Confirm LaunchAgent is gone
launchctl list | grep "update-helper"  # should return nothing
ls ~/Library/LaunchAgents/com.example.update-helper.plist  # should not exist

# Confirm payload is gone
ls /tmp/.not-a-real-payload  # should not exist

# Confirm no connections to C2
lsof -i -nP | grep "example.com"  # should return nothing

# Confirm clean dependency tree
npm ls axios  # should show clean version, no plain-crypto-js
```

**Linux remediation:**

```bash
# --- Containment ---
pkill -f ".not-a-real-payload" 2>/dev/null
echo "127.0.0.1 cdn.example.com" | sudo tee -a /etc/hosts

# --- Eradication ---
systemctl --user stop update-helper.service 2>/dev/null
systemctl --user disable update-helper.service 2>/dev/null
rm -f ~/.config/systemd/user/update-helper.service
systemctl --user daemon-reload

rm -f /tmp/.not-a-real-payload

# npm cleanup (same as macOS)
cd /path/to/project && npm uninstall axios && npm install axios@1.7.9

# --- Verification ---
systemctl --user status update-helper.service  # should show not found
ls /tmp/.not-a-real-payload  # should not exist
```

**Windows remediation (PowerShell):**

```powershell
# --- Containment ---
Stop-Process -Name "not-a-real-payload" -Force -ErrorAction SilentlyContinue

# --- Eradication ---
schtasks /delete /tn "UpdateHelper" /f
Remove-Item "$env:TEMP\.not-a-real-payload" -Force -ErrorAction SilentlyContinue

# npm cleanup
cd C:\path\to\project
npm uninstall axios
npm install axios@1.7.9

# --- Verification ---
schtasks /query /tn "UpdateHelper"  # should show ERROR: not found
Get-Process -Name "not-a-real-payload" -ErrorAction SilentlyContinue  # should be empty
```

### Step 2: Lessons learned

After completing the exercise, update your process:

- **Prompt update**: Did the triage prompt catch `plain-crypto-js` immediately? If not, add "check for packages not in the known dependency list of popular packages" to your triage prompt.
- **Modelfile update**: Consider adding `plain-crypto-js` and the dropper pattern to the `supplychain.Modelfile` system prompt as a known example.
- **Detection update**: Add your YARA and Sigma rules to a permanent rule set in `~/detection-rules/`.
- **Process update**: Should your CI pipeline check for `hasInstallScript: true` on new dependencies?

---

## Sample analysis report

Here is a complete report combining all four TADR phases. This is what a good exercise completion looks like.

```markdown
# Analysis Report: npm Supply Chain — plain-crypto-js@4.2.1

**Date**: 2026-04-XX
**Analyst**: [Your name]
**Artifacts**: package.json, package-lock.json, postinstall.sh
**Models used**: phi3:mini (triage), supplychain:1.0 (analyze/detect/remediate)

## Triage

The dependency tree for acme-web-dashboard contains axios@1.14.1, which
depends on plain-crypto-js@4.2.1. This package:
- Is not a known dependency of axios (phantom dependency)
- Has a postinstall script (hasInstallScript: true)
- Has a name similar to the legitimate crypto-js (possible typosquatting)

**Verdict**: SUSPICIOUS

## Analysis

The postinstall.sh script is a cross-platform RAT dropper with 5 stages:
1. Platform detection (uname -s / uname -m)
2. Binary download from cdn.example.com to /tmp/.not-a-real-payload
3. Persistence installation (LaunchAgent on macOS, systemd on Linux, schtasks on Windows)
4. Background execution via nohup
5. Self-cleaning (deletes itself, replaces with benign stub)

## IoCs

| Type | Value | Platform |
|------|-------|----------|
| Domain | cdn.example.com | All |
| File | /tmp/.not-a-real-payload | All |
| LaunchAgent | com.example.update-helper | macOS |
| Systemd unit | update-helper.service | Linux |
| Schtask | UpdateHelper | Windows |
| Behavior | Self-deleting postinstall script | All |

## Detection Rules

- YARA: SupplyChain_NPM_PlainCryptoJS_Dropper (matches dropper script patterns)
- Sigma: exercise-npm-supply-chain-001 (matches post-exploitation behavior)
- Log queries: 3 one-liners for macOS (payload file, LaunchAgent, network)

## Remediation

- Containment: kill process, block C2 domain in /etc/hosts
- Eradication: remove LaunchAgent/systemd/schtask, delete payload, npm uninstall
- Verification: confirm all artifacts removed, no C2 connections, clean dep tree
- Lesson: add hasInstallScript check to CI pipeline
```

---

## Your turn

Now practice on your own:

1. Open the artifacts without looking at the expected outputs above.
2. Run through all four TADR phases using your models.
3. Compare your findings to the expected outputs.
4. Note where your prompts or analysis differed — that is where you learn the most.

**Stretch goal**: Modify the `postinstall.sh` to use a different persistence mechanism (e.g., crontab instead of LaunchAgent) and re-run the analysis. Does your model catch the change?

## Next steps

- **Chapter 6**: Apply TADR to binary malware from email and MikroTik routers (medium difficulty).
