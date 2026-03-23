/**
 * SBA641_XMLAssembler
 * Writes XML chunks as part files in Salesforce Files.
 * Each part is linked to SBA641_XML_Upload__c.
 * The LWC downloads and merges parts client-side in the browser.
 *
 * Part file naming: SBA641_XML_Report_Q3_2025_Part001.xml etc.
 * The LWC reads all parts via SOQL, downloads via ContentVersion body,
 * and concatenates them using the browser's Blob API — zero Apex heap.
 */
public class SBA641_XMLAssembler implements Queueable {

    private List<Id> chunkCVIds;
    private String   varQuarterYear;
    private String   ownerEmail;
    private Integer  currentIndex;
    private Integer  partNumber;
    private Id       uploadRecordId;
    private String   accumulated;

    private static final Integer CHUNKS_PER_PART = 15;  // ~15 chunks × ~75KB = ~1MB per part
    private static final Integer MAX_PARTS       = 50;  // safety limit

    public SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail) {
        this.chunkCVIds     = chunkCVIds;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail     = ownerEmail;
        this.currentIndex   = 0;
        this.partNumber     = 1;
        this.accumulated    = '';
    }

    private SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail,
            Integer currentIndex, Integer partNumber, Id uploadRecordId, String accumulated) {
        this.chunkCVIds     = chunkCVIds;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail     = ownerEmail;
        this.currentIndex   = currentIndex;
        this.partNumber     = partNumber;
        this.uploadRecordId = uploadRecordId;
        this.accumulated    = accumulated;
    }

    public void execute(QueueableContext ctx) {
        try {
            // Create upload record on first execution
            if (uploadRecordId == null) {
                SBA641_XML_Upload__c rec = new SBA641_XML_Upload__c();
                rec.QuarterYear__c = varQuarterYear;
                insert rec;
                uploadRecordId = rec.Id;
            }

            // Read next batch of chunks
            Integer endIdx = Math.min(currentIndex + CHUNKS_PER_PART, chunkCVIds.size());
            List<Id> batchIds = new List<Id>();
            for (Integer i = currentIndex; i < endIdx; i++) {
                batchIds.add(chunkCVIds[i]);
            }

            List<ContentVersion> chunks = [
                SELECT Title, VersionData FROM ContentVersion
                WHERE Id IN :batchIds
                ORDER BY Title ASC
            ];

            for (ContentVersion cv : chunks) {
                accumulated += cv.VersionData.toString();
            }

            Integer nextIndex  = endIdx;
            Boolean allDone    = (nextIndex >= chunkCVIds.size());

            // Add closing tag on last part
            if (allDone) accumulated += '</CounselingInformation>\n';

            // Write this part as a ContentVersion
            writePart(accumulated, partNumber, uploadRecordId);

            if (allDone) {
                cleanupChunks();
                Integer totalParts = partNumber;
                if (totalParts == 1) {
                    // Single part — rename as final file
                    sendEmail('SBA641 XML Report \u2014 ' + varQuarterYear,
                        '641 XML for ' + varQuarterYear + ' is ready.\n\n' +
                        'Open the SBA 641 XML Upload record for ' + varQuarterYear +
                        ' in Salesforce to download the file.');
                } else {
                    sendEmail('SBA641 XML Report \u2014 ' + varQuarterYear + ' (Ready to Download)',
                        '641 XML for ' + varQuarterYear + ' is ready (' + totalParts + ' parts).\n\n' +
                        'Return to the SBA 641 Counseling Report wizard and click ' +
                        '"Download & Merge XML" to automatically combine the parts ' +
                        'and download the final file to your computer.');
                }
            } else if (partNumber < MAX_PARTS) {
                System.enqueueJob(new SBA641_XMLAssembler(
                    chunkCVIds, varQuarterYear, ownerEmail,
                    nextIndex, partNumber + 1, uploadRecordId, ''
                ));
            }

        } catch (Exception e) {
            sendEmail('SBA641 XML Assembly Error \u2014 ' + varQuarterYear,
                'Error at chunk ' + currentIndex + ':\n' + e.getMessage() +
                '\nStack: ' + e.getStackTraceString());
        }
    }

    private void writePart(String xml, Integer partNum, Id recId) {
        String label = String.valueOf(partNum).leftPad(3, '0');
        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA641_XML_Report_' + varQuarterYear + '_Part' + label;
        cv.PathOnClient   = cv.Title + '.xml';
        cv.VersionData    = Blob.valueOf(xml);
        cv.IsMajorVersion = false;
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docId;
        cdl.LinkedEntityId    = recId;
        cdl.ShareType         = 'V';
        insert cdl;
    }

    private void cleanupChunks() {
        try {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :chunkCVIds)];
            if (!docs.isEmpty()) delete docs;
        } catch (Exception e) { System.debug('Cleanup error: ' + e.getMessage()); }
    }

    private void sendEmail(String subject, String body) {
        if (String.isBlank(ownerEmail)) return;
        try {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject(subject);
            m.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m });
        } catch (Exception e) { System.debug('Email error: ' + e.getMessage()); }
    }
}
