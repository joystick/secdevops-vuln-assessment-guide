# Exercise Artifacts: Cryptominer Detection (Based on a Real Incident)

These artifacts are **sanitized versions of a real cryptominer** that was installed on a production server by a contractor. The wallet address and pool have been replaced with synthetic values, but the file structure, configuration patterns, and operational behavior are authentic.

This is not a theoretical exercise. This happened.

## What is in this directory

| File | Simulates | Origin |
|------|-----------|--------|
| `miner.sh` | The launcher script that checks for existing instances | Sanitized from the real incident |
| `config.json` | XMRig foreground config with pool and wallet | Sanitized from the real incident |
| `config_background.json` | XMRig background config with algo benchmarks | Sanitized from the real incident |
| `xmrig.log.excerpt` | First ~100 lines of the real miner log showing startup, calibration, and pool connection | Sanitized from the real incident |

## What happened in the real incident

1. A contractor with SSH access to a production server installed the MoneroOcean fork of XMRig
2. The miner was placed in `/home/<user>/moneroocean/` -- not hidden, but in a user directory that wasn't routinely audited
3. Two configurations were used: foreground (for testing) and background (for persistent mining)
4. The miner ran on all 4 CPU cores of an Intel Xeon VM at ~1100 H/s
5. It connected to `gulf.moneroocean.stream:10032` and mined to the contractor's personal wallet
6. The `miner.sh` script used `nice` to lower CPU priority and `pidof` to prevent duplicate instances

## What was sanitized

- The Monero wallet address has been replaced with an obviously fake one
- The worker password has been changed
- The home directory username has been changed
- Server hostname references in the log have been removed
- The actual `xmrig` binary is NOT included (8.7 MB, and distributing mining binaries is unnecessary)

## Why this matters for DevOps

This is not a sophisticated attack. There was no exploit, no vulnerability, no zero-day. A trusted insider with legitimate SSH access simply installed a miner. This is one of the most common forms of server compromise, and it is often the hardest to detect because:

- The miner uses legitimate tools (XMRig is open source)
- CPU usage may be attributed to normal workload
- The files are in a user home directory, not in system paths
- No alerts fire because no "malware" signatures match

The TADR methodology applies even when the threat is an insider, not an external attacker.

## How to use

Follow the walkthrough in [Chapter 9: Exercise -- Cryptominer Detection](../../09-exercise-cryptominer.md). Feed these files to your Ollama models and practice the TADR loop.
