/**
 * SBA888_XMLAssembler
 * Assembles SBA888 XML chunks into part files linked to SBA888_XML_Upload__c.
 * Same pattern as SBA641_XMLAssembler.
 */
public class SBA888_XMLAssembler implements Queueable {

    private List<Id> chunkCVIds;
    private String   varQuarterYear;
    private String   ownerEmail;
    private Integer  currentIndex;
    private Integer  partNumber;
    private Id       uploadRecordId;
    private String   accumulated;

    private static final Integer CHUNKS_PER_PART = 15;
    private static final Integer MAX_PARTS       = 50;

    public SBA888_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail) {
        this.chunkCVIds     = chunkCVIds;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail     = ownerEmail;
        this.currentIndex   = 0;
        this.partNumber     = 1;
        this.accumulated    = '';
    }

    private SBA888_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail,
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
            if (uploadRecordId == null) {
                SBA888_XML_Upload__c rec = new SBA888_XML_Upload__c();
                rec.QuarterYear__c = varQuarterYear;
                insert rec;
                uploadRecordId = rec.Id;
            }

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

            Integer nextIndex = endIdx;
            Boolean allDone   = (nextIndex >= chunkCVIds.size());
            if (allDone) accumulated += '</ManagementTrainingReport>\n';

            writePart(accumulated, partNumber, uploadRecordId);

            if (allDone) {
                cleanupChunks();
                if (partNumber == 1) {
                    sendEmail('SBA888 XML Report \u2014 ' + varQuarterYear,
                        '888 XML report for ' + varQuarterYear + ' has been generated.\n\n' +
                        'Open the SBA 888 XML Upload record for ' + varQuarterYear +
                        ' in Salesforce to download the file via the wizard.');
                } else {
                    sendEmail('SBA888 XML Report \u2014 ' + varQuarterYear + ' (' + partNumber + ' parts)',
                        '888 XML for ' + varQuarterYear + ' is ready (' + partNumber + ' parts).\n\n' +
                        'Return to the SBA 888 Training Report wizard and click ' +
                        '"Download & Merge XML" to combine and download the final file.');
                }
            } else if (partNumber < MAX_PARTS) {
                System.enqueueJob(new SBA888_XMLAssembler(
                    chunkCVIds, varQuarterYear, ownerEmail,
                    nextIndex, partNumber + 1, uploadRecordId, ''
                ));
            }

        } catch (Exception e) {
            sendEmail('SBA888 XML Assembly Error \u2014 ' + varQuarterYear,
                'Error at chunk ' + currentIndex + ':\n' + e.getMessage() +
                '\nStack: ' + e.getStackTraceString());
        }
    }

    private void writePart(String xml, Integer partNum, Id recId) {
        String label = String.valueOf(partNum).leftPad(3, '0');
        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA888_XML_Report_' + varQuarterYear + '_Part' + label;
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
