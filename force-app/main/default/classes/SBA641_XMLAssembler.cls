/**
 * SBA641_XMLAssembler
 * Assembles XML chunk ContentVersions into a final file.
 *
 * Uses a simple Queueable chain that reads chunks in small groups,
 * writes partial files, then uses a final pass to concatenate.
 *
 * For very large quarters, writes the final XML directly using
 * the standard ContentVersion insert — reading chunks in order
 * and building the string only up to the heap-safe limit per execution.
 *
 * If the total XML exceeds ~6MB (Apex heap safe limit for string ops),
 * the file is split into numbered parts and the user is notified.
 */
public class SBA641_XMLAssembler implements Queueable {

    private List<Id> chunkCVIds;
    private String   varQuarterYear;
    private String   ownerEmail;
    private Integer  currentIndex;
    private Integer  partNumber;
    private String   accumulated;

    private static final Integer HEAP_SAFE_CHARS = 3000000; // ~3MB safe threshold (conservative for 20k records)
    private static final Integer CHUNKS_PER_RUN  = 1;       // 1 chunk per execution — minimizes heap for large quarters

    // Initial constructor
    public SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail) {
        this.chunkCVIds    = chunkCVIds;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail    = ownerEmail;
        this.currentIndex  = 0;
        this.partNumber    = 1;
        this.accumulated   = '';
    }

    // Chaining constructor
    private SBA641_XMLAssembler(List<Id> chunkCVIds, String varQuarterYear, String ownerEmail,
            Integer currentIndex, Integer partNumber, String accumulated) {
        this.chunkCVIds    = chunkCVIds;
        this.varQuarterYear = varQuarterYear;
        this.ownerEmail    = ownerEmail;
        this.currentIndex  = currentIndex;
        this.partNumber    = partNumber;
        this.accumulated   = accumulated;
    }

    public void execute(QueueableContext ctx) {
        try {
            // Read next batch of chunks
            Integer endIdx = Math.min(currentIndex + CHUNKS_PER_RUN, chunkCVIds.size());
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
            Boolean allChunksDone = (nextIndex >= chunkCVIds.size());

            // Check if we need to flush to a part file
            if (accumulated.length() >= HEAP_SAFE_CHARS && !allChunksDone) {
                // Write this part and continue
                writePartFile(accumulated, partNumber);
                System.enqueueJob(new SBA641_XMLAssembler(
                    chunkCVIds, varQuarterYear, ownerEmail,
                    nextIndex, partNumber + 1, ''
                ));
                return;
            }

            if (allChunksDone) {
                // Add closing tag
                accumulated += '</CounselingInformation>\n';

                if (partNumber == 1) {
                    // Single part — write final file directly
                    writeFinalFile(accumulated);
                    cleanupChunks();
                    notifySuccess(1);
                } else {
                    // Multiple parts — write last part and notify
                    writePartFile(accumulated, partNumber);
                    cleanupChunks();
                    notifyMultipart(partNumber);
                }
            } else {
                // More chunks to process
                System.enqueueJob(new SBA641_XMLAssembler(
                    chunkCVIds, varQuarterYear, ownerEmail,
                    nextIndex, partNumber, accumulated
                ));
            }

        } catch (Exception e) {
            sendEmail(
                'SBA641 XML Assembly Error — ' + varQuarterYear,
                'Assembly failed at chunk ' + currentIndex + ':\n' +
                e.getMessage() + '\n\n' + e.getStackTraceString()
            );
        }
    }

    private void writeFinalFile(String xml) {
        SBA641_XML_Upload__c rec = new SBA641_XML_Upload__c();
        rec.QuarterYear__c = varQuarterYear;
        insert rec;

        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA641_XML_Report_' + varQuarterYear;
        cv.PathOnClient   = 'SBA641_Report_' + varQuarterYear + '.xml';
        cv.VersionData    = Blob.valueOf(xml);
        cv.IsMajorVersion = true;
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docId;
        cdl.LinkedEntityId    = rec.Id;
        cdl.ShareType         = 'V';
        insert cdl;
    }

    private void writePartFile(String xml, Integer partNum) {
        String partLabel = String.valueOf(partNum).leftPad(2, '0');
        ContentVersion cv = new ContentVersion();
        cv.Title          = 'SBA641_XML_Report_' + varQuarterYear + '_Part' + partLabel;
        cv.PathOnClient   = cv.Title + '.xml';
        cv.VersionData    = Blob.valueOf(xml);
        cv.IsMajorVersion = false;
        insert cv;
    }

    private void cleanupChunks() {
        try {
            List<ContentDocument> docs = [
                SELECT Id FROM ContentDocument
                WHERE Id IN (
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :chunkCVIds
                )
            ];
            if (!docs.isEmpty()) delete docs;
        } catch (Exception e) {
            System.debug('Chunk cleanup error: ' + e.getMessage());
        }
    }

    private void notifySuccess(Integer parts) {
        sendEmail(
            'SBA641 XML Report \u2014 ' + varQuarterYear,
            '641 XML report for ' + varQuarterYear + ' has been generated successfully.\n\n' +
            'The file is available in Salesforce Files linked to the ' +
            'SBA 641 XML Upload record for ' + varQuarterYear + '.\n\n' +
            'File: SBA641_Report_' + varQuarterYear + '.xml'
        );
    }

    private void notifyMultipart(Integer parts) {
        String partList = '';
        for (Integer i = 1; i <= parts; i++) {
            partList += '  SBA641_XML_Report_' + varQuarterYear + '_Part' + String.valueOf(i).leftPad(2, '0') + '.xml\n';
        }
        sendEmail(
            'SBA641 XML Report \u2014 ' + varQuarterYear + ' (' + parts + ' parts)',
            '641 XML for ' + varQuarterYear + ' was too large for a single file and has been split into ' + parts + ' parts.\n\n' +
            'Files saved to Salesforce Files:\n' + partList + '\n' +
            'To create the final submission file, concatenate these files in order:\n' +
            '  Windows: copy /b Part01.xml + Part02.xml SBA641_Report_' + varQuarterYear + '.xml\n' +
            '  Mac/Linux: cat Part01.xml Part02.xml > SBA641_Report_' + varQuarterYear + '.xml'
        );
    }

    private void sendEmail(String subject, String body) {
        if (String.isBlank(ownerEmail)) return;
        try {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject(subject);
            m.setPlainTextBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m });
        } catch (Exception e) {
            System.debug('Email error: ' + e.getMessage());
        }
    }
}
