/**
 * SBA641ReportController
 * AuraEnabled controller backing sba641ReportingWizard LWC.
 */
public with sharing class SBA641ReportController {

    @AuraEnabled(cacheable=false)
    public static Map<String,Object> validateQuarter(String quarterYear) {
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
        List<NexusValidationService.ValidationResult> res = NexusValidationService.validate641Records(records);
        Integer errCnt = 0, warnCnt = 0;
        for (NexusValidationService.ValidationResult r : res) {
            if (r.severity == 'ERROR')   errCnt++;
            if (r.severity == 'WARNING') warnCnt++;
        }
        return new Map<String,Object>{
            'totalRecords' => records.size(),
            'errorCount'   => errCnt,
            'warningCount' => warnCnt,
            'results'      => res,
            'canGenerate'  => (errCnt == 0)
        };
    }

    @AuraEnabled
    public static String generateXml(String quarterYear, String reportType) {
        return String.valueOf(Database.executeBatch(new SBA641_XMLBatch_REFACTORED(quarterYear, reportType), 200));
    }

    @AuraEnabled(cacheable=false)
    public static Map<String,Object> pollJobStatus(String jobId) {
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, TotalJobItems, JobItemsProcessed,
                   NumberOfErrors, ExtendedStatus, CompletedDate
            FROM AsyncApexJob WHERE Id = :jobId LIMIT 1
        ];
        if (jobs.isEmpty()) return new Map<String,Object>{ 'status' => 'NotFound' };
        AsyncApexJob j = jobs[0];
        Decimal pct = (j.TotalJobItems != null && j.TotalJobItems > 0)
            ? ((Decimal)j.JobItemsProcessed / j.TotalJobItems * 100).setScale(0) : 0;
        return new Map<String,Object>{
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
}
