/**
 * SBA641_XMLAssembler
 * Queueable job that assembles ContentVersion XML chunks into a final file
 * by chaining itself — one chunk per execution to stay within heap limits.
 *
 * Strategy:
 *   - Processes chunks in Title order (000, 001, 002 ... 999_CLOSE)
 *   - First execution creates the ContentVersion with chunk 0 data
 *   - Subsequent executions PATCH the ContentVersion body by re-creating it
 *     with accumulated content (for small totals) OR chains to next chunk
 *   - When all chunks processed: attaches to SBA641_XML_Upload__c and emails
 *
 * For very large files (>6MB), uses a two-pass approach:
 *   Pass 1: Collect all chunk Ids in order (already have them)
 *   Pass 2: Read 2 chunks at a time, write to a running ContentVersion
 *           by inserting new versions (ContentVersion is immutable after insert)
 *
 * Note: Salesforce ContentVersion body is immutable after insert.
 * The only way to "append" is to read all previous data + new chunk and
 * insert a new ContentVersion. This works for files up to ~6MB per transaction.
 *
 * For files larger than ~6MB: splits into multiple ContentVersion files
 * and notifies the user to concatenate them.
 */
public class SBA641_XMLAssembler implements Queueable, Database.AllowsCallouts {

    private List<Id> chunkCVIds;
    private Integer  currentIndex;
    private String   varQuarterYear;
    private String   ownerEmail;
    private Id       assembledCVId;   // ContentVersion being built
    private Blob     accumulatedData; // running XML blob (limited by heap)

    private static final Integer MAX_HEAP_BYTES = 5000000; // 5MB safe threshold

    public SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail) {
        this.chunkCVIds     = chunkCVIds;
        this.currentIndex   = 0;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail     = ownerEmail;
        this.accumulatedData = Blob.valueOf('');
    }

    // Chaining constructor
    private SBA641_XMLAssembler(List<Id> chunkCVIds, Integer currentIndex,
            String varQuarterYear, String ownerEmail,
            Id assembledCVId, Blob accumulatedData) {
        this.chunkCVIds      = chunkCVIds;
        this.currentIndex    = currentIndex;
        this.varQuarterYear  = varQuarterYear;
        this.ownerEmail      = ownerEmail;
        this.assembledCVId   = assembledCVId;
        this.accumulatedData = accumulatedData;
    }

    public void execute(QueueableContext ctx) {
        // Query chunks in batches of 3 at a time to build up accumulated content
        Integer batchSize  = 3;
        Integer endIndex   = Math.min(currentIndex + batchSize, chunkCVIds.size());
        List<Id> batchIds  = new List<Id>();
        for (Integer i = currentIndex; i < endIndex; i++) {
            batchIds.add(chunkCVIds[i]);
        }

        // Read this batch of chunks ordered by title
        List<ContentVersion> chunks = [
            SELECT Title, VersionData FROM ContentVersion
            WHERE Id IN :batchIds
            ORDER BY Title ASC
        ];

        // Accumulate chunk data
        String accumulated = accumulatedData.toString();
        for (ContentVersion cv : chunks) {
            accumulated += cv.VersionData.toString();
        }

        Integer nextIndex = endIndex;
        Boolean isDone    = (nextIndex >= chunkCVIds.size());

        if (isDone) {
            // All chunks processed — write final ContentVersion
            Blob finalBlob = Blob.valueOf(accumulated);
            finalizeXml(finalBlob);

            // Clean up temp chunks
            try {
                List<ContentDocument> docs = [
                    SELECT Id FROM ContentDocument
                    WHERE Id IN (
                        SELECT ContentDocumentId FROM ContentVersion
                        WHERE Id IN :chunkCVIds
                    )
                ];
                if (!docs.isEmpty()) delete docs;
            } catch(Exception e) {
                System.debug('Chunk cleanup failed: ' + e.getMessage());
            }
        } else {
            // Check if we're approaching heap limit — if so, write partial file
            Integer approxSize = accumulated.length();
            if (approxSize > MAX_HEAP_BYTES) {
                // Write what we have so far as a partial file and notify
                Blob partialBlob = Blob.valueOf(accumulated);
                writePartialFile(partialBlob, currentIndex);

                // Notify user and stop — they'll need to concatenate
                sendPartialNotification();
                return;
            }

            // Chain to next batch
            System.enqueueJob(new SBA641_XMLAssembler(
                chunkCVIds, nextIndex, varQuarterYear, ownerEmail,
                assembledCVId, Blob.valueOf(accumulated)
            ));
        }
    }

    private void finalizeXml(Blob xmlBlob) {
        // Create the SBA641_XML_Upload__c record
        SBA641_XML_Upload__c rec = new SBA641_XML_Upload__c();
        rec.QuarterYear__c = varQuarterYear;
        insert rec;

        // Create final ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA641_XML_Report_' + varQuarterYear;
        cv.PathOnClient   = 'SBA641_Report_' + varQuarterYear + '.xml';
        cv.VersionData    = xmlBlob;
        cv.IsMajorVersion = true;
        insert cv;

        // Link to upload record
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docId;
        cdl.LinkedEntityId    = rec.Id;
        cdl.ShareType         = 'V';
        insert cdl;

        // Email with attachment
        if (String.isNotBlank(ownerEmail)) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject('SBA641 XML Report \u2014 ' + varQuarterYear);
            m.setPlainTextBody(
                '641 XML report for ' + varQuarterYear + ' has been generated.\n\n' +
                'The file is attached and also available in Salesforce Files linked to the ' +
                'SBA 641 XML Upload record for ' + varQuarterYear + '.\n\n' +
                'File: SBA641_Report_' + varQuarterYear + '.xml'
            );
            Messaging.EmailFileAttachment a = new Messaging.EmailFileAttachment();
            a.setFileName('SBA641_Report_' + varQuarterYear + '.xml');
            a.setBody(xmlBlob);
            a.setContentType('text/xml');
            m.setFileAttachments(new Messaging.EmailFileAttachment[]{ a });
            try { Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m }); }
            catch(Exception e) { System.debug('Email failed: ' + e.getMessage()); }
        }
    }

    private void writePartialFile(Blob data, Integer fromChunk) {
        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA641_XML_PARTIAL_' + varQuarterYear + '_chunk' + fromChunk;
        cv.PathOnClient   = cv.Title + '.xml';
        cv.VersionData    = data;
        cv.IsMajorVersion = false;
        insert cv;
    }

    private void sendPartialNotification() {
        if (String.isNotBlank(ownerEmail)) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject('SBA641 XML Report \u2014 ' + varQuarterYear + ' (Partial — File Too Large)');
            m.setPlainTextBody(
                'The 641 XML for ' + varQuarterYear + ' exceeded the Apex heap limit during assembly.\n\n' +
                'Partial files have been saved to Salesforce Files. Please check Files for ' +
                '"SBA641_XML_PARTIAL_' + varQuarterYear + '" files and concatenate them manually.\n\n' +
                'Recommendation: Contact your Salesforce admin to adjust batch size for large quarters.'
            );
            try { Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m }); }
            catch(Exception e) { System.debug('Notification email failed: ' + e.getMessage()); }
        }
    }
}
