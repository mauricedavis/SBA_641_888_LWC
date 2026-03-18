/**
 * SBA641ReportController
 * AuraEnabled controller backing sba641ReportingWizard LWC.
 *
 * Run State Persistence:
 *   Uses SBA641_Run_State__c custom object to persist wizard state across
 *   page navigation and browser refreshes. One active record per user.
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

    // ── Step 5: Generate XML ───────────────────────────────────────────────────

    @AuraEnabled
    public static String generateXml(String quarterYear, String reportType) {
        return String.valueOf(
            Database.executeBatch(new SBA641_XMLBatch_REFACTORED(quarterYear, reportType), 200)
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

    // ── Run State Persistence ─────────────────────────────────────────────────
    // Uses SBA641_Run_State__c to persist wizard state across navigation/refresh.
    // One active record per user — upsert on OwnerId.

    @AuraEnabled
    public static void saveRunState(Map<String, Object> state) {
        Id userId = UserInfo.getUserId();
        List<SBA641_Run_State__c> existing = [
            SELECT Id FROM SBA641_Run_State__c
            WHERE OwnerId = :userId
            AND Run_Status__c = 'In Progress'
            LIMIT 1
        ];

        SBA641_Run_State__c rec = existing.isEmpty()
            ? new SBA641_Run_State__c()
            : existing[0];

        rec.Quarter_Year__c    = (String)  state.get('quarterYear');
        rec.Current_Step__c    = (Decimal) state.get('currentStep');
        rec.Date_Label__c      = (String)  state.get('dateLabel');
        rec.Extract_Job_Id__c  = (String)  state.get('extractJobId');
        rec.Extracted_Count__c = state.get('extractedCount') != null
            ? Decimal.valueOf(String.valueOf(state.get('extractedCount'))) : 0;
        rec.XML_Job_Id__c      = (String)  state.get('xmlJobId');
        rec.Run_Status__c      = (String)  state.get('runStatus');
        rec.Selected_Quarter__c = (String) state.get('selectedQuarter');
        rec.Selected_Year__c   = (String)  state.get('selectedYear');

        upsert rec;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadRunState() {
        Id userId = UserInfo.getUserId();
        List<SBA641_Run_State__c> recs = [
            SELECT Id, Quarter_Year__c, Current_Step__c, Date_Label__c,
                   Extract_Job_Id__c, Extracted_Count__c, XML_Job_Id__c,
                   Run_Status__c, Selected_Quarter__c, Selected_Year__c,
                   LastModifiedDate
            FROM SBA641_Run_State__c
            WHERE OwnerId = :userId
            AND Run_Status__c = 'In Progress'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (recs.isEmpty()) return null;

        SBA641_Run_State__c r = recs[0];
        return new Map<String, Object>{
            'stateId'        => r.Id,
            'quarterYear'    => r.Quarter_Year__c,
            'currentStep'    => r.Current_Step__c,
            'dateLabel'      => r.Date_Label__c,
            'extractJobId'   => r.Extract_Job_Id__c,
            'extractedCount' => r.Extracted_Count__c,
            'xmlJobId'       => r.XML_Job_Id__c,
            'runStatus'      => r.Run_Status__c,
            'selectedQuarter'=> r.Selected_Quarter__c,
            'selectedYear'   => r.Selected_Year__c,
            'lastModified'   => r.LastModifiedDate
        };
    }

    @AuraEnabled
    public static void clearRunState() {
        Id userId = UserInfo.getUserId();
        List<SBA641_Run_State__c> recs = [
            SELECT Id FROM SBA641_Run_State__c
            WHERE OwnerId = :userId LIMIT 10
        ];
        if (!recs.isEmpty()) delete recs;
    }
}
