public with sharing class SBA641BatchFlow {

    @InvocableMethod(label='Start SBA641 Batch' description='Invoke the batch to process SBA641 data')
    public static void invokeBatch(List<FlowInput> input) {
        Date startDate = input[0].startDate;
        Date endDate = input[0].endDate;
        String varRecordTypeId = input[0].varRecordTypeId;
        String varQuarterYear = input[0].varQuarterYear;

        System.debug('Start Date: ' + startDate);
        System.debug('End Date: ' + endDate);
        System.debug('RecordTypeId: ' + varRecordTypeId);
        System.debug('Quarter_Year): ' + varQuarterYear);

        SBA641Batch batch = new SBA641Batch(startDate, endDate, varRecordTypeId, varQuarterYear);
        Database.executeBatch(batch, 10);
    }

    public class FlowInput {
        @InvocableVariable(required=true) public Date startDate;
        @InvocableVariable(required=true) public Date endDate;
        @InvocableVariable(required=true) public String varRecordTypeId;
        @InvocableVariable(required=true) public String varQuarterYear;
    }
}
