public class SBA888_XMLMergeController {
    public String quarterYear   { get; private set; }
    public String partsJson     { get; private set; }
    public String statusMessage { get; private set; }

    public SBA888_XMLMergeController() {
        quarterYear   = '';
        partsJson     = '[]';
        statusMessage = '';
    }

    public PageReference init() {
        String uploadId = ApexPages.currentPage().getParameters().get('uploadId');
        if (String.isBlank(uploadId)) { statusMessage = 'Error: uploadId required'; return null; }
        List<SBA888_XML_Upload__c> uploads = [
            SELECT QuarterYear__c FROM SBA888_XML_Upload__c WHERE Id = :uploadId LIMIT 1
        ];
        if (uploads.isEmpty()) { statusMessage = 'Error: Upload record not found'; return null; }
        quarterYear = uploads[0].QuarterYear__c;
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :uploadId
        ]) { docIds.add(cdl.ContentDocumentId); }
        List<Map<String,String>> parts = new List<Map<String,String>>();
        for (ContentVersion cv : [
            SELECT Id, Title FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE :('SBA888_XML_Report_' + quarterYear + '%')
            AND IsLatest = true
            ORDER BY Title ASC
        ]) {
            parts.add(new Map<String,String>{ 'cvId' => cv.Id, 'title' => cv.Title });
        }
        partsJson = JSON.serialize(parts);
        statusMessage = '<div class="status">Found ' + parts.size() + ' part files. Starting downloads\u2026</div>';
        return null;
    }
}