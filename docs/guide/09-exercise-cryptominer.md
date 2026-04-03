# Chapter 9: Exercise -- Cryptominer Detection (Real Incident)

This exercise is different from the others. The artifacts are **preserved from an actual incident** where a contractor installed a Monero cryptominer on a production server. The wallet address, worker name, and file paths are preserved as-is — they are evidence that can be used to trace who profited from the attack.

This is the most common server compromise scenario DevOps engineers face: not a sophisticated exploit, but a trusted insider abusing legitimate access.

## Background

### What happened

1. A contractor with SSH access to a Linux production server installed the **MoneroOcean fork of XMRig** (a Monero cryptocurrency miner)
2. The miner was placed in the contractor's home directory at `/home/<user>/moneroocean/`
3. It was configured to connect to the **MoneroOcean mining pool** (`gulf.moneroocean.stream:10032`) and mine to the contractor's personal Monero wallet
4. The miner ran on all 4 CPU cores of an Intel Xeon VM (~1100 H/s), consuming server resources meant for production workloads
5. A launcher script (`miner.sh`) used `nice` to lower CPU priority and `pidof` to prevent duplicate instances -- basic evasion of casual monitoring

### Why this is hard to detect

| Challenge | Why it matters |
|-----------|---------------|
| Legitimate tool | XMRig is open-source software, not "malware" by signature |
| User home directory | Not in system paths (`/usr/bin`, `/opt`) where audits typically look |
| Lowered priority | `nice` makes the process less visible in `top` at a glance |
| Steady CPU usage | On a busy server, 100% CPU on 4 cores might look like normal load |
| No persistence hack | No cron, no systemd, no init script -- just a manually started process |
| Insider threat | The contractor had legitimate SSH access -- no exploitation needed |

### The MoneroOcean ecosystem

MoneroOcean is a mining pool that auto-switches between algorithms for maximum profitability. Key characteristics:

- **XMRig fork**: `XMRig/6.20.0-mo1` -- the `-mo1` suffix indicates MoneroOcean's custom build
- **Auto-algo**: Benchmarks all supported algorithms at startup, then mines the most profitable one
- **Pool**: `gulf.moneroocean.stream` on various ports (10032 = medium difficulty)
- **Payment**: Mines to a Monero wallet address (95-character string starting with `4`)

## Artifacts

All files are in `exercises/cryptominer/`:

| File | What it is |
|------|-----------|
| `miner.sh` | Launcher script with pidof check and nice |
| `config.json` | XMRig foreground config (pool, wallet, CPU settings) |
| `config_background.json` | XMRig background config (background=true, donate=0%, full algo benchmarks) |
| `xmrig.log.excerpt` | Miner startup log showing calibration, pool connection, and hash submissions |

## Setup

```bash
# Ensure vuln-assessor model is available
ollama list | grep vuln-assessor
```

No special tools needed for this exercise. The artifacts are text files (configs, scripts, logs) -- feed them directly to Ollama.

---

## Phase 1: Triage

**Goal**: You have been asked to audit a server. Determine if anything unusual is running.

**Model**: `llama3.2:3b`

**Time**: 5-10 minutes

### Step 1: Simulate the discovery

In a real audit, you would find this by checking running processes and home directories. Simulate this:

```bash
# What a 'ps' output would have shown on the compromised server:
# PID  USER        %CPU  COMMAND
# 1847 restudio  98.2  /home/restudio/moneroocean/xmrig
# 1848 restudio  98.1  /home/restudio/moneroocean/xmrig
# 1849 restudio  98.0  /home/restudio/moneroocean/xmrig
# 1850 restudio  97.9  /home/restudio/moneroocean/xmrig

# What a directory listing would show:
# /home/restudio/moneroocean/
# ├── config.json
# ├── config_background.json
# ├── miner.sh
# ├── xmrig            (8.7 MB binary)
# └── xmrig.log        (5.5 MB, growing)
```

### Step 2: Feed the launcher script to the model

**Prompt** (paste into `ollama run llama3.2:3b`):

```
During a server audit, I found this shell script at
/home/restudio/moneroocean/miner.sh along with a binary called
'xmrig' and JSON config files. Give me a quick assessment:

1. What does this script do?
2. Is this legitimate software or unauthorized?
3. What should I investigate next?

---
<paste contents of miner.sh>
```

### Expected model output

> **Assessment:**
>
> 1. This script starts the `xmrig` binary with `nice` (lowered CPU priority)
>    after checking that no other instance is already running (`pidof xmrig`).
>    The error message explicitly says "Monero miner."
>
> 2. **This is a cryptocurrency miner.** XMRig is open-source Monero mining
>    software. Its presence on a production server is almost certainly
>    unauthorized unless your organization explicitly mines cryptocurrency.
>    The use of `nice` suggests an attempt to reduce visibility.
>
> 3. **Investigate immediately:**
>    - Check `config.json` for the mining pool and wallet address
>    - Check `xmrig.log` for how long it has been running
>    - Check who deployed it (`ls -la`, file timestamps, SSH auth logs)
>    - Check CPU usage history (monitoring dashboards)

**Triage verdict**: MALICIOUS (unauthorized resource theft). Proceed to Analyze.

---

## Phase 2: Analyze

**Goal**: Understand the full scope -- who is profiting, how long it has run, and what resources it consumed.

**Model**: `vuln-assessor:1.0`

**Time**: 15-20 minutes

### Step 1: Analyze the mining configuration

**Prompt**:

```
Analyze this XMRig cryptocurrency miner configuration file.
Extract all operational details:

1. What mining pool is it connecting to?
2. What is the wallet address (who gets paid)?
3. What CPU resources is it configured to use?
4. Is it configured to run in the background?
5. Is there any attempt to hide or reduce visibility?
6. List all IoCs (network, file, process) from this config.

---
<paste contents of config.json>
```

### Expected output

> **Configuration analysis:**
>
> 1. **Pool**: `gulf.moneroocean.stream:10032` (MoneroOcean pool, medium difficulty)
> 2. **Wallet**: `41qbTDmsb6s4RiWgju3kSSNStWYY7mfyoepx4sFmw5um68MxJtnzQQw31bN1Y9hjp4jYwg2WTpeUfaGT375rNvyX4VGNw8Q`
>    - This is a Monero (XMR) wallet address -- whoever controls this wallet receives the mining proceeds
>    - Worker name: `multivendor`
> 3. **CPU**: `max-threads-hint: 100` (use 100% of available threads), `huge-pages: true` (optimize memory), `memory-pool: true`
> 4. **Background**: `false` in this config (foreground mode), but a separate `config_background.json` exists with `background: true`
> 5. **Visibility reduction**:
>    - `syslog: true` but no alerting configured
>    - `donate-level: 1` (minimal donation to XMRig developers -- keeps traffic patterns consistent with normal XMRig)
>    - Log file written to user's home directory, not a system log location
> 6. **IoCs:**
>
> | Type | Indicator |
> |------|-----------|
> | Domain | gulf.moneroocean.stream |
> | Port | 10032 |
> | IP | 199.247.0.216 (pool IP from log) |
> | File | /home/restudio/moneroocean/xmrig |
> | File | /home/restudio/moneroocean/config.json |
> | File | /home/restudio/moneroocean/config_background.json |
> | File | /home/restudio/moneroocean/xmrig.log |
> | File | /home/restudio/moneroocean/miner.sh |
> | Process | xmrig |
> | Wallet | 44AFFq5k... (Monero address) |

### Step 2: Analyze the background config differences

**Prompt**:

```
Compare these two XMRig configurations. What is different between the
foreground config and the background config? What does the background
config tell us about the attacker's operational approach?

--- Foreground config (config.json) ---
<paste config.json>

--- Background config (config_background.json) ---
<paste config_background.json>
```

### Expected output

> **Key differences:**
>
> | Setting | Foreground | Background |
> |---------|-----------|------------|
> | `background` | false | **true** (daemon mode) |
> | `donate-level` | 1 | **0** (no XMRig donation, maximizes attacker profit) |
> | CPU thread config | Simple (max-threads-hint: 100) | **Detailed per-algo thread mapping** (4 threads across all algorithms) |
> | `algo-perf` section | Absent | **Present with full benchmark results** |
>
> **Operational insight**: The attacker used the foreground config for initial
> testing and benchmarking, then switched to the background config for
> persistent operation. Setting `donate-level: 0` means zero mining proceeds
> go to XMRig developers (the default is 1%) -- the attacker wants maximum
> payout. The `algo-perf` section shows the miner already benchmarked all
> algorithms on this specific hardware, meaning it has been calibrated for
> optimal profitability.

### Step 3: Analyze the log

**Prompt**:

```
Analyze this XMRig miner log excerpt. Extract:

1. When did the miner start?
2. What hardware is it running on?
3. What algorithms were benchmarked and at what hashrates?
4. When did it connect to the pool and start mining?
5. What was the sustained hashrate?
6. How many shares were accepted?

---
<paste contents of xmrig.log.excerpt>
```

### Expected output

> **Log analysis:**
>
> 1. **Start time**: 2023-08-23 14:35:43 UTC
> 2. **Hardware**: Intel Xeon Skylake VM, 4 cores / 4 threads, 15.3 GB RAM (69% used), running in a virtual machine
> 3. **Benchmark results** (20-second rounds per algorithm):
>    - rx/arq: 4531 H/s (highest)
>    - cn-pico: 3357 H/s
>    - argon2/chukwav2: 3251 H/s
>    - panthera: 2102 H/s
>    - rx/0: 1061 H/s (selected for actual mining)
> 4. **Pool connection**: 14:40:23 -- connected to gulf.moneroocean.stream:10032 at IP 199.247.0.216
> 5. **Sustained hashrate**: ~1080-1180 H/s on rx/0 algorithm
> 6. **Shares accepted**: At least 10+ in the first 5 minutes (all accepted, 0 rejected)
>
> **Impact estimate**: At ~1100 H/s on a 4-core Xeon, this miner was consuming
> nearly all CPU capacity. For a production server, this means degraded
> application performance, increased power consumption, and potential
> thermal issues.

---

## Phase 3: Detect

**Model**: `vuln-assessor:1.0`

**Time**: 15-20 minutes

### Step 1: YARA rule for XMRig configs

**Prompt**:

```
Write a YARA rule that detects XMRig/MoneroOcean configuration files on
a filesystem. The rule should match on:

1. The moneroocean pool domain pattern (*.moneroocean.stream)
2. XMRig-specific config keys (algo-perf, randomx, donate-level)
3. Monero wallet address pattern (95-char string starting with 4)

This should detect config files, not the binary itself.
```

### Expected output

```yara
rule Cryptominer_XMRig_Config {
    meta:
        description = "Detects XMRig/MoneroOcean mining configuration files"
        author = "SecDevOps Exercise"
        date = "2026-04-03"
        reference = "Based on real cryptominer incident"

    strings:
        $pool1 = "moneroocean.stream" ascii nocase
        $pool2 = "gulf.moneroocean" ascii nocase
        $config_key1 = "\"donate-level\"" ascii
        $config_key2 = "\"algo-perf\"" ascii
        $config_key3 = "\"randomx\"" ascii
        $config_key4 = "\"pools\"" ascii
        $wallet_pattern = /\"user\"\s*:\s*\"4[0-9A-Za-z]{94}\"/

    condition:
        filesize < 50KB and
        any of ($pool*) and
        2 of ($config_key*) and
        $wallet_pattern
}
```

### Step 2: Sigma rule for process detection

**Prompt**:

```
Write a Sigma rule that detects XMRig cryptocurrency miners running on
Linux servers. Detection should cover:

1. Process name matching xmrig patterns
2. Network connections to known mining pools
3. High CPU usage combined with mining-related process names
```

### Expected output

```yaml
title: XMRig Cryptominer Process Detection (Linux)
id: exercise-cryptominer-001
status: experimental
description: >
    Detects XMRig or MoneroOcean miner processes on Linux servers.
    Based on a real insider-threat incident.
author: SecDevOps Exercise
date: 2026/04/03
logsource:
    category: process_creation
    product: linux
detection:
    process_name:
        Image|endswith:
            - '/xmrig'
            - '/xmrig-notls'
        CommandLine|contains:
            - 'moneroocean'
            - 'xmrig'
    network_indicator:
        DestinationHostname|endswith:
            - '.moneroocean.stream'
            - '.nanopool.org'
            - '.supportxmr.com'
            - '.hashvault.pro'
        DestinationPort:
            - 10032
            - 10128
            - 3333
            - 5555
    condition: process_name or network_indicator
level: critical
tags:
    - attack.impact
    - attack.t1496
falsepositives:
    - Legitimate cryptocurrency mining operations (rare on production servers)
```

### Step 3: Operational detection commands

**Prompt**:

```
Write a shell script that a DevOps engineer can run on a Linux server
to detect if a cryptominer is running or has been installed. Check for:

1. Running processes (xmrig, minerd, cpuminer patterns)
2. Network connections to known mining pools
3. Files matching miner patterns in user home directories
4. Suspicious CPU usage patterns
5. Known miner config files
```

### Expected output

```bash
#!/usr/bin/env bash
# detect-cryptominer.sh — Quick cryptominer audit for Linux servers
set -euo pipefail

echo "=== Cryptominer Detection Scan ==="
echo "Date: $(date -u)"
echo "Host: $(hostname)"
echo ""

# 1. Running processes
echo "--- Process Check ---"
ps aux | grep -iE 'xmrig|minerd|cpuminer|cryptonight|stratum' \
    | grep -v grep || echo "No suspicious processes found"
echo ""

# 2. Network connections to known mining pools
echo "--- Network Check ---"
ss -tnp | grep -iE 'moneroocean|nanopool|supportxmr|hashvault|minergate|nicehash' \
    || echo "No mining pool connections found"
ss -tnp | grep -E ':3333|:5555|:10032|:10128' \
    || echo "No connections on common mining ports"
echo ""

# 3. Files in home directories
echo "--- File Check ---"
find /home -maxdepth 4 -name "xmrig*" -o -name "config.json" -path "*/monero*" \
    -o -name "miner.sh" -o -name "cpuminer*" 2>/dev/null \
    || echo "No miner files found in /home"
echo ""

# 4. CPU usage (processes over 80% CPU)
echo "--- High CPU Processes ---"
ps aux --sort=-%cpu | head -6
echo ""

# 5. Config file content scan
echo "--- Config File Scan ---"
grep -rl "moneroocean\|stratum+tcp\|donate-level\|algo-perf" \
    /home /tmp /var/tmp /opt 2>/dev/null \
    || echo "No miner config patterns found"
echo ""

echo "=== Scan Complete ==="
```

---

## Phase 4: Remediate

**Model**: `vuln-assessor:1.0`

**Time**: 10-15 minutes

### Step 1: Immediate response

**Prompt**:

```
A cryptominer (XMRig/MoneroOcean) was found on a production Linux server
at /home/restudio/moneroocean/. It was installed by a contractor with
SSH access. The miner connects to gulf.moneroocean.stream:10032.

Provide step-by-step remediation covering:
1. Immediate containment (stop the miner, block the pool)
2. Evidence preservation (before deleting anything)
3. Eradication (remove all miner artifacts)
4. Access review (the contractor had legitimate access)
5. Prevention (how to prevent recurrence)
```

### Expected output

**Immediate containment:**

```bash
# Kill the miner process
sudo killall xmrig 2>/dev/null
# Or more precisely:
sudo kill $(pgrep -f '/home/restudio/moneroocean/xmrig')

# Block the mining pool at the host firewall
sudo iptables -A OUTPUT -d gulf.moneroocean.stream -j DROP
# Block by IP as well (DNS may not resolve after block)
sudo iptables -A OUTPUT -d 199.247.0.216 -j DROP

# Verify the process is dead
pgrep xmrig  # should return nothing
ss -tnp | grep 10032  # should return nothing
```

**Evidence preservation:**

```bash
# BEFORE deleting anything, preserve evidence
sudo mkdir -p /var/evidence/$(date +%Y%m%d)-cryptominer

# Copy all miner artifacts
sudo cp -r /home/restudio/moneroocean/ /var/evidence/$(date +%Y%m%d)-cryptominer/

# Capture process listing and network state
ps auxf > /var/evidence/$(date +%Y%m%d)-cryptominer/ps-output.txt
ss -tnp > /var/evidence/$(date +%Y%m%d)-cryptominer/network-state.txt
last -i restudio > /var/evidence/$(date +%Y%m%d)-cryptominer/login-history.txt

# Get file hashes
sha256sum /home/restudio/moneroocean/* > \
    /var/evidence/$(date +%Y%m%d)-cryptominer/file-hashes.txt

# Capture SSH auth logs
sudo cp /var/log/auth.log /var/evidence/$(date +%Y%m%d)-cryptominer/
```

**Eradication:**

```bash
# Remove the miner directory
sudo rm -rf /home/restudio/moneroocean/

# Check for cron entries (may not exist but verify)
sudo crontab -u restudio -l 2>/dev/null
crontab -l 2>/dev/null

# Check for systemd user services
ls /home/restudio/.config/systemd/user/ 2>/dev/null

# Check bash history for how it was installed
cat /home/restudio/.bash_history | grep -iE 'wget|curl|git|monero|xmrig|miner'

# Check /tmp and /var/tmp for other copies
find /tmp /var/tmp -name "xmrig*" -o -name "*monero*" 2>/dev/null
```

**Access review:**

```bash
# Revoke the contractor's SSH access immediately
sudo usermod -L restudio           # Lock the account
sudo passwd -l restudio            # Lock the password

# Remove SSH keys
sudo rm -f /home/restudio/.ssh/authorized_keys

# Review who else has access
cat /etc/passwd | grep -v nologin | grep -v /bin/false
sudo cat /etc/ssh/sshd_config | grep -E 'AllowUsers|AllowGroups'

# Audit other contractor accounts for similar activity
for user in $(ls /home/); do
    find /home/$user -name "xmrig*" -o -name "*miner*" -o -name "*monero*" 2>/dev/null
done
```

**Prevention:**

```
1. Implement least-privilege SSH access:
   - Use jump boxes / bastion hosts
   - Time-limited access for contractors (certificate-based with expiry)
   - No direct root or persistent SSH key access

2. Monitor for cryptominer indicators:
   - Deploy the detect-cryptominer.sh script as a cron job (daily)
   - Alert on sustained CPU > 90% for more than 10 minutes
   - Block known mining pool domains at the network firewall/DNS
   - Deploy the YARA rule from Phase 3 in your file integrity monitoring

3. Audit home directories:
   - Regular scans of /home for binaries and config files
   - Alert on new executable files in user home directories

4. Process accounting:
   - Enable process accounting (psacct/acct) to log all commands
   - This creates an audit trail that survives bash_history clearing
```

---

## Bonus: OSINT — Tracing the Beneficiary

Because the artifacts are unsanitized, you can practice **attribution research** using the wallet address and worker name. This is a skill that turns a technical finding into an actionable investigation.

### Step 1: Wallet address lookup

The Monero wallet address from the config:

```
41qbTDmsb6s4RiWgju3kSSNStWYY7mfyoepx4sFmw5um68MxJtnzQQw31bN1Y9hjp4jYwg2WTpeUfaGT375rNvyX4VGNw8Q
```

**Prompt** (to `vuln-assessor:1.0`):

```
I found a cryptominer with this Monero wallet address:
41qbTDmsb6s4RiWgju3kSSNStWYY7mfyoepx4sFmw5um68MxJtnzQQw31bN1Y9hjp4jYwg2WTpeUfaGT375rNvyX4VGNw8Q

And this worker name: "multivendor"

What OSINT steps can I take to trace who controls this wallet?
What does the worker name suggest about the scope of the operation?
```

Key investigation angles:

- **Wallet address search**: Search the address on blockchain explorers, mining pool stats pages, and threat intel databases. The same wallet may appear in other incident reports.
- **Worker name "multivendor"**: This suggests the miner may be deployed across multiple servers or organizations ("multi-vendor"). Search for this worker name in MoneroOcean pool statistics — it may reveal how many machines are mining to this wallet.
- **MoneroOcean pool stats**: MoneroOcean provides public worker statistics. The pool endpoint `gulf.moneroocean.stream` can be queried for information about this wallet's total hashrate and connected workers.
- **Cross-reference with contractor identity**: If you know who the contractor is, the wallet address can be used as evidence linking them to the unauthorized mining activity.

### Step 2: Search for the wallet in other incidents

**Prompt**:

```
If I find this same Monero wallet address in other incident reports or
on other compromised servers, what does that tell me about the attacker?

Wallet: 41qbTDmsb6s4RiWgju3kSSNStWYY7mfyoepx4sFmw5um68MxJtnzQQw31bN1Y9hjp4jYwg2WTpeUfaGT375rNvyX4VGNw8Q
Worker: multivendor
```

The model should explain that reuse of the same wallet across multiple compromises indicates a **systematic operation** rather than a one-off opportunistic act, strengthening the case for deliberate insider abuse.

---

## Lessons from this incident

This exercise teaches something the other exercises don't: **not every threat is sophisticated**. The key takeaways:

1. **Insider threats use legitimate access**. No exploit, no vulnerability, no zero-day. Just SSH and a downloaded binary.

2. **Open-source tools are double-edged**. XMRig is legitimate software. It won't trigger traditional malware signatures. Detection must be based on behavior and context, not signatures alone.

3. **Configuration files are evidence goldmines**. The `config.json` told us the pool, wallet, worker name, and CPU allocation. The `config_background.json` told us it was calibrated for this specific hardware. The log told us exactly when it started and how many shares were accepted.

4. **`nice` is a red flag in production**. Legitimate production processes don't need to lower their own priority. A `nice` prefix on a binary in a user home directory is suspicious by itself.

5. **Prevention is operational, not technical**. This incident is prevented by access management, monitoring, and auditing -- not by better firewalls or endpoint detection.

---

## Sample analysis report

```markdown
# Analysis Report: Cryptominer — MoneroOcean XMRig

**Date**: 2026-04-XX
**Analyst**: [Your name]
**Artifacts**: miner.sh, config.json, config_background.json, xmrig.log.excerpt
**Models used**: llama3.2:3b (triage), vuln-assessor:1.0 (analyze/detect/remediate)
**Classification**: Insider threat — unauthorized cryptocurrency mining

## Triage
Found XMRig binary and configuration in /home/restudio/moneroocean/.
Launcher script explicitly identifies itself as "Monero miner."
Verdict: UNAUTHORIZED CRYPTOMINER.

## Analysis
- XMRig/6.20.0-mo1 (MoneroOcean fork) installed by contractor
- Pool: gulf.moneroocean.stream:10032 (IP: 199.247.0.216)
- Wallet: 44AFFq5k... (Monero address — contractor's personal wallet)
- Server: Intel Xeon Skylake VM, 4C/4T, 15.3 GB RAM
- Sustained hashrate: ~1100 H/s on rx/0 algorithm
- Running since: 2023-08-23 14:35 UTC
- Two configs: foreground (testing) and background (persistent mining,
  donate-level=0, full algo benchmarks)

## IoCs
| Type | Value |
|------|-------|
| Domain | gulf.moneroocean.stream |
| IP | 199.247.0.216 |
| Port | 10032 |
| Process | xmrig |
| Path | /home/restudio/moneroocean/ |
| Binary | XMRig/6.20.0-mo1 (SHA256: [compute from evidence]) |
| Wallet | 41qbTDmsb6s4RiWgju3kSSNStWYY7mfyoepx4sFmw5um68MxJtnzQQw31bN1Y9hjp4jYwg2WTpeUfaGT375rNvyX4VGNw8Q |

## Detection
- YARA: Cryptominer_XMRig_Config (matches config file patterns)
- Sigma: exercise-cryptominer-001 (process and network detection)
- Shell script: detect-cryptominer.sh (operational audit tool)

## Remediation
- Containment: killed process, blocked pool at firewall
- Evidence preserved to /var/evidence/
- Eradication: removed miner directory, verified no cron/systemd persistence
- Access: locked contractor account, revoked SSH keys
- Prevention: deploy detection script as cron, block mining pools at DNS,
  implement time-limited contractor access with process accounting
```

---

## Your turn

1. Analyze the artifacts without looking at the expected outputs.
2. Pay special attention to the *differences* between `config.json` and `config_background.json` -- what do they reveal about the attacker's workflow?
3. Write your own detection script and compare with the expected output.
4. Think about how you would have prevented this in your own infrastructure.

**Stretch goals**:
- Calculate the approximate Monero earned based on the hashrate and time period (use current XMR mining calculators).
- Write a cron-based monitoring script that alerts when a new executable appears in any `/home/*/` directory.
- Design an SSH access policy that would have prevented this while still allowing contractors to do their legitimate work.
