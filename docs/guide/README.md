# SecDevOps Vulnerability Assessment Guide

A practical, hands-on guide for DevOps engineers to build security vulnerability assessment skills using an air-gapped MacBook Air M1 (8 GB), local LLMs via Ollama, and reverse-engineering tools.

## How to use this guide

Work through the chapters in order. Chapters 1-2 establish the methodology. Chapters 3-4 set up your lab. Chapters 5-7 are progressive exercises that apply the methodology to increasingly complex attack surfaces. Chapter 8 shows how to integrate everything into your production workflows.

Every exercise follows the same **TADR loop** (Triage, Analyze, Detect, Remediate) so the process becomes muscle memory regardless of the threat type.

## Table of contents

| # | Chapter | Description |
|---|---------|-------------|
| 1 | [Introduction](01-introduction.md) | Who this guide is for, what you'll learn, prerequisites, and the three attack surfaces covered |
| 2 | [TADR Methodology](02-tadr-methodology.md) | The Triage-Analyze-Detect-Remediate loop explained with concrete input/output examples |
| 3 | [Lab Setup](03-lab-setup.md) | Installing Ollama, models, Ghidra, radare2, and GhidrOllama on an air-gapped M1 MacBook Air |
| 4 | [Air-Gap Operations](04-airgap-operations.md) | Checklists for safely transferring artifacts to/from the air-gapped laptop |
| 5 | [Exercise: npm Supply Chain Attack](05-exercise-npm-supply-chain.md) | TADR walkthrough analyzing a poisoned npm package (easiest) |
| 6 | [Exercise: Binary Malware RE](06-exercise-binary-malware.md) | TADR walkthrough reverse-engineering a suspicious binary from email or MikroTik (medium) |
| 7 | [Exercise: iOS JavaScript Exploits](07-exercise-ios-js-exploits.md) | TADR walkthrough analyzing obfuscated Safari/JSC exploit payloads (hardest) |
| 8 | [Operationalizing in CI/CD](08-operationalizing-cicd.md) | Integrating TADR into your DevOps pipeline: pre-install scanning, quarantine, detection deployment |

## Appendices

| Resource | Description |
|----------|-------------|
| [Prompt Library](templates/prompts.md) | All prompt templates organized by TADR phase and attack surface |
| [Modelfiles](templates/) | Custom Ollama Modelfiles for security-focused analysis |
| [Exercise Artifacts](exercises/) | Synthetic samples for hands-on practice |

## Hardware and software

- **Hardware**: MacBook Air M1, 8 GB RAM, air-gapped (no network)
- **LLM runtime**: Ollama with Metal acceleration
- **Models**: `llama3.2:3b`, `phi3:mini`, `gemma3:4b`, custom `vuln-assessor`
- **RE tools**: Ghidra + GhidrOllama, radare2/rizin (lightweight alternative)
- **Transfer**: One-way USB from staging machine to air-gapped laptop
