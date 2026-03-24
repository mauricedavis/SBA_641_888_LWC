/**
 * SBA641ReportController
 * AuraEnabled controller backing sba641ReportingWizard LWC.
 *
 * Run State Persistence uses dynamic Apex to reference SBA641_Run_State__c,
 * avoiding compile-time type resolution issues with FLS/profile access.
 *
 * SBA Fiscal Quarters:
 *   Q1 = Oct 1 (year-1) – Dec 31 (year-1)
 *   Q2 = Jan 1 – Mar 31
 *   Q3 = Apr 1 – Jun 30
 *   Q4 = Jul 1 – Sep 30
 */
public with sharing class SBA641ReportController {

    // ── Quarter date range ─────────────────────────────────────────────────────

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
                           + ' \u2013 '
                           + endDate.month() + '/' + endDate.day() + '/' + endDate.year()
        };
    }

    // ── Step 2: Extract Sessions ───────────────────────────────────────────────

    @AuraEnabled
    public static String extractSessions(String quarterYear) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'SBA_641_Output__c'
            AND DeveloperName = :quarterYear
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            throw new AuraHandledException(
                'No Record Type found for "' + quarterYear + '" on SBA 641 Output. ' +
                'Please create it in Setup first.'
            );
        }
        String recordTypeId = rts[0].Id;

        Map<String, String> dates = getQuarterDates(quarterYear);
        Date startDate = Date.valueOf(dates.get('startDate'));
        Date endDate   = Date.valueOf(dates.get('endDate'));

        List<SBA_641_Output__c> existing = [
            SELECT Id FROM SBA_641_Output__c
            WHERE Quarter_Year__c = :quarterYear LIMIT 10000
        ];
        if (!existing.isEmpty()) delete existing;

        SBA641Batch batch = new SBA641Batch(startDate, endDate, recordTypeId, quarterYear);
        return String.valueOf(Database.executeBatch(batch, 10));
    }

    // ── Step 3: Validate ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> validateQuarter(String quarterYear) {
        List<SBA_641_Output__c> records = [
            SELECT Id, PartnerClientNumber__c, LocationCode__c,
                   LastClientNamePart1__c, FirstClientNamePart1__c,
                   RaceClientIntake__c, EthnicityClientIntake__c, SexClientIntake__c,
                   MilitaryStatusClientIntake__c, SessionType_CounselorRecord__c,
                   PrimaryPhonePart1__c, SecondaryPhonePart1__c,
                   Primary_PhonePart3__c, Secondary_PhonePart3__c,
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

    // ── Step 5: Generate XML ───────────────────────────────────────────────────

    @AuraEnabled
    public static String generateXml(String quarterYear, String reportType) {
        return String.valueOf(
            Database.executeBatch(new SBA641_XMLBatch_REFACTORED(quarterYear, reportType), 50)
        );
    }

    // ── Job status polling ─────────────────────────────────────────────────────

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

    // ── Output record count ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Integer getOutputCount(String quarterYear) {
        return [SELECT COUNT() FROM SBA_641_Output__c WHERE Quarter_Year__c = :quarterYear];
    }

    // ── Record Type check ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Boolean recordTypeExists(String quarterYear) {
        return ![SELECT Id FROM RecordType
                 WHERE SobjectType = 'SBA_641_Output__c'
                 AND DeveloperName = :quarterYear LIMIT 1].isEmpty();
    }

    // ── Run State Persistence (Dynamic Apex — avoids FLS compile issues) ───────
    // Uses dynamic SOQL/DML so SBA641_Run_State__c is resolved at runtime,
    // not at compile time. This bypasses profile FLS restrictions on the type.

    private static final String RUN_STATE_OBJECT = 'SBA641_Run_State__c';

    @AuraEnabled
    public static void saveRunState(Map<String, Object> state) {
        try {
            Id userId = UserInfo.getUserId();

            // Check for existing in-progress record
            String query = 'SELECT Id FROM ' + RUN_STATE_OBJECT
                + ' WHERE OwnerId = \'' + userId + '\''
                + ' AND Run_Status__c = \'In Progress\' LIMIT 1';
            List<SObject> existing = Database.query(query);

            SObject rec = existing.isEmpty()
                ? Schema.getGlobalDescribe().get(RUN_STATE_OBJECT).newSObject()
                : existing[0];

            rec.put('Quarter_Year__c',    state.get('quarterYear'));
            rec.put('Current_Step__c',    state.get('currentStep'));
            rec.put('Date_Label__c',      state.get('dateLabel'));
            rec.put('Extract_Job_Id__c',  state.get('extractJobId'));
            rec.put('XML_Job_Id__c',      state.get('xmlJobId'));
            rec.put('Run_Status__c',      state.get('runStatus') != null ? state.get('runStatus') : 'In Progress');
            rec.put('Selected_Quarter__c',state.get('selectedQuarter'));
            rec.put('Selected_Year__c',   state.get('selectedYear'));

            Object cnt = state.get('extractedCount');
            if (cnt != null) {
                rec.put('Extracted_Count__c', Decimal.valueOf(String.valueOf(cnt)));
            }

            upsert rec;
        } catch(Exception e) {
            // Silently fail — run state persistence is non-critical
            System.debug('saveRunState failed: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadRunState() {
        try {
            Id userId = UserInfo.getUserId();
            String query = 'SELECT Id, Quarter_Year__c, Current_Step__c, Date_Label__c,'
                + ' Extract_Job_Id__c, Extracted_Count__c, XML_Job_Id__c,'
                + ' Run_Status__c, Selected_Quarter__c, Selected_Year__c, LastModifiedDate'
                + ' FROM ' + RUN_STATE_OBJECT
                + ' WHERE OwnerId = \'' + userId + '\''
                + ' AND Run_Status__c = \'In Progress\''
                + ' ORDER BY LastModifiedDate DESC LIMIT 1';

            List<SObject> recs = Database.query(query);
            if (recs.isEmpty()) return null;

            SObject r = recs[0];
            return new Map<String, Object>{
                'stateId'         => r.get('Id'),
                'quarterYear'     => r.get('Quarter_Year__c'),
                'currentStep'     => r.get('Current_Step__c'),
                'dateLabel'       => r.get('Date_Label__c'),
                'extractJobId'    => r.get('Extract_Job_Id__c'),
                'extractedCount'  => r.get('Extracted_Count__c'),
                'xmlJobId'        => r.get('XML_Job_Id__c'),
                'runStatus'       => r.get('Run_Status__c'),
                'selectedQuarter' => r.get('Selected_Quarter__c'),
                'selectedYear'    => r.get('Selected_Year__c'),
                'lastModified'    => r.get('LastModifiedDate')
            };
        } catch(Exception e) {
            System.debug('loadRunState failed: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void clearRunState() {
        try {
            Id userId = UserInfo.getUserId();
            String query = 'SELECT Id FROM ' + RUN_STATE_OBJECT
                + ' WHERE OwnerId = \'' + userId + '\' LIMIT 10';
            List<SObject> recs = Database.query(query);
            if (!recs.isEmpty()) delete recs;
        } catch(Exception e) {
            System.debug('clearRunState failed: ' + e.getMessage());
        }
    }

    // ── Get part file ContentVersions for client-side merge ───────────────────
    // Returns ordered list of {cvId, title} for all parts linked to the
    // most recent SBA641_XML_Upload__c for this quarter.
    @AuraEnabled(cacheable=false)
    public static List<Map<String,String>> getXmlPartFiles(String quarterYear) {
        List<Map<String,String>> result = new List<Map<String,String>>();

        // Find the most recent upload record for this quarter
        List<SBA641_XML_Upload__c> uploads = [
            SELECT Id FROM SBA641_XML_Upload__c
            WHERE QuarterYear__c = :quarterYear
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (uploads.isEmpty()) return result;

        Id uploadId = uploads[0].Id;

        // Get all linked ContentVersions that are part files, ordered by title
        for (ContentVersion cv : [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN (
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :uploadId
            )
            AND Title LIKE :('SBA641_XML_Report_' + quarterYear + '%')
            AND IsLatest = true
            ORDER BY Title ASC
        ]) {
            result.add(new Map<String,String>{
                'cvId'  => cv.Id,
                'title' => cv.Title
            });
        }
        return result;
    }
}
