/**
 * SBA888ReportController
 * AuraEnabled controller for sba888ReportingWizard LWC.
 * Handles event extraction, XML generation, polling, and file management.
 */
public with sharing class SBA888ReportController {

    // ── Quarter date ranges (same SBA fiscal year as 641) ─────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String,String> getQuarterDates(String quarterYear) {
        List<String> parts = quarterYear.split('_');
        String quarter = parts[0];
        Integer year   = Integer.valueOf(parts[1]);
        Date startDate, endDate;
        String label;

        if (quarter == 'Q1') {
            startDate = Date.newInstance(year - 1, 10, 1);
            endDate   = Date.newInstance(year - 1, 12, 31);
            label     = 'Q1 ' + year + ': Oct 1 \u2013 Dec 31, ' + (year - 1);
        } else if (quarter == 'Q2') {
            startDate = Date.newInstance(year, 1, 1);
            endDate   = Date.newInstance(year, 3, 31);
            label     = 'Q2 ' + year + ': Jan 1 \u2013 Mar 31, ' + year;
        } else if (quarter == 'Q3') {
            startDate = Date.newInstance(year, 4, 1);
            endDate   = Date.newInstance(year, 6, 30);
            label     = 'Q3 ' + year + ': Apr 1 \u2013 Jun 30, ' + year;
        } else {
            startDate = Date.newInstance(year, 7, 1);
            endDate   = Date.newInstance(year, 9, 30);
            label     = 'Q4 ' + year + ': Jul 1 \u2013 Sep 30, ' + year;
        }
        return new Map<String,String>{
            'startDate' => String.valueOf(startDate),
            'endDate'   => String.valueOf(endDate),
            'label'     => label
        };
    }

    // ── Check if RecordType exists for this quarter ────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Boolean recordTypeExists(String quarterYear) {
        return ![SELECT Id FROM RecordType
                 WHERE SObjectType = 'SBA_888_Output__c'
                 AND DeveloperName = :quarterYear LIMIT 1].isEmpty();
    }

    // ── Extract events → SBA_888_Output__c ────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static String extractEvents(String quarterYear) {
        Map<String,String> dates = getQuarterDates(quarterYear);
        Date startDate = Date.valueOf(dates.get('startDate'));
        Date endDate   = Date.valueOf(dates.get('endDate'));

        RecordType rt = [SELECT Id FROM RecordType
                         WHERE SObjectType = 'SBA_888_Output__c'
                         AND DeveloperName = :quarterYear LIMIT 1];

        return String.valueOf(Database.executeBatch(
            new SBA888Batch(startDate, endDate, rt.Id, quarterYear), 10
        ));
    }

    // ── Get count of extracted output records ──────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Integer getOutputCount(String quarterYear) {
        return [SELECT COUNT() FROM SBA_888_Output__c
                WHERE RecordType.DeveloperName = :quarterYear];
    }

    // ── Poll batch job status ──────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Map<String,Object> pollJobStatus(String jobId) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                            TotalJobItems, ExtendedStatus
                            FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        Integer pct = (job.TotalJobItems > 0)
            ? Integer.valueOf((job.JobItemsProcessed * 100) / job.TotalJobItems) : 0;
        return new Map<String,Object>{
            'status'    => job.Status,
            'processed' => job.JobItemsProcessed,
            'total'     => job.TotalJobItems,
            'errors'    => job.NumberOfErrors,
            'percent'   => pct,
            'detail'    => job.ExtendedStatus
        };
    }

    // ── Validate extracted output records against XSD ────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Map<String,Object> validateQuarter(String quarterYear) {
        SBA888ValidationService.ValidationSummary summary =
            SBA888ValidationService.validate(quarterYear);
        List<Map<String,Object>> results = new List<Map<String,Object>>();
        for (SBA888ValidationService.ValidationResult r : summary.results) {
            results.add(new Map<String,Object>{
                'recordId'             => r.recordId,
                'partnerTrainingNumber' => r.partnerTrainingNumber,
                'severity'             => r.severity,
                'field'                => r.field,
                'message'              => r.message
            });
        }
        return new Map<String,Object>{
            'totalRecords' => summary.totalRecords,
            'errorCount'   => summary.errorCount,
            'warningCount' => summary.warningCount,
            'results'      => results
        };
    }

    // ── Generate XML ───────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static String generateXml(String quarterYear) {
        return String.valueOf(
            Database.executeBatch(new SBA888_XMLBatch(quarterYear), 50)
        );
    }

    // ── Get XML part files for this quarter ────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static List<Map<String,String>> getXmlPartFiles(String quarterYear) {
        List<Map<String,String>> result = new List<Map<String,String>>();
        List<SBA888_XML_Upload__c> uploads = [
            SELECT Id FROM SBA888_XML_Upload__c
            WHERE QuarterYear__c = :quarterYear
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (uploads.isEmpty()) return result;
        Id uploadId = uploads[0].Id;
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :uploadId
        ]) { docIds.add(cdl.ContentDocumentId); }
        if (docIds.isEmpty()) return result;
        for (ContentVersion cv : [
            SELECT Id, Title FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE :('SBA888_XML_Report_' + quarterYear + '%')
            AND IsLatest = true
            ORDER BY Title ASC
        ]) {
            result.add(new Map<String,String>{ 'cvId' => cv.Id, 'title' => cv.Title });
        }
        return result;
    }

    // ── Get upload record Id ───────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Id getUploadRecordId(String quarterYear) {
        List<SBA888_XML_Upload__c> uploads = [
            SELECT Id FROM SBA888_XML_Upload__c
            WHERE QuarterYear__c = :quarterYear
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        return uploads.isEmpty() ? null : uploads[0].Id;
    }
}
