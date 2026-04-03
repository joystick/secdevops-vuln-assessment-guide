# Exercise Artifacts: npm Supply Chain Attack

These are **synthetic, harmless artifacts** designed to mimic the patterns of a real npm supply chain attack (similar to the March 2026 axios compromise). They are safe to analyze and will not cause any damage.

## What is in this directory

| File | Simulates | Real-world equivalent |
|------|-----------|----------------------|
| `package.json` | A project that depends on a poisoned package | A repo that pulled `axios@1.14.1` which depended on `plain-crypto-js@4.2.1` |
| `package-lock.json` | The resolved dependency tree showing the phantom dependency | A lockfile revealing the hidden malicious sub-dependency |
| `postinstall.sh` | The malicious postinstall script from the phantom dependency | The dropper script in `plain-crypto-js@4.2.1` that deployed a cross-platform RAT |

## What makes these realistic

The `postinstall.sh` script demonstrates real attack techniques:

1. **Platform detection** — checks the OS to deploy the right payload
2. **Binary download** — fetches an executable from a remote server
3. **Persistence installation** — creates a launch agent (macOS), systemd service (Linux), or scheduled task (Windows)
4. **Self-cleaning** — removes temporary files and the script itself to hide traces

## What makes these safe

- All URLs point to `example.com` (an IANA-reserved domain that resolves nowhere)
- All file paths use clearly fake names (`/tmp/.not-a-real-payload`)
- The script will fail harmlessly if accidentally executed (no real endpoints)
- Comments throughout mark each section as synthetic

## How to use

Follow the walkthrough in [Chapter 5: Exercise — npm Supply Chain Attack](../../05-exercise-npm-supply-chain.md). Feed these files to your Ollama models and practice the TADR loop.
