# Chapter 4: Air-Gap Operations

An air-gapped laptop is only as secure as the discipline around it. This chapter defines the operational procedures for safely transferring artifacts to and from your analysis environment.

These are checklists, not suggestions. Print them out or keep them open on the staging machine while you work.

## 4.1 Network isolation

Before the laptop becomes your analysis lab, disable all network interfaces permanently.

### macOS firmware-level lockdown

1. Shut down the MacBook Air
2. Boot into Recovery Mode (hold power button on M1 until "Loading startup options" appears)
3. Open **Startup Security Utility** (Utilities menu)
4. Set **Secure Boot** to Full Security
5. Boot normally, then in **System Preferences > Network**:
   - Select Wi-Fi, click the minus (-) button to remove the interface
   - If Bluetooth is listed, remove it too
6. In **System Preferences > Bluetooth**: Turn off Bluetooth
7. Verify: the menu bar should show no Wi-Fi or Bluetooth icons

### Verification

```bash
# Should return no active network interfaces (except loopback)
ifconfig | grep -E "^[a-z]" | grep -v lo0

# Should show no Wi-Fi hardware
networksetup -listallhardwareports | grep -A2 Wi-Fi
# Expected: empty or "no port"

# Confirm no route to the internet
ping -c 1 8.8.8.8
# Expected: "Network is unreachable" or 100% packet loss
```

Run these checks every time you sit down at the air-gapped laptop.

## 4.2 USB media hygiene

### Choosing USB media

- Use a **dedicated USB drive** that is only used for air-gap transfers. Label it clearly.
- Prefer USB drives with a **physical write-protect switch** if available.
- Never use the same USB drive for both transferring samples IN and carrying results OUT.
- If you must extract results (e.g., a written report), use a **separate, clearly labeled USB drive** for outbound data.

### The two-USB rule

| USB drive | Label | Direction | Contents |
|-----------|-------|-----------|----------|
| **USB-IN** | "INBOUND - staging to airgap" | Staging machine -> Air-gapped laptop | Tools, models, samples, updates |
| **USB-OUT** | "OUTBOUND - reports only" | Air-gapped laptop -> Reporting machine | Written reports, detection rules (text only) |

**USB-IN** never gets plugged back into the staging machine after touching the air-gapped laptop. After each transfer session, format it on a separate machine or treat it as disposable.

**USB-OUT** never carries executable files, only plain text (Markdown reports, YARA rules, Sigma rules). The receiving machine should scan it before opening any files.

## 4.3 Transfer checklist: Tools and models (one-time setup)

Use this checklist when initially setting up the lab (Chapter 3) or when updating tools.

### Before transfer (on staging machine)

```
[ ] Downloaded Ollama installer/binary
    File: ________________________  SHA256: ________________________
[ ] Downloaded all required models (ollama pull)
    [ ] llama3.2:3b
    [ ] phi3:mini
    [ ] gemma3:4b
[ ] Created models archive: tar -czf ollama-models.tar.gz -C ~/.ollama models/
    SHA256: ________________________
[ ] Downloaded Ghidra zip
    File: ________________________  SHA256: ________________________
[ ] Downloaded JDK for macOS ARM64
    File: ________________________  SHA256: ________________________
[ ] Downloaded radare2 binaries or source
    File: ________________________  SHA256: ________________________
[ ] Downloaded GhidrOllama (GhidrOllama.py + ghidrollama_utils/)
    SHA256 of zip/tar: ________________________
[ ] Copied all Modelfile templates from docs/guide/templates/
[ ] Verified all SHA256 checksums against official sources
[ ] Formatted USB-IN drive (FAT32 or exFAT for macOS compatibility)
[ ] Copied all files to USB-IN
[ ] Safely ejected USB-IN from staging machine
```

### During transfer (on air-gapped laptop)

```
[ ] Verified laptop has no network connectivity (run ifconfig check)
[ ] Mounted USB-IN (read-only if possible: diskutil mount readOnly /dev/diskN)
[ ] Verified SHA256 of each file on USB matches the checksums recorded above
    Command: shasum -a 256 /Volumes/USB-IN/<file>
[ ] Copied files to appropriate locations (see Chapter 3)
[ ] Ejected USB-IN
[ ] Ran Chapter 3 verification checklist (all tools working)
```

### After transfer

```
[ ] USB-IN is either: formatted on a separate machine, or set aside (not reused on staging)
[ ] Checksums recorded in a transfer log (date, files, SHA256 values)
```

## 4.4 Transfer checklist: Samples for analysis

Use this checklist every time you transfer suspicious artifacts to the air-gapped laptop.

### Before transfer (on staging machine)

```
[ ] Identified the artifacts to transfer:
    Artifact 1: ________________________
    Artifact 2: ________________________
    Artifact 3: ________________________
[ ] Extracted artifacts in an isolated environment (VM or container)
    - Email attachments: extracted from .eml/.msg in a disposable VM
    - npm packages: downloaded with --ignore-scripts, extracted in a container
    - MikroTik configs: exported via /export or /file print
    - JavaScript: saved from browser cache or curl in a VM
[ ] Computed SHA256 of each artifact
    Artifact 1 SHA256: ________________________
    Artifact 2 SHA256: ________________________
    Artifact 3 SHA256: ________________________
[ ] Placed artifacts in a clearly named directory on USB-IN
    Directory name convention: YYYY-MM-DD_<case-name>/
[ ] Included a manifest.txt listing all files and their SHA256 values
[ ] Safely ejected USB-IN
```

### During transfer (on air-gapped laptop)

```
[ ] Verified no network connectivity
[ ] Mounted USB-IN
[ ] Verified SHA256 of each artifact matches manifest
[ ] Copied artifacts to a dedicated analysis directory
    Recommended: ~/cases/YYYY-MM-DD_<case-name>/
[ ] Ejected USB-IN
[ ] Opened artifacts ONLY in analysis tools (Ghidra, radare2, text editor, Ollama)
    Never double-click or execute binaries directly
```

### After analysis

```
[ ] Analysis artifacts (reports, rules) saved in the case directory
[ ] If exporting results: copy ONLY text files to USB-OUT
    [ ] No executables on USB-OUT
    [ ] No original samples on USB-OUT
    [ ] Only: .md, .yar, .yml, .txt, .json files
[ ] USB-IN from this session: formatted or disposed of
```

## 4.5 Transfer checklist: Model updates

Periodically you may want to update Ollama or pull newer model versions.

### On the staging machine

```
[ ] Downloaded updated Ollama binary/app
    SHA256: ________________________
[ ] Pulled updated models (ollama pull <model>)
[ ] Created fresh models archive
    SHA256: ________________________
[ ] Verified the update doesn't change model behavior unexpectedly
    - Run a known prompt and compare output to previous version
    - Document any behavior changes
[ ] Copied to USB-IN with updated checksums
```

### On the air-gapped laptop

```
[ ] Backed up current ~/.ollama/models/ before overwriting
    cp -r ~/.ollama/models/ ~/.ollama/models-backup-YYYY-MM-DD/
[ ] Installed updated files
[ ] Ran Chapter 3 verification checklist
[ ] Ran a known prompt from Chapter 5/6/7 to confirm model behavior is consistent
[ ] If behavior changed: noted in transfer log, updated Modelfile if needed
```

## 4.6 What goes IN, what stays, what goes OUT

| Category | Direction | Examples |
|----------|-----------|---------|
| **Tools and models** | IN (one-time + updates) | Ollama, models, Ghidra, radare2, GhidrOllama, Modelfiles |
| **Samples for analysis** | IN (per case) | Suspicious binaries, scripts, configs, package files |
| **Exercise artifacts** | Already on laptop | Synthetic samples from `docs/guide/exercises/` |
| **Analysis work product** | STAYS on laptop | Ghidra projects, Ollama chat history, working notes |
| **Reports and rules** | OUT (via USB-OUT, text only) | Markdown reports, YARA rules, Sigma rules, IoC lists |
| **Original samples** | NEVER out | Malware samples never leave the air-gapped laptop |
| **Ollama model weights** | NEVER out | Model files never leave the air-gapped laptop |

### What NEVER happens

- USB-IN plugged back into the staging machine after use on the air-gapped laptop
- Executables or binaries on USB-OUT
- Network adapters re-enabled "just for a quick download"
- Original malware samples copied to USB-OUT
- Analysis tools copied out (they may have been contaminated by analyzing malware)

## 4.7 Transfer log template

Keep a running log of all transfers. This is your audit trail.

```markdown
# Air-Gap Transfer Log

## 2026-04-03 — Initial lab setup
- Direction: IN
- USB-IN serial/label: ________________________
- Files transferred:
  - Ollama-darwin.zip (SHA256: abc123...)
  - ollama-models.tar.gz (SHA256: def456...)
  - ghidra_11.3_PUBLIC.zip (SHA256: ghi789...)
  - temurin-jdk-17.tar.gz (SHA256: jkl012...)
  - radare2-install.tar.gz (SHA256: mno345...)
  - GhidrOllama.zip (SHA256: pqr678...)
- Verification: all checksums matched
- USB-IN disposition: formatted after use

## 2026-04-04 — Exercise 1 samples
- Direction: IN
- USB-IN serial/label: ________________________
- Files transferred:
  - (synthetic, from exercises/ directory — no USB needed)
- Notes: first exercise uses only repo-included artifacts
```

## Next steps

- **Chapter 5**: Start your first TADR exercise with the npm supply chain attack samples already in `docs/guide/exercises/npm-supply-chain/`.
