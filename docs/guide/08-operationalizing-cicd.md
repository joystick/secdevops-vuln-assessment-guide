# Chapter 8: Operationalizing in CI/CD

You have the methodology (TADR), the lab (air-gapped M1), and hands-on experience from three exercises. This chapter connects everything to your production DevOps workflow so security analysis is part of how you work, not an occasional side activity.

## 8.1 Pre-install dependency scanning

The npm supply chain exercise (Chapter 5) showed how a poisoned package can slip into your dependency tree. This section automates that triage step in CI.

### The scan script

This shell script extracts `postinstall`/`preinstall` scripts from new or updated dependencies and flags suspicious patterns. It runs without Ollama — it is a static pattern check that can run in any CI environment.

```bash
#!/usr/bin/env bash
# scan-postinstall.sh — Flag suspicious lifecycle scripts in npm dependencies
# Run in CI after npm install (or with --ignore-scripts + manual review)
set -euo pipefail

SUSPICIOUS=0
REPORT=""

# Find all package.json files in node_modules that have lifecycle scripts
find node_modules -maxdepth 3 -name "package.json" -print0 | \
while IFS= read -r -d '' pkg; do
    # Extract postinstall and preinstall scripts
    scripts=$(jq -r '.scripts // {} | to_entries[] |
        select(.key | test("postinstall|preinstall|install")) |
        "\(.key): \(.value)"' "$pkg" 2>/dev/null)

    if [ -n "$scripts" ]; then
        pkg_name=$(jq -r '.name // "unknown"' "$pkg" 2>/dev/null)
        pkg_version=$(jq -r '.version // "unknown"' "$pkg" 2>/dev/null)

        # Check for known-bad patterns
        if echo "$scripts" | grep -qiE 'curl|wget|http|eval|exec|child_process|\.sh\b'; then
            echo "WARNING: ${pkg_name}@${pkg_version}"
            echo "  Scripts: ${scripts}"
            echo "  Path: ${pkg}"
            echo ""
            SUSPICIOUS=1
        fi
    fi
done

if [ "$SUSPICIOUS" -eq 1 ]; then
    echo "=========================================="
    echo "SUSPICIOUS LIFECYCLE SCRIPTS DETECTED"
    echo "Review the packages above before proceeding."
    echo "=========================================="
    exit 1
fi

echo "No suspicious lifecycle scripts found."
exit 0
```

### CI integration (GitHub Actions example)

```yaml
# .github/workflows/dependency-scan.yml
name: Dependency Security Scan
on:
  pull_request:
    paths:
      - 'package.json'
      - 'package-lock.json'

jobs:
  scan-postinstall:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies (skip lifecycle scripts)
        run: npm ci --ignore-scripts

      - name: Scan for suspicious lifecycle scripts
        run: bash scripts/scan-postinstall.sh

      - name: Check for new/changed dependencies
        run: |
          # Compare lockfile against main branch
          git diff origin/main -- package-lock.json | \
            grep -E '^\+.*"resolved"' | \
            grep -v '^\+\+\+' > /tmp/new-deps.txt || true

          if [ -s /tmp/new-deps.txt ]; then
            echo "New or changed dependencies detected:"
            cat /tmp/new-deps.txt
            echo ""
            echo "Review these packages before merging."
          fi
```

### Ollama-assisted deep scan (on the air-gapped laptop)

When the CI scan flags a package, the deep analysis happens on the air-gapped laptop:

1. CI quarantines the build (fails the check)
2. DevOps engineer extracts the flagged package(s) to USB
3. On the air-gapped laptop, runs the TADR loop from Chapter 5
4. Results (safe/malicious + detection rules) go back via USB-OUT

This is a manual step by design — you do not want an LLM making automated allow/deny decisions on dependencies in CI.

## 8.2 Quarantine stage

When a dependency or artifact is flagged, it needs to be isolated before anyone investigates.

### Quarantine directory structure

```
/var/quarantine/
├── 2026-04-03_axios-suspicious/
│   ├── manifest.txt          # what was flagged, by whom, why
│   ├── package.json           # from the flagged build
│   ├── package-lock.json
│   └── node_modules/
│       └── plain-crypto-js/   # the suspicious package only
├── 2026-04-05_email-binary/
│   ├── manifest.txt
│   └── invoice.exe            # suspicious email attachment
└── README.md                  # quarantine procedures
```

### Quarantine script

```bash
#!/usr/bin/env bash
# quarantine.sh — Isolate a suspicious artifact for analysis
set -euo pipefail

QUARANTINE_DIR="/var/quarantine"
CASE_NAME="${1:?Usage: quarantine.sh <case-name> <artifact-path>}"
ARTIFACT="${2:?Usage: quarantine.sh <case-name> <artifact-path>}"
DATE=$(date +%Y-%m-%d)
CASE_DIR="${QUARANTINE_DIR}/${DATE}_${CASE_NAME}"

mkdir -p "$CASE_DIR"

# Copy artifact
cp -r "$ARTIFACT" "$CASE_DIR/"

# Create manifest
cat > "${CASE_DIR}/manifest.txt" << EOF
Quarantine Manifest
===================
Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Case: ${CASE_NAME}
Flagged by: $(whoami)@$(hostname)
Artifact: ${ARTIFACT}
SHA256: $(shasum -a 256 "$ARTIFACT" | awk '{print $1}')

Reason for quarantine:
<fill in manually>

Analysis status: PENDING
EOF

echo "Quarantined: ${CASE_DIR}"
echo "Next: transfer to air-gapped laptop for TADR analysis"
```

## 8.3 Detection rule deployment

Exercises generate YARA rules, Sigma rules, and WAF configurations. Here is how to deploy them.

### YARA rules

```bash
# Organize rules by source
~/detection-rules/
├── yara/
│   ├── supply-chain/
│   │   └── npm-plain-crypto-js.yar
│   ├── binary-malware/
│   │   └── rat-fake-update-helper.yar
│   └── README.md
```

Deploy to your scanning infrastructure:

```bash
# Test rules against a known-good and known-bad sample
yara ~/detection-rules/yara/supply-chain/npm-plain-crypto-js.yar \
    /path/to/quarantined/postinstall.sh

# Deploy to CI scanning (example: integrate with osquery or YARA scanner)
# Copy rules to the scanning host
scp -r ~/detection-rules/yara/ scanner-host:/etc/yara/custom-rules/
```

### Sigma rules

```bash
# Convert Sigma to your SIEM's query language
# Using sigmac or sigma-cli:
sigma convert -t splunk -p sysmon \
    ~/detection-rules/sigma/binary-malware-001.yml

# Or for Elastic:
sigma convert -t elasticsearch -p ecs-zeek \
    ~/detection-rules/sigma/binary-malware-001.yml
```

### WAF rules

```bash
# Deploy ModSecurity rules
sudo cp ~/detection-rules/waf/jsc-exploit.conf \
    /etc/modsecurity/rules/custom/

# Test with nginx -t before reload
sudo nginx -t && sudo systemctl reload nginx
```

## 8.4 Model update workflow

Your Ollama models and Modelfiles should improve over time as you encounter new threats.

### When to update

- New CVE or attack technique that your current system prompts do not cover
- Model output quality degrades (hallucinations increase, rules become too generic)
- New Ollama model release that significantly improves code understanding

### Update process

```
On staging machine (internet-connected):
1. Pull updated model: ollama pull llama3.2:3b
2. Test with a known prompt from your exercises
3. Compare output to previous version
4. If quality is equal or better: package for transfer
5. If quality is worse: stay on current version

On air-gapped laptop:
1. Back up current models: cp -r ~/.ollama/models ~/.ollama/models-backup
2. Transfer and install updated models (Chapter 4 procedure)
3. Re-run one prompt from each exercise chapter
4. Verify output quality matches or exceeds previous
5. If worse: restore from backup
```

### Modelfile evolution

As you encounter real incidents, update your Modelfiles:

```dockerfile
# Before: generic supply chain prompt
SYSTEM """You analyze npm packages for supply chain attacks."""

# After: enriched with real-world patterns you have seen
SYSTEM """You analyze npm packages for supply chain attacks.
Known patterns to check for:
- Phantom dependencies added to popular packages (e.g., plain-crypto-js in axios)
- Postinstall scripts that curl|wget remote binaries
- Self-deleting scripts that replace themselves with benign stubs
- Typosquatted package names (plain-crypto-js vs crypto-js)
- Cross-platform persistence: LaunchAgent, systemd, schtasks
When you see these patterns, flag them explicitly and suggest specific IoCs."""
```

Rebuild after changes:

```bash
ollama create supplychain:1.1 -f ./supplychain.Modelfile
# Note: version bump (1.0 -> 1.1), keep old version until verified
```

## 8.5 Feedback loop

The TADR methodology is a loop. After every exercise and every real incident, feed lessons back into the system.

```
                    +------------------+
                    |  New threat or   |
                    |  incident occurs |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Run TADR loop   |
                    |  (Chapters 5-7)  |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
     +--------v---+  +------v------+  +----v--------+
     | Update     |  | Update      |  | Update      |
     | Modelfiles |  | detection   |  | CI scripts  |
     | & prompts  |  | rules       |  | & checklists|
     +--------+---+  +------+------+  +----+--------+
              |              |              |
              +--------------+--------------+
                             |
                    +--------v---------+
                    |  Better prepared |
                    |  for next threat |
                    +------------------+
```

### Concrete feedback actions

| After exercise/incident | Update target | Example change |
|------------------------|---------------|----------------|
| Triage missed a suspicious pattern | Modelfile system prompt | Add the pattern as a known example |
| Model hallucinated a non-existent API | Prompt template | Add "verify against actual imports" instruction |
| YARA rule had false positives | Rule conditions | Tighten string matching or add file-type constraints |
| Remediation missed a persistence mechanism | Remediation checklist | Add the missing platform/mechanism |
| New attack technique emerged | Exercise set | Create a new synthetic artifact demonstrating it |
| CI scan missed a malicious package | scan-postinstall.sh | Add the missed pattern to grep list |

## 8.6 Maturity levels

Not every team needs everything at once. Adopt incrementally:

### Level 1: Manual (start here)

- Air-gapped laptop set up (Chapter 3)
- TADR exercises completed (Chapters 5-7)
- Detection rules written but deployed manually
- CI has basic `npm audit` / `npm ci --ignore-scripts`

### Level 2: Semi-automated

- CI pre-install scanning with `scan-postinstall.sh`
- Quarantine directory and process established
- Detection rules deployed to one SIEM/scanner
- Modelfiles updated after each real incident

### Level 3: Integrated

- CI/CD pipeline includes dependency scanning, quarantine, and flagging
- YARA/Sigma rules deployed across EDR, SIEM, and WAF
- Regular model updates on a schedule (monthly or after major incidents)
- Team trained on TADR methodology (this guide used as onboarding material)
- Feedback loop formalized: incidents produce updated rules within 48 hours

## Next steps

You have completed the guide. You now have:

- A **repeatable methodology** (TADR) for any suspicious artifact
- An **air-gapped analysis lab** with local LLMs and RE tools
- **Hands-on experience** across three attack surfaces
- **CI/CD integration** to make security analysis part of your daily workflow
- A **feedback loop** to continuously improve your tools and processes

Continue practicing. The exercises are starting points — modify the artifacts, create new ones, and run the loop on real samples (following Chapter 4 procedures) as your confidence grows.
