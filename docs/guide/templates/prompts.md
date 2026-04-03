# Prompt Library -- SecDevOps Vulnerability Assessment

All prompt templates from the guide, organized by TADR phase and attack surface. Copy-paste these into your Ollama sessions.

## How to use

1. Pick the section matching your artifact type and TADR phase
2. Replace `<paste ... here>` with your actual artifact content
3. Use the recommended model shown in parentheses
4. Compare output against the expected patterns described in the exercise chapters

---

## Triage Prompts

### T1. npm dependency tree triage (`phi3:mini`)

```
I am reviewing the dependency tree of an npm project. Examine this
package-lock.json and tell me:

1. Are there any packages that look like they don't belong?
2. Are there any packages with hasInstallScript: true?
3. Is the dependency chain from axios to its sub-dependencies normal?

Focus on anything unexpected. Be specific.

---
<paste package-lock.json contents here>
```

### T2. Binary metadata triage (`llama3.2:3b`)

```
I extracted the following from a suspicious binary found as an email
attachment. Based on the strings and imports, give me a quick assessment:

1. Is this binary likely malicious?
2. What category of malware does it appear to be?
3. Should I invest time in deep reverse engineering?

--- Strings ---
<paste output from: r2 -q -c "iz" ./binary>

--- Imports ---
<paste output from: r2 -q -c "ii" ./binary>
```

### T3. RouterOS script triage (`llama3.2:3b`)

```
I found this RouterOS script on a MikroTik router during a routine audit.
Give me a quick assessment:

1. Is this configuration script suspicious?
2. What categories of changes does it make?
3. Should I investigate further?

---
<paste RouterOS script contents here>
```

### T4. JavaScript exploit triage (`phi3:mini`)

```
I captured this JavaScript from a website reported as a watering-hole
attack vector. Give me a quick assessment:

1. Does this look like normal website JavaScript or an exploit payload?
2. What specific patterns suggest it is malicious?
3. Should I invest time in full deobfuscation and analysis?

Focus on structural patterns, not line-by-line explanation.

---
<paste first 40-60 lines of the JavaScript here>
```

---

## Analysis Prompts

### A1. npm postinstall script analysis (`supplychain:1.0`)

```
Analyze this postinstall script from the npm package <package-name>.
For each section of the script, explain:

1. What it does in plain English
2. What artifacts it creates on disk
3. What network activity it generates
4. What persistence mechanism it installs

Then provide an overall assessment: is this malicious? What kind of malware is this?

---
<paste postinstall script contents here>
```

### A2. IoC extraction from postinstall (`supplychain:1.0`)

```
Based on your analysis, list all Indicators of Compromise (IoCs) in a
structured format. Include:
- File paths (all platforms)
- Network indicators (domains, URLs)
- Process names
- Persistence artifacts (plist names, service names, task names)
- Behavioral indicators
```

### A3. Binary function analysis — Ghidra export (`vuln-assessor:1.0`)

```
I am reverse-engineering a suspicious binary in Ghidra. Below are the
decompiled functions. For each function:

1. Explain what it does in plain English
2. Identify any IoCs (IPs, ports, file paths, registry keys)
3. Rate its threat level (benign / suspicious / malicious)

Then provide an overall assessment of the binary's purpose and capabilities.

---
<paste decompiled functions here>
```

### A4. Binary function analysis — radare2 disassembly (`vuln-assessor:1.0`)

```
I am reverse-engineering a suspicious binary with radare2. Below is the
disassembly of key functions. For each function:

1. Explain what it does in plain English
2. Identify any IoCs (IPs, ports, file paths)
3. Rate its threat level

Then provide an overall assessment.

---
<paste radare2 disassembly output here>
```

### A5. MikroTik RouterOS deep analysis (`vuln-assessor:1.0`)

```
Analyze this MikroTik RouterOS backdoor script in detail.
For each stage, explain:
1. The technique used
2. The MITRE ATT&CK mapping
3. What evidence it leaves on the router
4. How an admin would notice it during normal operations

---
<paste RouterOS script contents here>
```

### A6. JavaScript deobfuscation — string table (`ios-js-re:1.0`)

```
This JavaScript contains a hex-encoded string array. Decode each entry
and explain what browser API or concept it refers to:

<paste the hex string array here>
```

### A7. JavaScript exploit chain analysis (`ios-js-re:1.0`)

```
Analyze this deobfuscated JavaScript exploit payload stage by stage.
For each stage, explain:

1. What the code does
2. What the REAL exploit equivalent would be (vs. this synthetic version)
3. What IoCs or detection opportunities each stage creates

---
<paste deobfuscated JavaScript here>
```

### A8. Shellcode byte array analysis (`ios-js-re:1.0`)

```
Decode this Uint8Array — are these bytes machine code (ARM64/x86) or
something else? Show the decoded content.

<paste the Uint8Array initialization here>
```

---

## Detection Prompts

### D1. YARA rule — npm dropper (`vuln-assessor:1.0`)

```
Write a YARA rule that detects the postinstall dropper script from
<package-name>. The rule should match on:

- The curl/wget download pattern to <domain>
- The persistence artifact creation (<specific artifact>)
- The self-deletion pattern (rm -f "$0")

Include rule metadata: name, description, author, date.
Make the rule specific enough to avoid false positives on legitimate
postinstall scripts.
```

### D2. YARA rule — binary (`vuln-assessor:1.0`)

```
Write a YARA rule that detects this RAT binary. It should match on:
- The C2 IP (<ip>) and port (<port>)
- The combination of socket + connect + system imports
- The persistence file path pattern (<path>)

Make it work for both Mach-O (macOS) and ELF (Linux) binaries.
Include metadata with description, author, and date.
```

### D3. Sigma rule — process/network behavior (`vuln-assessor:1.0`)

```
Write a Sigma rule that detects the runtime behavior of this malware:
<describe the behavior: outbound connection, persistence creation, etc.>

Format as valid Sigma YAML with title, status, description, logsource,
detection, and level fields.
```

### D4. MikroTik detection checklist (`vuln-assessor:1.0`)

```
Based on this MikroTik backdoor, write:

1. A checklist of RouterOS commands an admin should run to detect each
   stage of this compromise
2. Sigma-style detection logic for syslog events from the router
3. Network-level IoCs that a firewall or IDS upstream of the router
   would catch
```

### D5. WAF rules — JavaScript exploit (`ios-js-re:1.0`)

```
Write ModSecurity WAF rules that detect JavaScript exploit payloads
with these characteristics:

1. Hex-encoded string arrays
2. atob() combined with ArrayBuffer/TypedArray construction
3. Uint8Array initialized with long hex byte sequences
4. Browser fingerprinting patterns (navigator.userAgent version checks)
5. Dynamically constructed callback URLs from hex parts

Provide rules that balance detection with false-positive avoidance.
Include rule IDs, descriptions, and severity levels.
```

### D6. Log detection queries (`vuln-assessor:1.0`)

```
Write 3 one-liner shell commands to check if this specific malware has
been active on a system:

1. Check for the payload file
2. Check for the persistence mechanism
3. Check for network connections to the C2

Target platform: <macOS / Linux / Windows>
```

---

## Remediation Prompts

### R1. Platform-specific remediation (`vuln-assessor:1.0`)

```
Given <malware type> that:
- <behavior 1>
- <behavior 2>
- <behavior 3>

Provide step-by-step remediation commands for <platform(s)>.
Include: containment, eradication, and verification for each.
```

### R2. npm supply chain remediation (`supplychain:1.0`)

```
Given a supply chain attack where <package>@<version> was installed,
provide remediation commands for:

1. Containment (stop the malware from running)
2. Eradication (remove all artifacts: files, persistence, packages)
3. Verification (confirm the system is clean)
4. Prevention (pin dependencies, update lockfile)

Cover macOS, Linux, and Windows.
```

### R3. MikroTik remediation (`vuln-assessor:1.0`)

```
Provide RouterOS commands to fully remediate this MikroTik backdoor.
For each stage of the compromise, show the exact commands to:
1. Undo the malicious change
2. Restore the secure default
3. Verify the fix

Also include post-remediation hardening recommendations.
```

### R4. Watering-hole incident response (`vuln-assessor:1.0`)

```
A watering-hole site is serving a JSC exploit to iOS Safari users.
Provide remediation steps for:

1. Network/infrastructure level (WAF, DNS, proxy)
2. Endpoint level (iOS devices that may have visited the site)
3. Organizational level (communication, monitoring, prevention)
```

### R5. Cryptominer incident remediation (`vuln-assessor:1.0`)

```
A cryptominer (XMRig/MoneroOcean) was found on a production Linux server
at <path>. It was installed by a contractor with SSH access. The miner
connects to <pool>:<port>.

Provide step-by-step remediation covering:
1. Immediate containment (stop the miner, block the pool)
2. Evidence preservation (before deleting anything)
3. Eradication (remove all miner artifacts)
4. Access review (the contractor had legitimate access)
5. Prevention (how to prevent recurrence)
```

---

## Cryptominer-Specific Prompts

### CM1. Miner config analysis (`vuln-assessor:1.0`)

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
<paste config.json contents here>
```

### CM2. Miner config comparison (`vuln-assessor:1.0`)

```
Compare these two XMRig configurations. What is different between the
foreground config and the background config? What does the background
config tell us about the attacker's operational approach?

--- Foreground config ---
<paste config.json>

--- Background config ---
<paste config_background.json>
```

### CM3. Miner log analysis (`vuln-assessor:1.0`)

```
Analyze this XMRig miner log excerpt. Extract:

1. When did the miner start?
2. What hardware is it running on?
3. What algorithms were benchmarked and at what hashrates?
4. When did it connect to the pool and start mining?
5. What was the sustained hashrate?
6. How many shares were accepted?

---
<paste xmrig.log excerpt here>
```

### CM4. Cryptominer YARA rule (`vuln-assessor:1.0`)

```
Write a YARA rule that detects XMRig/MoneroOcean configuration files on
a filesystem. The rule should match on:

1. Mining pool domain patterns (*.moneroocean.stream, etc.)
2. XMRig-specific config keys (algo-perf, randomx, donate-level)
3. Monero wallet address pattern (95-char string starting with 4)

This should detect config files, not the binary itself.
```

---

## Model quick reference

| Model | Best for | Prompt categories |
|-------|----------|-------------------|
| `phi3:mini` | Fast code/JS triage | T1, T4 |
| `gemma3:4b` | Quick pattern-matching | Ad-hoc triage |
| `llama3.2:3b` | General reasoning | T2, T3 |
| `vuln-assessor:1.0` | Deep security analysis | A3, A4, A5, CM1-CM4, D1-D4, D6, R1-R3, R5 |
| `supplychain:1.0` | npm/dependency focus | A1, A2, R2 |
| `ios-js-re:1.0` | JavaScript/iOS exploits | A6, A7, A8, D5, R4 |
