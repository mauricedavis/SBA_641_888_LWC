public with sharing class SBA888_XMLBatchFlow {

    @InvocableMethod(label='Start SBA888 XML Batch' description='Invoke the batch to generate XML for SBA888 records')
    public static void invokeBatch(List<FlowInput> input) {
        String varQuarterYear = input[0].varQuarterYear;
        String varReportType = input[0].varReportType;

        System.debug('Quarter Year: ' + varQuarterYear);
        System.debug('Report Type: ' + varReportType);

        SBA888_XMLBatch batch = new SBA888_XMLBatch(varQuarterYear, varReportType);
        Database.executeBatch(batch, 200);
    }

    public class FlowInput {
        @InvocableVariable(required=true) public String varQuarterYear;
        @InvocableVariable(required=true) public String varReportType;
    }
}
