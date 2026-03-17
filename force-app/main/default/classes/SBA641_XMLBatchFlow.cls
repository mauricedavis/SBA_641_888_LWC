public with sharing class SBA641_XMLBatchFlow {

    @InvocableMethod(label='Start SBA641 XML Batch' description='Invoke the batch to process SBA641 XML data')
    public static void invokeBatch(List<FlowInput> input) {
        String varQuarterYear = input[0].varQuarterYear;
        String varReportType = input[0].varReportType;

        System.debug('Quarter Year: ' + varQuarterYear);
        System.debug('Report Type: ' + varReportType);

        SBA641_XMLBatch batch = new SBA641_XMLBatch(varQuarterYear, varReportType);
        Database.executeBatch(batch, 10);
    }

    public class FlowInput {
        @InvocableVariable(required=true) public String varQuarterYear;
        @InvocableVariable(required=true) public String varReportType;
    }
}
