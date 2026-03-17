public with sharing class SBA888BatchFlow {

    @InvocableMethod(label='Start SBA888 Batch' description='Invoke the batch to process SBA888 data')
    public static void invokeBatch(List<FlowInput> input) {
        Date startDate = input[0].startDate;
        Date endDate = input[0].endDate;
        String varRecordTypeId = input[0].varRecordTypeId;
        String varQuarterYear = input[0].varQuarterYear;

        System.debug('Start Date: ' + startDate);
        System.debug('End Date: ' + endDate);
        System.debug('RecordTypeId: ' + varRecordTypeId);
        System.debug('Quarter_Year): ' + varQuarterYear);

        SBA888Batch batch = new SBA888Batch(startDate, endDate, varRecordTypeId, varQuarterYear);
        Database.executeBatch(batch, 200);
    }

    public class FlowInput {
        @InvocableVariable(required=true) public Date startDate;
        @InvocableVariable(required=true) public Date endDate;
        @InvocableVariable(required=true) public String varRecordTypeId;
        @InvocableVariable(required=true) public String varQuarterYear;
    }
}
