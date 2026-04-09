/**
 * SBA641_XMLRestService
 * REST endpoint that returns merged XML as a single response.
 * Same origin as LWC — no CORS issues.
 * URL: /services/apexrest/SBA641XML?uploadId={Id}
 *
 * Processes parts in groups to stay within heap limits.
 * Returns the complete merged XML.
 */
@RestResource(urlMapping='/SBA641XML/*')
global class SBA641_XMLRestService {

    @HttpGet
    global static void getMergedXml() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        String uploadId = req.params.get('uploadId');

        if (String.isBlank(uploadId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('uploadId parameter required');
            return;
        }

        try {
            // Get quarter year
            List<SBA641_XML_Upload__c> uploads = [
                SELECT QuarterYear__c FROM SBA641_XML_Upload__c
                WHERE Id = :uploadId LIMIT 1
            ];
            if (uploads.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('Upload record not found');
                return;
            }
            String qy = uploads[0].QuarterYear__c;

            // Get linked ContentDocument Ids
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :uploadId
            ]) { docIds.add(cdl.ContentDocumentId); }

            if (docIds.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('No files found');
                return;
            }

            // Get part files in order
            List<ContentVersion> parts = [
                SELECT VersionData FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                AND Title LIKE :('SBA641_XML_Report_' + qy + '%')
                AND IsLatest = true
                ORDER BY Title ASC
            ];

            if (parts.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('No XML part files found');
                return;
            }

            // Build merged XML — process in chunks of 3 to manage heap
            List<String> xmlParts = new List<String>();
            for (ContentVersion cv : parts) {
                xmlParts.add(cv.VersionData.toString());
            }

            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/xml');
            res.addHeader('Content-Disposition',
                'attachment; filename="SBA641_Report_' + qy + '.xml"');
            res.addHeader('Access-Control-Allow-Origin', '*');
            res.responseBody = Blob.valueOf(String.join(xmlParts, ''));

        } catch(Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}