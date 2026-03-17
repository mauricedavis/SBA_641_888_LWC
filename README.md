# SBA 641 & 888 LWC Reporting Refactor

**Michigan SBDC at Grand Valley State University**  
Sandbox org: `michigansbdcatgrandvalleystateuniv--fullsb`  
API Version: 63.0 | Local folder: `C:\Users\MauriceJDavis\SBA_641_888_LWC`

---

## Project Goal

Replace the Flow-triggered batch pipeline for NEXUS 641 (Counseling) and 888 (Training) quarterly reporting with resilient, LWC-driven workflows that **validate and normalize data before XML generation**.

Full architecture details: [`docs/NEXUS_641_888_LWC_Refactor_Plan.docx`](docs/)

---

## What's in This Repo

### Existing Org Classes (source-tracked as-is from sandbox)

| Class | Description |
|---|---|
| `SBA641BatchFlow` | Invocable bridge: Flow → SBA641Batch (data population) |
| `SBA641_XMLBatchFlow` | Invocable bridge: Flow → SBA641_XMLBatch |
| `SBA888BatchFlow` | Invocable bridge: Flow → SBA888Batch (data population) |
| `SBA888_XMLBatchFlow` | Invocable bridge: Flow → SBA888_XMLBatch |
| `SBA641_XMLBatch` | Generates 641 counseling XML — **bugs documented below** |
| `SBA888_XMLBatch` | Generates 888 training XML — **critical bugs documented below** |
| `SBA641_XMLBatchTest` | Test class for 641 XML batch |
| `SBA641_XMLBatch_TEST` | Additional test class for 641 XML batch |
| `SBA888_XMLBatch_TEST` | Test class for 888 XML batch |

### New Classes (refactored — in `force-app/main/default/classes/`)

| Class | Description |
|---|---|
| `NexusValidationService` | Shared XSD-compliant field validation — called before XML generation |
| `SBA641NormalizationHelper` | All 641 normalization: race multi-value, country, ethnicity, phone |
| `SBA888NormalizationHelper` | All 888 normalization: state expansion, topic/format translations |
| `SBA641ReportController` | AuraEnabled controller backing `sba641ReportingWizard` |
| `SBA888ReportController` | AuraEnabled controller backing `sba888ReportingWizard` |
| `SBA641_XMLBatch_REFACTORED` | Refactored 641 batch with all bug fixes applied |
| `SBA888_XMLBatch_REFACTORED` | Refactored 888 batch with all bug fixes applied |

### New LWC Components

| Component | Exposed | Description |
|---|---|---|
| `sba641ReportingWizard` | App Page | 4-step wizard: select → validate → review → generate (641) |
| `sba888ReportingWizard` | App Page | 4-step wizard: select → validate → review → generate (888) |
| `nexusReportValidationPanel` | Child | Shared ERROR/WARNING display panel |
| `nexusReportProgressTracker` | Child | Batch job polling + live progress bar |

---

## Bugs Identified in Existing Code

### 888 — Multi-Chunk XML Root Tag `[P0 — CRITICAL]`
`SBA888_XMLBatch.execute()` emits `<?xml version="1.0"?>` and `<ManagementTrainingReport>` on **every** batch chunk. Any quarter with >200 events produces duplicate XML headers → unparseable by Nexus.  
**Fix:** emit root tag in `start()` only; close it in `finish()` only. See `SBA888_XMLBatch_REFACTORED`.

### 888 — Missing `Quarter_Year__c` Filter `[P0 — CRITICAL]`
`SBA888_XMLBatch.start()` has **no WHERE clause** — every run includes ALL SBA_888_Output__c records from all quarters ever loaded.  
**Fix:** `WHERE Quarter_Year__c = :varQuarterYear` added. See `SBA888_XMLBatch_REFACTORED`.

### 641 — Phone `'9'` Padding `[P1]`
`formatPhoneNumber()` pads short phone numbers with `'9'` to reach 10 digits. Produces fake numbers (e.g., `4165559999`) that fail Nexus schema validation.  
**Fix:** short phones return `null`; `NexusValidationService` flags them as ERRORs upstream. No padding.

### 641 — Race Single-Value Drop `[P1]`
`RaceClientIntake__c` is sourced from `Contact.hed__Race__c` (Multi-Select Picklist, semicolon-delimited). The batch emits only one `<Code>` tag, silently dropping all values after the first semicolon.  
**Fix:** `SBA641NormalizationHelper.getRaceCodes()` splits on `;`, removes space-duplicate artifacts, translates, deduplicates, emits one `<Code>` per value. XSD `maxOccurs="unbounded"` confirmed.

### 641 — Country Pass-Through `[P1]`
Non-standard values (`Wayne`, `Kent`, `Eaton`, `Kalamazoo` — Michigan county names; `48504` — zip code) pass through as-is, failing XSD `CountryList` enum validation.  
**Fix:** `SBA641NormalizationHelper.normalizeCountry()` — any non-blank value → `'United States'`.

### 641 — Ethnicity Incorrect Mapping `[P1]`
`'No'` maps to `'Prefer not to say'`. XSD enum is `'Non Hispanic or Latino'`.  
**Fix:** `normalizeEthnicity()` maps `'No'` → `'Non Hispanic or Latino'`.

### 888 — `<ProgramFormat>` Missing `[P2]`
Sample XML requires both `<ProgramFormat>` (raw value) and `<ProgramFormatType>` (normalized). Original batch only emits `<ProgramFormatType>`.  
**Fix:** Both tags emitted in `SBA888_XMLBatch_REFACTORED`.

---

## XSD Authority

- `SBA_NEXUS_Counseling-2-14.xsd`
- `SBA_NEXUS_Training-2-25-2025.xsd`

Key facts confirmed from XSD review:

**641:**
- `<Race><Code>` has `maxOccurs="unbounded"` → multi-value required
- `<Country><Code>` = full country name (`United States`), NOT 2-letter code
- `<Sex>` replaced `<Gender>` (XSD change #140, Feb 2025)
- `SexualOrientation` fully removed (XSD change #141)
- `<Operation>` element added (change #105) — emit `''` for new submissions
- `<Ethnicity>` enum: `"Non Hispanic or Latino"` (not `"Not Hispanic or Latino"`)

**888:**
- `<ProgramFormat>` (raw) AND `<ProgramFormatType>` (normalized) — both required
- `<OtherAgency>` tag in `<TrainingPartners>` — distinct from `<Other>`
- `<Language>` supports multiple `<Code>` tags

---

## Deployment

```bash
# Authorize sandbox
sf org login web --alias fullsb \
  --instance-url https://michigansbdcatgrandvalleystateuniv--fullsb.sandbox.my.salesforce.com

# Deploy all
sf project deploy start --source-dir force-app --target-org fullsb

# Run tests
sf apex run test --target-org fullsb --test-level RunLocalTests --wait 20
```

Or use the convenience script:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh          # full deploy + test
./scripts/deploy.sh --check  # validate only (no deploy)
```

---

## Phase Plan

| Phase | Work | Status |
|---|---|---|
| 1 — Critical Fixes | 888 root tag bug, 888 filter, 641 phone, 641 race, country, ethnicity | ✅ Done |
| 2 — Shared Services | `NexusValidationService`, normalization helpers | ✅ Done |
| 3 — Controllers | `SBA641ReportController`, `SBA888ReportController` | ✅ Done |
| 4 — LWC | 4 LWC components built and wired | ✅ Done |
| 5 — Integration & UAT | End-to-end sandbox test against real quarter data | 🔜 Next |
| 6 — Retire Flows | Deactivate legacy Flow-triggered batch chains after UAT | 🔜 After UAT |

---

*Michigan SBDC at GVSU | Attain Partners — Attain Managed Services | March 2026*
