/**
 * SBA641_XMLAssembler
 * Assembles XML chunks into a final ContentVersion using the Salesforce
 * Files REST API chunked upload (Content-Range). Each execution uploads
 * one chunk without holding accumulated content in heap.
 *
 * Flow:
 *   1. First execution: initiate upload, get ContentVersion Id
 *   2. Each subsequent execution: PATCH one chunk with Content-Range header
 *   3. Final execution: finalize, link to SBA641_XML_Upload__c, email
 */
public class SBA641_XMLAssembler implements Queueable, Database.AllowsCallouts {

    private List<Id>  chunkCVIds;
    private Integer   currentIndex;
    private String    varQuarterYear;
    private String    ownerEmail;
    private Id        targetCVId;       // ContentVersion being built via REST
    private Id        targetDocId;      // ContentDocument Id
    private Long      bytesUploaded;    // running byte offset for Content-Range
    private Long      totalBytes;       // total file size (calculated on first pass)

    // ── Constructor (initial) ──────────────────────────────────────────────────
    public SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail) {
        this.chunkCVIds    = chunkCVIds;
        this.currentIndex  = 0;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail    = ownerEmail;
        this.bytesUploaded = 0;
        this.totalBytes    = -1; // calculated on first run
    }

    // ── Constructor (chaining) ─────────────────────────────────────────────────
    private SBA641_XMLAssembler(List<Id> chunkCVIds, Integer currentIndex,
            String varQuarterYear, String ownerEmail,
            Id targetCVId, Id targetDocId,
            Long bytesUploaded, Long totalBytes) {
        this.chunkCVIds    = chunkCVIds;
        this.currentIndex  = currentIndex;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail    = ownerEmail;
        this.targetCVId    = targetCVId;
        this.targetDocId   = targetDocId;
        this.bytesUploaded = bytesUploaded;
        this.totalBytes    = totalBytes;
    }

    public void execute(QueueableContext ctx) {
        try {
            // On first run, calculate total size across all chunks
            if (totalBytes < 0) {
                totalBytes = calculateTotalSize();
                if (totalBytes <= 0) {
                    sendEmail('SBA641 XML Assembly Failed',
                        'Could not calculate total XML size for ' + varQuarterYear);
                    return;
                }
            }

            // Read current chunk
            Id chunkId = chunkCVIds[currentIndex];
            ContentVersion chunk = [SELECT Title, VersionData FROM ContentVersion
                                    WHERE Id = :chunkId LIMIT 1];
            Blob chunkData = chunk.VersionData;
            Long chunkSize = chunkData.size();
            Long rangeEnd  = bytesUploaded + chunkSize - 1;

            String baseUrl = URL.getOrgDomainUrl().toExternalForm();

            if (targetCVId == null) {
                // First chunk — create ContentVersion via multipart POST
                String boundary = 'boundary_641xml';
                String metaJson = '{"Title":"SBA641_XML_Report_' + varQuarterYear + '",' +
                    '"PathOnClient":"SBA641_Report_' + varQuarterYear + '.xml",' +
                    '"IsMajorVersion":true}';

                // Build multipart body
                Blob metaPart  = Blob.valueOf(
                    '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="entity_content"\r\n' +
                    'Content-Type: application/json\r\n\r\n' +
                    metaJson + '\r\n' +
                    '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="VersionData"; filename="SBA641_Report_' + varQuarterYear + '.xml"\r\n' +
                    'Content-Type: text/xml\r\n\r\n'
                );
                Blob closePart = Blob.valueOf('\r\n--' + boundary + '--');

                // Combine: metaPart + chunkData + closePart
                Blob body = combine(combine(metaPart, chunkData), closePart);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(baseUrl + '/services/data/v63.0/sobjects/ContentVersion');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
                req.setBodyAsBlob(body);

                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 201) {
                    Map<String,Object> result = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                    targetCVId = (Id)result.get('id');
                    // Get ContentDocumentId
                    targetDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :targetCVId LIMIT 1].ContentDocumentId;
                    bytesUploaded += chunkSize;
                } else {
                    sendEmail('SBA641 XML Assembly Error',
                        'Failed to create ContentVersion. Status: ' + res.getStatusCode() +
                        '\n' + res.getBody());
                    return;
                }
            } else {
                // Subsequent chunks — PATCH with Content-Range
                String contentRange = 'bytes ' + bytesUploaded + '-' + rangeEnd + '/' + totalBytes;

                String boundary = 'boundary_641xml';
                String metaJson = '{"Id":"' + targetCVId + '"}';

                Blob metaPart  = Blob.valueOf(
                    '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="entity_content"\r\n' +
                    'Content-Type: application/json\r\n\r\n' +
                    metaJson + '\r\n' +
                    '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="VersionData"; filename="SBA641_Report_' + varQuarterYear + '.xml"\r\n' +
                    'Content-Type: text/xml\r\n' +
                    'Content-Range: ' + contentRange + '\r\n\r\n'
                );
                Blob closePart = Blob.valueOf('\r\n--' + boundary + '--');
                Blob body = combine(combine(metaPart, chunkData), closePart);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(baseUrl + '/services/data/v63.0/sobjects/ContentVersion/' + targetCVId);
                req.setMethod('PATCH');
                req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
                req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
                req.setBodyAsBlob(body);

                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                    bytesUploaded += chunkSize;
                } else {
                    sendEmail('SBA641 XML Assembly Error',
                        'PATCH chunk ' + currentIndex + ' failed. Status: ' + res.getStatusCode() +
                        '\n' + res.getBody());
                    return;
                }
            }

            Integer nextIndex = currentIndex + 1;
            Boolean isDone    = (nextIndex >= chunkCVIds.size());

            if (isDone) {
                finalizeUpload();
                cleanupChunks();
            } else {
                // Chain to next chunk
                System.enqueueJob(new SBA641_XMLAssembler(
                    chunkCVIds, nextIndex, varQuarterYear, ownerEmail,
                    targetCVId, targetDocId, bytesUploaded, totalBytes
                ));
            }

        } catch(Exception e) {
            sendEmail('SBA641 XML Assembly Exception',
                'Unexpected error at chunk ' + currentIndex + ': ' + e.getMessage() +
                '\nStack: ' + e.getStackTraceString());
        }
    }

    // ── Calculate total bytes across all chunks ────────────────────────────────
    private Long calculateTotalSize() {
        Long total = 0;
        // Query in batches to avoid heap issues
        for (ContentVersion cv : [SELECT VersionData FROM ContentVersion
                                   WHERE Id IN :chunkCVIds]) {
            total += cv.VersionData.size();
        }
        return total;
    }

    // ── Combine two Blobs ──────────────────────────────────────────────────────
    private static Blob combine(Blob a, Blob b) {
        return EncodingUtil.base64Decode(
            EncodingUtil.base64Encode(a) + EncodingUtil.base64Encode(b)
        );
    }

    // ── Finalize: link file + email ────────────────────────────────────────────
    private void finalizeUpload() {
        // Create SBA641_XML_Upload__c record
        SBA641_XML_Upload__c rec = new SBA641_XML_Upload__c();
        rec.QuarterYear__c = varQuarterYear;
        insert rec;

        // Link ContentDocument to upload record
        if (targetDocId != null) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = targetDocId;
            cdl.LinkedEntityId    = rec.Id;
            cdl.ShareType         = 'V';
            insert cdl;
        }

        // Email notification (no attachment — file is in Salesforce Files)
        sendEmail(
            'SBA641 XML Report \u2014 ' + varQuarterYear,
            '641 XML report for ' + varQuarterYear + ' has been generated.\n\n' +
            'The file is available in Salesforce Files linked to the ' +
            'SBA 641 XML Upload record for ' + varQuarterYear + '.\n\n' +
            'File: SBA641_Report_' + varQuarterYear + '.xml'
        );
    }

    // ── Clean up temp chunk ContentVersions ───────────────────────────────────
    private void cleanupChunks() {
        try {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion
                             WHERE Id IN :chunkCVIds)];
            if (!docs.isEmpty()) delete docs;
        } catch(Exception e) {
            System.debug('Chunk cleanup failed: ' + e.getMessage());
        }
    }

    // ── Email helper ──────────────────────────────────────────────────────────
    private void sendEmail(String subject, String body) {
        if (String.isBlank(ownerEmail)) return;
        try {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject(subject);
            m.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m });
        } catch(Exception e) {
            System.debug('Email failed: ' + e.getMessage());
        }
    }
}
