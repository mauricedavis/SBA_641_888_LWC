@isTest
public class SBA888_BatchFlowTest {
    
    @isTest
    static void testInvokeBatch() {
        // Retrieve an existing RecordType Id for SBA_888_Output__c
        RecordType testRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'SBA_888_Output__c' LIMIT 1];

        // Prepare input for Flow
        SBA888BatchFlow.FlowInput flowInput = new SBA888BatchFlow.FlowInput();
        flowInput.startDate = Date.today().addMonths(-1);  // Example start date
        flowInput.endDate = Date.today();  // Example end date
        flowInput.varRecordTypeId = testRecordType.Id;  // Assigning the existing record type
        flowInput.varQuarterYear = 'Q1_2024';  // Example Quarter_Year
        
        // Add input to list as invokeBatch expects a list of FlowInput
        List<SBA888BatchFlow.FlowInput> flowInputs = new List<SBA888BatchFlow.FlowInput>{ flowInput };

        Test.startTest();
        // Call the invocable method
        SBA888BatchFlow.invokeBatch(flowInputs);

        // Since Database.executeBatch is asynchronous, we use Test.stopTest() to ensure it completes.
        Test.stopTest();

        // Assert that the batch job has been executed and completed successfully
        Integer batchJobCount = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex' AND Status = 'Completed'];
        System.assert(batchJobCount > 0, 'Batch job should be completed successfully');
    }
}