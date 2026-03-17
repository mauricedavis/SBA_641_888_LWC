# Push to GitHub — Step-by-Step

Run these commands from `C:\Users\MauriceJDavis\SBA_641_888_LWC` in PowerShell or Git Bash:

## First-time setup (new repo)

```powershell
# Clone the repo (if not already done)
git clone https://github.com/mauricedavis/SBA_641_888_LWC.git
cd SBA_641_888_LWC

# Copy all files from this zip/download into the folder, then:
git add -A
git commit -m "feat: initial LWC refactor scaffold with all bug fixes

- SBA641_XMLBatch: fix race multi-value, country normalization, ethnicity correction
- SBA888_XMLBatch: fix critical multi-chunk XML root tag bug + missing Quarter_Year filter
- NexusValidationService: XSD-compliant upstream validation
- SBA641NormalizationHelper: race split/dedup/translate, country, ethnicity, phone
- SBA888NormalizationHelper: state expansion, topic/format translations, partner codes
- SBA641ReportController + SBA888ReportController: AuraEnabled wrappers for LWC
- sba641ReportingWizard + sba888ReportingWizard: 4-step LWC wizard UI
- nexusReportValidationPanel + nexusReportProgressTracker: shared child components
- README.md: full architecture, XSD compliance notes, deployment guide"

git push origin main
```

## Subsequent updates

```powershell
git add -A
git commit -m "your message here"
git push origin main
```

## Branch strategy (recommended)

```powershell
# Create a feature branch for Phase 2 work
git checkout -b feature/phase2-shared-services
# ... develop ...
git push origin feature/phase2-shared-services
# Then open a PR on GitHub
```

## Sync with sandbox after org changes

```powershell
sf project retrieve start --source-dir force-app --target-org fullsb
git add -A
git commit -m "chore: retrieve latest from fullsb sandbox"
git push origin main
```
