public class SBA641_XMLDownloadController {
    public String fileName   { get; private set; }
    public String xmlContent { get; private set; }
    public SBA641_XMLDownloadController() {
        fileName = 'SBA641_Report.xml';
        xmlContent = '';
    }
    public PageReference streamXml() {
        String uploadId = ApexPages.currentPage().getParameters().get('uploadId');
        if (String.isBlank(uploadId)) { xmlContent = '<!-- Error: uploadId required -->'; return null; }
        List<SBA641_XML_Upload__c> uploads = [SELECT Id, QuarterYear__c FROM SBA641_XML_Upload__c WHERE Id = :uploadId LIMIT 1];
        if (uploads.isEmpty()) { xmlContent = '<!-- Error: record not found -->'; return null; }
        String qy = uploads[0].QuarterYear__c;
        fileName = 'SBA641_Report_' + qy + '.xml';
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :uploadId]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) { xmlContent = '<!-- No files found -->'; return null; }
        List<String> parts = new List<String>();
        for (ContentVersion cv : [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId IN :docIds AND Title LIKE :('SBA641_XML_Report_' + qy + '%') AND IsLatest = true ORDER BY Title ASC]) {
            parts.add(cv.VersionData.toString());
        }
        xmlContent = String.join(parts, '');
        return null;
    }
}

// Note: getUploadRecordId is in SBA641ReportController, not here
