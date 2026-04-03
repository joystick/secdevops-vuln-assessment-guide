<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# let's work on the following task:

- setting up local llm with ollama for reverse engineering.

Given a malware received by email or found on the mikrotik router
As a devops engineer
I need to set up a local llm with ollama and ghydra
On the airgapped laptop
So I can reverse engineer the malware threat and find the remediation

You can set up a secure, air‑gapped local‑LLM stack for malware reverse‑engineering using **Ollama + Ghidra (often via GhidraMCP / “Ghydra”)**, then run analysis on the MikroTik‑related or email‑delivered malware without ever touching the public internet.[^1][^2][^3]

Below is a concrete, DevOps‑style playbook tailored to your use case.

***

### 1. Target architecture (air‑gapped laptop)

Goal: on one physically air‑gapped laptop you have:

- **Ghidra** (reverse‑engineering UI)
- **Ollama** (local LLM, no internet)
- **GhidraMCP plugin / OGhidra / GhidrOllama** (Ghidra ↔ Ollama bridge)[^2][^4][^1]
- Optionally **OpenWebUI** (if you want a web‑like chat UI next to Ghidra)[^5][^3]

You bring the malware samples via a **clean, one‑way USB** or other media; never let the laptop back on‑network.

***

### 2. Prepare the air‑gapped laptop

On a spare laptop (no WiFi/Bluetooth, NIC physically disabled or removed):

1. Install a **minimal Linux** (e.g., Ubuntu LTS or Debian) with:
    - OpenJDK (for Ghidra)
    - `curl`, `wget`, `git`, Python (3.9+)[^6][^3]
2. Configure a **local disk or SSD** for:
    - Ghidra storage
    - Ollama models (multi‑GB, depending on model)

Before the laptop goes air‑gapped:

- **Download Ollama, Ghidra, and plugins on a staging machine** (or inside a VM with internet), then copy them over via USB or DVD.[^7][^8]

***

### 3. Install and configure Ollama (offline)

On the staging machine (with internet):

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1
# or: ollama pull qwen2:7b, deepseek‑coder‑6.7b‑instruct, etc.
```

Then **package the Ollama binary + model files**:

- Copy `/usr/bin/ollama` to the air‑gapped laptop.
- Copy the model directory (e.g., `~/.ollama/models/` on Linux) to the same location on the lab laptop.[^9][^2]

On the air‑gapped laptop:

```bash
sudo install ollama /usr/local/bin/ollama
mkdir -p ~/.ollama/models
# copy model files here
chmod -R 755 ~/.ollama
```

Start Ollama service (no internet needed):

```bash
ollama serve &   # or run as systemd service
ollama run llama3.1
```

Ollama should now respond on `http://localhost:11434/api/generate`.[^9][^2]

***

### 4. Install Ghidra

On the air‑gapped laptop:

1. Download Ghidra from the official site on the staging machine, verify checksums, then copy the `.tar.gz` to the air‑gapped laptop.[^6]
2. Extract:
```bash
tar -xzf ghidra_*.tar.gz
cd ghidra_*
```

3. Install **OpenJDK** (if not present) and start Ghidra:
```bash
./ghidraRun
```

Accept the EULA and license once, then close.

***

### 5. Connect Ghidra to Ollama (Ghydra / GhidrOllama / OGhidra)

There are two common patterns you can use; pick one that fits your workflow.

#### Option A: GhidrOllama (simple script)

GhidrOllama is a Python script that talks to Ollama from inside Ghidra.[^1][^2]

Steps:

1. On the staging machine, download GhidrOllama:
```bash
git clone https://github.com/lr-m/GhidrOllama.git
```

2. Copy the `GhidrOllama.py` script and the `ghidrollama_utils/` folder to the air‑gapped laptop.
3. Place them in Ghidra’s script directory, usually `~/.ghidra/.../Ghidra/Features/VarParser/...` or a custom `ghidra_scripts` dir.[^2]
4. In Ghidra:
    - Open a project and load the malware binary (e.g., PE, ELF, or MikroTik‑related blob).
    - Open **Script Manager** → load/enable `GhidrOllama.py`.
    - Configure the Ollama URL (e.g., `http://localhost:11434`) the first time it asks.
    - Select a function or assembly block and run the script; it will send the disassembly to the local LLM and return interpretations.[^1][^2]

Use‑cases for malware:

- Ask the model:
    - “Explain this function in C‑like pseudocode.”
    - “Which syscalls or network APIs does this routine likely use?”
    - “Suggest IoC patterns (strings, URLs, IPs, hashes) present here.”


#### Option B: GhidraMCP / OGhidra (more advanced “Ghydra”‑style stack)

This is closer to the “Ghydra”‑style setup many talks describe (MCP server + Ghidra).[^3][^4][^5]

Steps (high‑level):

1. On staging machine, fetch:
    - `ghydramcp` / `pyghidra‑mcp`
    - `OGhidra` (MCP server connecting Ollama to Ghidra)
2. Copy the Python code and requirements to the air‑gapped laptop.
3. Install Python deps locally (no pip to internet):
```bash
python3 -m venv ./ghydramcp-venv
source ./ghydramcp-venv/bin/activate
pip install --no-index --find-links ./offline-pkgs/ requests grpcio
```

(You must pre‑download wheels and cache them on the staging machine.)[^4][^3]

4. Start the MCP server pointed at Ollama:
```python
from og_hidra import *

server = OllamaServer(
    ollama_url="http://localhost:11434",
    model="llama3.1:8b",
)
server.start()
```

5. In Ghidra, configure GhidraMCP to connect to `localhost:<mcp_port>` and reload the extension.[^3][^4]

Advantages:

- More natural language prompts inside Ghidra.
- Can ask the model to propose remediation steps after you reverse a backdoor or C2 logic.

***

### 6. Handling malware from email and MikroTik

On the air‑gapped laptop:

#### A. Email‑delivered malware

1. Extract the binary from the email on a **disposable VM** (Internet‑connected, not the air‑gapped laptop).
2. Copy **only the binary** (e.g., `.exe`, `.dll`, `.zip` contents) via USB to the air‑gapped laptop.
3. In Ghidra:
    - Import the binary.
    - Use GhidrOllama / OGhidra to:
        - Annotate unknown functions.
        - Suggest C2 domains, IPs, or encryption routines.[^2][^3][^1]
4. Based on the analysis, write remediation steps:
    - Indicators of Compromise (file hashes, suspicious strings, registry keys).
    - Mitigations (e.g., firewall rules, EDR YARA rules).

#### B. Malware / suspicious code from MikroTik

Because MikroTik runs RouterOS, common artifacts are:

- `/flash` dumps, scripts, or custom binaries.
- Suspicious `.rsc` configuration files or scripts.

Approach:

1. From the MikroTik, export the relevant files or configuration (e.g., RouterOS export, script dumps) and transfer them to the air‑gapped laptop via USB.
2. If it’s a binary (RouterOS‑related ELF or firmware blob), analyze it in Ghidra.
3. If it’s a script (ROS script, shell script, etc.), you can still paste it into prompts through GhidrOllama or a local‑LLM chat UI (e.g., OpenWebUI) asking things like:
    - “What does this RouterOS script do?”
    - “Is this script trying to exfiltrate data or open a backdoor?”
    - “Suggest mitigation commands for this router configuration.”[^8][^3]

You can also pre‑build a **custom Ollama model** tuned for networking and security:

```dockerfile
# Modelfile
FROM llama3.1:8b
SYSTEM """
You are a reverse‑engineering and security‑analysis assistant.
You help a DevOps engineer analyze malware retrieved from email and MikroTik routers.
You answer concisely and avoid speculation.
"""
```

Then:

```bash
ollama create rash‑re:1.0 -f ./Modelfile
ollama run rash‑re:1.0
```

This model will better understand your questions about MikroTik, RouterOS, and Linux‑based malware.[^10][^9]

***

### 7. Security and air‑gap hygiene

Given your DevOps mindset, keep this tight:

- **No network adapters active** on the air‑gapped laptop; disable WiFi/Bluetooth in BIOS.
- **One‑way media**: USB keys or DVDs written from the staging machine and never plugged back into any online system that has access to the same data. Consider write‑protected or one‑time‑use media.[^7]
- **Verify checksums** before copying anything to the air‑gapped laptop.
- **Isolate the model files** in a separate directory; do not expose the laptop’s whole filesystem through Ollama (watch for file‑disclosure‑type vulnerabilities in Ollama if you ever update versions).[^11][^7]

***

If you want, I can next provide:

- A concrete **step‑by‑step playbook** (commands + paths) for your specific Linux distro and Ghidra version.
- A pre‑written **Modelfile** and prompt templates tailored for:
    - “Analyze this decompiled C‑like function from Ghidra and explain the malware behavior.”
    - “Suggest remediation and detection rules after this reversed routine.”

Say which distro (e.g., Ubuntu, Debian, Arch) and whether you prefer GhidrOllama or GhidraMCP, and I’ll turn this into a literal runbook.
<span style="display:none">[^12][^13][^14][^15][^16][^17]</span>

<div align="center">⁂</div>

[^1]: https://github.com/lr-m/GhidrOllama

[^2]: https://github.com/lr-m/GhidrOllama/blob/main/README.md

[^3]: https://www.clearseclabs.com/blog/supercharging-ghidra-re-llms-ringzer0-countermeasure-2025/

[^4]: https://github.com/msrocean/OGhidra

[^5]: https://ringzer0.training/countermeasure25-workshop-supercharging-ghidra-build-your-own-private-local-llm-re-stack-with-ghidramcp-ollama-and-openwebui/

[^6]: https://seanthegeek.net/posts/ghidra-setup-guide/

[^7]: https://localaimaster.com/blog/run-ai-offline

[^8]: https://bytebreach.com/posts/2025/reverse-engineering-binaries-with-ai/

[^9]: https://www.freecodecamp.org/news/run-and-customize-llms-locally-with-ollama/

[^10]: https://itnotes.dev/how-to-run-local-llm-with-ollama-for-beginner-developers/

[^11]: https://ridgesecurity.ai/blog/securing-your-ai-critical-vulnerabilities-found-in-popular-ollama-framework/

[^12]: https://github.com/llnl/OGhidra

[^13]: https://clearseclabs.com/blog/supercharging-ghidra-re-llms-ringzer0-countermeasure-2025/

[^14]: https://www.reddit.com/r/devops/comments/1ox297t/opensource_local_airgapped_claudecode_alternative/

[^15]: https://www.reddit.com/r/ReverseEngineering/comments/1kbfb5a/supercharging_ghidra_using_local_llms_with/

[^16]: https://www.youtube.com/watch?v=WOsVlzEXxJk

[^17]: https://www.youtube.com/watch?v=JlQWDEdlYp8

