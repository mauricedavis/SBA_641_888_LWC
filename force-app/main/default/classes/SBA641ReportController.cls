/**
 * SBA641ReportController
 * AuraEnabled controller backing sba641ReportingWizard LWC.
 *
 * Full 5-step pipeline:
 *   1. getQuarterDates()  → calculate date range from quarter/year
 *   2. extractSessions()  → SBA641Batch: Session__c → SBA_641_Output__c
 *   3. validateQuarter()  → NexusValidationService XSD validation
 *   4. generateXml()      → SBA641_XMLBatch_REFACTORED
 *   pollJobStatus()       → shared async job poller
 *   getOutputCount()      → post-extraction record count
 *
 * SBA Fiscal Quarters:
 *   Q1 = Oct 1 (year-1) – Dec 31 (year-1)
 *   Q2 = Jan 1 – Mar 31
 *   Q3 = Apr 1 – Jun 30
 *   Q4 = Jul 1 – Sep 30
 */
public with sharing class SBA641ReportController {

    // ── Quarter date range ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getQuarterDates(String quarterYear) {
        List<String> parts = quarterYear.split('_');
        String quarter = parts[0];
        Integer year   = Integer.valueOf(parts[1]);

        Date startDate;
        Date endDate;

        if (quarter == 'Q1') {
            startDate = Date.newInstance(year - 1, 10, 1);
            endDate   = Date.newInstance(year - 1, 12, 31);
        } else if (quarter == 'Q2') {
            startDate = Date.newInstance(year, 1, 1);
            endDate   = Date.newInstance(year, 3, 31);
        } else if (quarter == 'Q3') {
            startDate = Date.newInstance(year, 4, 1);
            endDate   = Date.newInstance(year, 6, 30);
        } else {
            startDate = Date.newInstance(year, 7, 1);
            endDate   = Date.newInstance(year, 9, 30);
        }

        return new Map<String, String>{
            'startDate' => String.valueOf(startDate),
            'endDate'   => String.valueOf(endDate),
            'label'     => startDate.month() + '/' + startDate.day() + '/' + startDate.year()
                           + ' – '
                           + endDate.month() + '/' + endDate.day() + '/' + endDate.year()
        };
    }

    // ── Step 2: Extract Sessions → Output records ─────────────────────────────

    @AuraEnabled
    public static String extractSessions(String quarterYear) {
        // Look up the RecordTypeId for this quarter
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'SBA_641_Output__c'
            AND DeveloperName = :quarterYear
            LIMIT 1
        ];

        if (rts.isEmpty()) {
            throw new AuraHandledException(
                'No Record Type found for quarter "' + quarterYear + '". ' +
                'Please ensure a Record Type named "' + quarterYear + '" exists on SBA 641 Output.'
            );
        }

        String recordTypeId = rts[0].Id;

        // Calculate date range
        Map<String, String> dates = getQuarterDates(quarterYear);
        Date startDate = Date.valueOf(dates.get('startDate'));
        Date endDate   = Date.valueOf(dates.get('endDate'));

        // Delete existing Output records for this quarter (clean slate)
        List<SBA_641_Output__c> existing = [
            SELECT Id FROM SBA_641_Output__c
            WHERE Quarter_Year__c = :quarterYear
            LIMIT 10000
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }

        // Fire SBA641Batch with correct RecordTypeId
        SBA641Batch batch = new SBA641Batch(startDate, endDate, recordTypeId, quarterYear);
        return String.valueOf(Database.executeBatch(batch, 10));
    }

    // ── Step 3: Validate ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> validateQuarter(String quarterYear) {
        List<SBA_641_Output__c> records = [
            SELECT Id, PartnerClientNumber__c, LocationCode__c,
                   LastClientNamePart1__c, FirstClientNamePart1__c,
                   RaceClientIntake__c, EthnicityClientIntake__c, SexClientIntake__c,
                   MilitaryStatusClientIntake__c, SessionType_CounselorRecord__c,
                   PrimaryPhonePart1__c, Primary_PhonePart3__c,
                   CountryAddressPart1__c, Country_AddressPart3__c,
                   DateCounseled_CounselorRecord__c, PartnerSessionNumber_Counselor__c
            FROM SBA_641_Output__c
            WHERE Quarter_Year__c = :quarterYear
            LIMIT 2000
        ];

        List<NexusValidationService.ValidationResult> res =
            NexusValidationService.validate641Records(records);

        Integer errCnt = 0, warnCnt = 0;
        for (NexusValidationService.ValidationResult r : res) {
            if (r.severity == 'ERROR')   errCnt++;
            if (r.severity == 'WARNING') warnCnt++;
        }

        return new Map<String, Object>{
            'totalRecords' => records.size(),
            'errorCount'   => errCnt,
            'warningCount' => warnCnt,
            'results'      => res,
            'canGenerate'  => (errCnt == 0)
        };
    }

    // ── Step 4: Generate XML ──────────────────────────────────────────────────

    @AuraEnabled
    public static String generateXml(String quarterYear, String reportType) {
        return String.valueOf(
            Database.executeBatch(new SBA641_XMLBatch_REFACTORED(quarterYear, reportType), 200)
        );
    }

    // ── Shared: Job status polling ────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> pollJobStatus(String jobId) {
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, TotalJobItems, JobItemsProcessed,
                   NumberOfErrors, ExtendedStatus, CompletedDate
            FROM AsyncApexJob WHERE Id = :jobId LIMIT 1
        ];
        if (jobs.isEmpty()) return new Map<String, Object>{ 'status' => 'NotFound' };

        AsyncApexJob j = jobs[0];
        Decimal pct = (j.TotalJobItems != null && j.TotalJobItems > 0)
            ? ((Decimal)j.JobItemsProcessed / j.TotalJobItems * 100).setScale(0) : 0;

        return new Map<String, Object>{
            'status'           => j.Status,
            'totalBatches'     => j.TotalJobItems,
            'batchesProcessed' => j.JobItemsProcessed,
            'errorsCount'      => j.NumberOfErrors,
            'extendedStatus'   => j.ExtendedStatus,
            'completedDate'    => j.CompletedDate,
            'percentComplete'  => pct,
            'isComplete'       => (j.Status == 'Completed' || j.Status == 'Failed' || j.Status == 'Aborted')
        };
    }

    // ── Shared: Output record count ───────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Integer getOutputCount(String quarterYear) {
        return [SELECT COUNT() FROM SBA_641_Output__c WHERE Quarter_Year__c = :quarterYear];
    }

    // ── Shared: Check if Record Type exists for quarter ───────────────────────

    @AuraEnabled(cacheable=true)
    public static Boolean recordTypeExists(String quarterYear) {
        return ![SELECT Id FROM RecordType
                 WHERE SobjectType = 'SBA_641_Output__c'
                 AND DeveloperName = :quarterYear
                 LIMIT 1].isEmpty();
    }
}
