# Exercise Artifacts: Cryptominer Detection (Based on a Real Incident)

These artifacts are **unsanitized originals from a real cryptominer** that was installed on a production server by a contractor. The wallet address, worker name, and file paths are preserved as-is — they are evidence that identifies the beneficiary of the attack.

This is not a theoretical exercise. This happened.

## What is in this directory

| File | Simulates | Origin |
|------|-----------|--------|
| `miner.sh` | The launcher script that checks for existing instances | Original from the incident |
| `config.json` | XMRig foreground config with pool and wallet | Original — wallet and worker name preserved |
| `config_background.json` | XMRig background config with algo benchmarks | Original — includes real benchmark data |
| `xmrig.log.excerpt` | First ~100 lines of the real miner log showing startup, calibration, and pool connection | Original — timestamps and pool IPs preserved |

## What happened in the real incident

1. A contractor with SSH access to a production server installed the MoneroOcean fork of XMRig
2. The miner was placed in `/home/<user>/moneroocean/` -- not hidden, but in a user directory that wasn't routinely audited
3. Two configurations were used: foreground (for testing) and background (for persistent mining)
4. The miner ran on all 4 CPU cores of an Intel Xeon VM at ~1100 H/s
5. It connected to `gulf.moneroocean.stream:10032` and mined to the contractor's personal wallet
6. The `miner.sh` script used `nice` to lower CPU priority and `pidof` to prevent duplicate instances

## What is preserved (not sanitized)

The following are **original values** from the incident, preserved intentionally as investigation evidence:

- **Monero wallet address** — identifies who was receiving the mining proceeds
- **Worker password** (`multivendor`) — may link to other compromised machines using the same identity
- **Home directory username** (`restudio`) — the contractor's account on the server
- **Pool IP address** (199.247.0.216) — the MoneroOcean pool endpoint the miner connected to
- **Timestamps** — show exactly when the miner was installed and started operating

The `xmrig` binary itself is available in `docs/research/moneroocean_/` for hash verification and further analysis.

## Why this matters for DevOps

This is not a sophisticated attack. There was no exploit, no vulnerability, no zero-day. A trusted insider with legitimate SSH access simply installed a miner. This is one of the most common forms of server compromise, and it is often the hardest to detect because:

- The miner uses legitimate tools (XMRig is open source)
- CPU usage may be attributed to normal workload
- The files are in a user home directory, not in system paths
- No alerts fire because no "malware" signatures match

The TADR methodology applies even when the threat is an insider, not an external attacker.

## How to use

Follow the walkthrough in [Chapter 9: Exercise -- Cryptominer Detection](../../09-exercise-cryptominer.md). Feed these files to your Ollama models and practice the TADR loop.
