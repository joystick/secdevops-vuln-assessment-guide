# Plan: SecDevOps Vulnerability Assessment Guide

> Source: Grill-me session (2026-04-03) + 6 Perplexity research docs in `docs/research/`

## Architectural decisions

Durable decisions that apply across all phases:

- **Audience**: Mid-level DevOps/SRE engineers comfortable with CLI, Docker, CI/CD, npm/yarn. No prior RE or malware analysis experience. RE fundamentals taught to enable root-cause understanding.
- **Methodology**: TADR loop (Triage → Analyze → Detect → Remediate) — the repeatable cycle every exercise follows.
- **Attack surfaces (progressive difficulty)**: (1) npm supply chain, (2) binary malware (email/MikroTik), (3) iOS JavaScript exploits.
- **Hardware target**: Air-gapped MacBook Air M1, 8 GB RAM, no network.
- **Model stack**: `llama3.2:3b` (general reasoning), `phi3:mini` (code/JS focus), `gemma3:4b` (fast triage), plus custom `vuln-assessor` Modelfile on `llama3.2:3b`.
- **RE tooling**: Ghidra (sequential workflow — close before running Ollama) + radare2/rizin (lightweight, runs alongside Ollama). Reader chooses.
- **Ghidra-LLM bridge**: GhidrOllama (Python script). GhidraMCP out of scope (appendix mention only).
- **Exercise artifacts**: Synthetic, harmless samples committed to `docs/guide/exercises/`. No real malware in the repo.
- **Exercise output**: Each exercise produces an analysis report + detection rules (YARA/Sigma) + remediation steps.
- **File structure**:
  ```
  docs/guide/
  ├── README.md                  # Main guide entry point with full TOC
  ├── 01-introduction.md
  ├── 02-tadr-methodology.md
  ├── 03-lab-setup.md
  ├── 04-airgap-operations.md
  ├── 05-exercise-npm-supply-chain.md
  ├── 06-exercise-binary-malware.md
  ├── 07-exercise-ios-js-exploits.md
  ├── 08-operationalizing-cicd.md
  ├── exercises/
  │   ├── npm-supply-chain/       # Synthetic postinstall scripts, package.json
  │   ├── binary-malware/         # Synthetic C binary source + compiled artifacts
  │   └── ios-js-exploits/        # Synthetic obfuscated JS payloads
  └── templates/
      ├── vuln-assessor.Modelfile
      ├── ios-js-re.Modelfile
      ├── supplychain.Modelfile
      └── prompts.md              # Consolidated prompt library
  ```

---

## Phase 1: TADR Methodology + Guide Skeleton

**User stories**: As a DevOps engineer, I need a systematic framework for assessing security threats so I don't rely on ad-hoc intuition. As a reader, I need to understand the guide's structure before diving in.

### What to build

Create the `docs/guide/` directory structure and write two complete chapters:

**01-introduction.md** — Who this guide is for, what they'll learn, hardware/software prerequisites, and the three attack surfaces covered in progressive difficulty. Set expectations: this is hands-on methodology, not theory.

**02-tadr-methodology.md** — The TADR loop explained in detail:
- **Triage**: Is this artifact suspicious? What category (dependency, binary, JS payload)? Which model to use? Decision tree for routing artifacts to the right analysis path.
- **Analyze**: What does it actually do? Deobfuscation, decompilation, LLM-assisted explanation. How to ask the right questions of the model.
- **Detect**: Translate analysis into machine-readable detection: YARA rules, Sigma rules, IoC lists, log queries. Template-driven output.
- **Remediate**: Containment (quarantine, rollback), eradication (remove persistence), recovery (verify clean state), and lessons-learned (update models/prompts).

Each phase should include a "what good looks like" example showing expected input/output.

**README.md** — Full table of contents linking all chapters, with one-line descriptions. This is the guide's landing page.

### Acceptance criteria

- [ ] `docs/guide/` directory structure exists matching the architectural decision
- [ ] `README.md` has complete TOC with links to all 8 chapters (even if most are placeholders)
- [ ] `01-introduction.md` defines audience, prerequisites, scope, and progressive difficulty path
- [ ] `02-tadr-methodology.md` explains all 4 phases with concrete examples of input → output for each
- [ ] TADR loop is described generically enough to apply to all three attack surfaces
- [ ] No tooling-specific instructions yet (that's Phase 2) — methodology stands on its own

---

## Phase 2: Lab Setup + Air-Gap Operations

**User stories**: As a DevOps engineer, I need step-by-step instructions to set up an air-gapped M1 MacBook Air as a security analysis lab. As a practitioner, I need checklists to safely transfer artifacts in and out.

### What to build

**03-lab-setup.md** — Complete setup guide for the analysis environment:
- Installing Ollama on macOS (M1 Metal acceleration). Offline installation path (staging machine → USB → air-gapped laptop).
- Pulling and transferring 3 models: `llama3.2:3b`, `phi3:mini`, `gemma3:4b`. Disk space requirements, verification commands.
- Building the custom `vuln-assessor` Modelfile. Testing with a smoke-test prompt.
- Installing Ghidra (JDK dependency, offline installer). Memory tuning for 8 GB constraint.
- Installing radare2/rizin as the lightweight alternative. When to use which.
- Installing GhidrOllama (copy script + utils, configure Ollama URL).
- Verification checklist: every tool responds correctly.

**04-airgap-operations.md** — Operational discipline for the air-gapped workflow:
- What to download on the staging machine (models, tools, updates) and how to verify checksums.
- USB hygiene: write-protected media, one-way transfer, never plug air-gapped USB back into networked machines.
- BIOS-level network disable (WiFi, Bluetooth).
- What goes IN to the air-gapped machine (samples, tools, model updates).
- What NEVER comes OUT (analysis results stay on-device or go via secure reporting channel, never via the same USB).
- Checklist format for each transfer operation.

**templates/** — Create the Modelfile templates:
- `vuln-assessor.Modelfile` (general security assessment on llama3.2:3b)
- `supplychain.Modelfile` (npm/supply-chain focus)
- `ios-js-re.Modelfile` (JavaScript/iOS exploit focus)

### Acceptance criteria

- [ ] `03-lab-setup.md` covers Ollama, 3 models, custom Modelfile, Ghidra, radare2, GhidrOllama — all with offline install paths
- [ ] Reader can follow the chapter and have a working lab without internet access
- [ ] `04-airgap-operations.md` has actionable checklists (not just prose)
- [ ] USB hygiene, BIOS network disable, and checksum verification are explicitly covered
- [ ] All 3 Modelfile templates exist in `docs/guide/templates/` and are syntactically valid
- [ ] Memory management addressed: when to run Ghidra vs Ollama sequentially on 8 GB

---

## Phase 3: Exercise 1 — npm Supply Chain Attack (TADR)

**User stories**: As a DevOps engineer, I need to practice identifying and analyzing poisoned npm packages using the TADR loop so I can protect my CI/CD pipeline.

### What to build

**Synthetic artifacts** in `docs/guide/exercises/npm-supply-chain/`:
- A fake `package.json` with a suspicious dependency (mimicking the axios → plain-crypto-js pattern).
- A fake malicious `postinstall.sh` script that simulates: downloading a binary, creating persistence (launchd plist / systemd service / registry key), and self-cleaning. Clearly commented as synthetic, all URLs are `example.com`, no actual payloads.
- A `README.md` in the exercise directory explaining what each file represents.

**05-exercise-npm-supply-chain.md** — Full TADR walkthrough:
- **Triage**: Given a `package-lock.json`, use `phi3:mini` to spot suspicious dependencies. Prompt template provided. Expected output: "these packages look suspicious because..."
- **Analyze**: Feed the `postinstall.sh` to `vuln-assessor` model. Prompt template for deep analysis. Expected output: plain-English explanation of what the script does, what artifacts it drops.
- **Detect**: Ask the model to generate YARA rules matching the dropper script's patterns, Sigma rules for log detection (process creation, file drops), and IoC list (hashes, paths, fake domains). Prompt template provided.
- **Remediate**: Ask the model for containment commands (kill persistence, remove dropped files) for macOS, Linux, and Windows. Prompt template provided.
- **Expected output section**: A complete sample analysis report showing what a good exercise completion looks like.

### Acceptance criteria

- [ ] Synthetic `package.json` and `postinstall.sh` are realistic but clearly harmless
- [ ] Exercise follows all 4 TADR phases with explicit prompt templates for each
- [ ] Each phase shows the expected model output (what good looks like)
- [ ] Reader produces: analysis report, YARA rule, Sigma rule, remediation commands
- [ ] Exercise is self-contained — no internet, no real malware, just the synthetic artifacts + Ollama
- [ ] Prompt templates reference the correct models from the stack (phi3:mini for triage, vuln-assessor for analysis/detect/remediate)

---

## Phase 4: Exercise 2 — Binary Malware RE (TADR)

**User stories**: As a DevOps engineer, I need to practice reverse-engineering suspicious binaries from email or MikroTik routers so I can understand what they do and write detection rules.

### What to build

**Synthetic artifacts** in `docs/guide/exercises/binary-malware/`:
- A simple C source file (`fake-rat.c`) that mimics C2-like behavior: opens a socket to `example.com:4444`, reads commands, writes to a log file, creates a persistence mechanism. Clearly synthetic, compiles but connects nowhere real.
- Pre-compiled binaries (or build instructions) for macOS ARM64. Alternatively, just the source + Makefile so the reader compiles it on the air-gapped laptop.
- A fake MikroTik `.rsc` RouterOS script that adds suspicious firewall rules and scheduled scripts (mimicking real MikroTik compromises).
- A `README.md` explaining each artifact.

**06-exercise-binary-malware.md** — Full TADR walkthrough:
- **Triage**: Given a suspicious binary or `.rsc` file, use `llama3.2:3b` to do initial assessment. "Is this worth deeper analysis?"
- **Analyze (two paths)**:
  - **Ghidra path**: Load binary in Ghidra, export decompiled functions to text, close Ghidra, feed to `vuln-assessor` via GhidrOllama workflow. Annotate functions, identify C2 patterns.
  - **radare2 path**: Use `r2` CLI to disassemble, pipe output to Ollama. Lighter, runs concurrently.
  - For the `.rsc` script: paste directly into Ollama chat, ask for explanation.
- **Detect**: Generate YARA rules for the binary, Sigma rules for process/network behavior, IoC extraction (strings, IPs, file paths).
- **Remediate**: Containment and eradication steps for macOS/Linux. MikroTik-specific remediation (RouterOS commands to undo malicious changes).
- **Expected output section**.

### Acceptance criteria

- [ ] Synthetic C source is realistic (socket, persistence, command loop) but harmless (example.com, no actual payload)
- [ ] MikroTik `.rsc` script is realistic but clearly annotated as synthetic
- [ ] Both Ghidra (sequential) and radare2 (concurrent) workflows are documented
- [ ] GhidrOllama integration is shown step-by-step for the Ghidra path
- [ ] Exercise follows all 4 TADR phases
- [ ] Reader produces: analysis report, YARA rule, Sigma rule, MikroTik remediation commands
- [ ] Memory management guidance: when to close Ghidra before running Ollama

---

## Phase 5: Exercise 3 — iOS JavaScript Exploit Analysis (TADR)

**User stories**: As a DevOps engineer, I need to recognize and analyze JavaScript-based exploit payloads (e.g., Safari/JSC chains) so I can write WAF rules and detection logic for watering-hole attacks.

### What to build

**Synthetic artifacts** in `docs/guide/exercises/ios-js-exploits/`:
- An obfuscated JavaScript file (`fake-jsc-exploit.js`) that mimics exploit patterns: browser fingerprinting, `ArrayBuffer`/`TypedArray` manipulation, hex-encoded shellcode-like arrays, `eval`/`atob` chains. All fake — no actual exploit, just the patterns.
- A "deobfuscated" version of the same file for comparison.
- A `README.md` explaining what real JSC exploits look like vs. this synthetic version.

**07-exercise-ios-js-exploits.md** — Full TADR walkthrough:
- **Triage**: Given a suspicious JS file from a reported watering-hole site, use `phi3:mini` for quick pattern scan. "Does this look like an exploit?"
- **Analyze**: Feed the JS (both obfuscated and deobfuscated versions) to `ios-js-re` custom model. Prompt templates for: identifying JSC-specific primitives, spotting ROP-like gadget construction, recognizing shellcode arrays.
- **Detect**: Generate WAF rules (ModSecurity/nginx), log-based detection patterns, URL-blocking recommendations. Prompt templates provided.
- **Remediate**: Browser/device-level mitigations, network-level blocking, incident response steps for compromised endpoints.
- **Expected output section**.

### Acceptance criteria

- [ ] Synthetic JS file has realistic exploit-like patterns but is completely inert
- [ ] Both obfuscated and deobfuscated versions provided for learning
- [ ] Exercise follows all 4 TADR phases
- [ ] Reader produces: analysis report, WAF rules, log detection patterns, remediation steps
- [ ] Explains the difference between this synthetic exercise and real JSC exploit chains (DarkSword etc.)
- [ ] Prompt templates reference `phi3:mini` for triage and `ios-js-re` Modelfile for deep analysis

---

## Phase 6: Operationalizing in CI/CD + Appendices

**User stories**: As a DevOps engineer, I need to integrate what I've learned into my real CI/CD pipeline so security analysis becomes part of my workflow, not a separate activity.

### What to build

**08-operationalizing-cicd.md** — How to take the TADR methodology from the air-gapped lab into production DevOps:
- **Pre-install dependency scanning**: Using Ollama as a local check in CI before `npm install`. Example: a shell script or CI stage that extracts `postinstall` scripts from new/updated dependencies and runs them through the supply-chain Modelfile.
- **Quarantine stage**: If a dependency is flagged, automatically quarantine the build artifact and copy suspicious packages to the analysis queue (air-gapped laptop or dedicated analysis environment).
- **Detection rule deployment**: How to take YARA/Sigma rules generated during exercises and deploy them to your security stack (EDR, SIEM, WAF).
- **Model update workflow**: How to periodically update Ollama models and Modelfiles as new threats emerge. Staging machine pulls updates, you verify, transfer via USB.
- **Feedback loop**: How exercise findings feed back into better prompts, updated Modelfiles, and refined detection rules.

**Appendices** (add to `templates/` and consolidate):
- `prompts.md` — Complete prompt library organized by TADR phase and attack surface. All prompts from the 3 exercises in one reference.
- Modelfile reference — All 3 custom Modelfiles with inline documentation.
- Air-gap transfer checklist — Consolidated from Chapter 4, in quick-reference format.
- Tool quick-reference — Ollama commands, Ghidra shortcuts, radare2 cheat sheet.

### Acceptance criteria

- [ ] CI/CD integration chapter shows concrete examples (shell scripts, CI stage configs) not just concepts
- [ ] Pre-install scanning, quarantine, and detection-rule deployment are all covered
- [ ] Model update workflow addresses the air-gap constraint
- [ ] `prompts.md` consolidates ALL prompt templates from all 3 exercises, organized by TADR phase
- [ ] Appendices are reference-quality: a reader can use them standalone without re-reading the exercises
- [ ] Guide is complete end-to-end: a reader can go from zero to operational SecDevOps practice
