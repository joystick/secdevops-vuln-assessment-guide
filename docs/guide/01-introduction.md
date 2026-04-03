# Chapter 1: Introduction

## Who this guide is for

You are a **DevOps or SRE engineer** who is comfortable with:

- Command-line tools, shell scripting, and automation
- Package managers (npm, yarn, pnpm) and dependency management
- CI/CD pipelines and build systems
- Container runtimes and infrastructure-as-code

You are **not** expected to have experience with:

- Reverse engineering or disassembly
- Malware analysis or incident response
- Security-specific tooling (YARA, Sigma, Ghidra)
- Low-level binary formats (PE, ELF, Mach-O)

This guide teaches those security skills from the ground up, but always through the lens of your existing DevOps knowledge. You won't become a malware analyst overnight, but you will gain the ability to **understand what a threat does, why it works, and how to detect and remediate it** in your infrastructure.

## What you will learn

By the end of this guide you will be able to:

1. **Apply a repeatable methodology** (TADR: Triage, Analyze, Detect, Remediate) to any suspicious artifact that crosses your desk.
2. **Use local LLMs** (via Ollama) as an analysis assistant, asking the right questions and critically evaluating the answers.
3. **Reverse-engineer binaries** at a functional level using Ghidra or radare2, enough to understand what malware does without needing years of RE experience.
4. **Write detection rules** (YARA, Sigma, WAF rules) from your own analysis, not just copy-paste from advisories.
5. **Integrate security analysis into your DevOps workflows**, from pre-install dependency checks to CI/CD quarantine stages.

## Why air-gapped, why local LLMs

Malware analysis requires isolation. You do not want to:

- Run suspicious code on a networked machine
- Send potentially sensitive artifacts to cloud-based AI services
- Risk accidental C2 callbacks from live samples

An air-gapped laptop with a local LLM gives you a **safe, private, repeatable** analysis environment. The trade-off is constrained hardware (8 GB RAM on an M1 MacBook Air), which means smaller models and sequential workflows. This guide is designed around those constraints.

## The three attack surfaces

This guide covers three categories of threats, ordered by increasing complexity. Each uses the same TADR methodology, so the process reinforces with every exercise.

### Level 1: npm supply chain attacks (Chapter 5)

**What**: Poisoned npm packages that install backdoors via `postinstall` scripts. Recent example: the March 2026 axios compromise where `axios@1.14.1` pulled in `plain-crypto-js@4.2.1`, deploying a cross-platform RAT.

**Why DevOps cares**: You install npm packages every day. Your CI/CD pipeline runs `npm install` on every build. A single poisoned dependency can compromise your entire build and deployment chain.

**Skills practiced**: Dependency tree analysis, script deobfuscation, IoC extraction, YARA/Sigma rule writing.

### Level 2: Binary malware from email and network gear (Chapter 6)

**What**: Executable payloads (PE, ELF, Mach-O) delivered via phishing emails or found on compromised MikroTik routers. These are compiled binaries that require disassembly to understand.

**Why DevOps cares**: You manage the infrastructure these payloads target. Understanding what a RAT does to a system helps you write better detection rules, harden your infrastructure, and respond faster to incidents.

**Skills practiced**: Binary loading in Ghidra/radare2, function-level analysis with LLM assistance, C2 pattern identification, MikroTik-specific remediation.

### Level 3: iOS JavaScript exploit chains (Chapter 7)

**What**: Obfuscated JavaScript payloads that exploit Safari/JavaScriptCore vulnerabilities for remote code execution. Recent example: the DarkSword exploit chain targeting multiple JSC CVEs via watering-hole sites.

**Why DevOps cares**: If you serve web content or manage WAF/CDN infrastructure, you need to recognize exploit payloads in traffic. If your organization's employees are targeted via watering-hole attacks, you need to analyze the JS and write detection rules.

**Skills practiced**: JavaScript deobfuscation, JSC exploit pattern recognition, WAF rule generation, browser-level IoC extraction.

## Prerequisites

Before starting Chapter 3 (Lab Setup), you need:

| Item | Details |
|------|---------|
| **Hardware** | MacBook Air M1 with 8 GB RAM (or equivalent Apple Silicon Mac) |
| **Staging machine** | Any computer with internet access, used to download tools and models before transferring to the air-gapped laptop |
| **USB media** | At least one USB drive (16+ GB recommended), ideally write-protectable |
| **macOS** | macOS Ventura or later (for Metal GPU acceleration with Ollama) |
| **Disk space** | At least 20 GB free on the air-gapped laptop (models are 2-4 GB each) |

Software installation is covered in Chapter 3. No pre-installation required.

## How each exercise works

Every exercise in Chapters 5-7 follows the same structure:

1. **Context**: What this attack surface is and why it matters.
2. **Synthetic artifacts**: Harmless but realistic samples you analyze. These are included in the `exercises/` directory so you never need internet access or real malware.
3. **TADR walkthrough**:
   - **Triage** with a fast model to decide if the artifact is suspicious
   - **Analyze** with a deeper model or RE tool to understand what it does
   - **Detect** by writing YARA rules, Sigma rules, or WAF configurations
   - **Remediate** with containment, eradication, and recovery steps
4. **Expected output**: A sample analysis report showing what a good result looks like.
5. **Your turn**: Space to practice on your own and compare results.

## A note on LLM limitations

Local LLMs are powerful assistants but they are not oracles. Throughout this guide you will learn to:

- **Verify model output** against what you observe in the actual artifact. The model may hallucinate function names, API calls, or IoCs that don't exist.
- **Iterate on prompts** when the first answer is too vague or too confident. The prompt templates in this guide are starting points, not scripts.
- **Use multiple models** for cross-validation. If `phi3:mini` says something is suspicious, ask `llama3.2:3b` for a second opinion.
- **Know when the model can't help**. Some analysis requires manual inspection. The methodology tells you when to rely on the model and when to look at the raw data yourself.

The goal is not to automate security analysis. It is to make you faster and more thorough by having a knowledgeable assistant available in a fully offline environment.
