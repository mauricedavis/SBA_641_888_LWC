@isTest
public class SBA641_BatchFlowTest {
    
    @testSetup
    static void setupTestData() {
        // Step 1: Create an Account record
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingPostalCode = '94103',
            BillingCountry = 'USA'
        );
        insert testAccount;
                
        // Step 2: Insert the Case record
        Case testCase = new Case(
            AccountId = testAccount.Id,
            Status = 'New',
            eRFC_Complete__c = true
            // Populate other necessary fields for Case if required
        );
        insert testCase;

        // Step 2: Create a Session record related to the Account
        Session__c testSession = new Session__c(
            Account__c = testAccount.Id,
            Case__c = testCase.Id, // Reference the created Case record
            Delivery_Type__c = 'Telephone',  // Ensure this matches criteria in your batch job
            Session_Type__c = 'Counseling: Initial',
            Area_of_Counseling__c = '100 Business Startup & Acquisition: Business Start-Up',
            Business_Status_for_Session__c = 'In Business',
            Contact_Hours__c = 0.5,
            Prep_Hours__c = 0.5,
            Travel_Hours__c = 1.0,
            Travel_Distance__c = 60.0
        );
        insert testSession;
    }

    @isTest
    public static void testInvokeBatch() {
        // Define test dates for the batch query
        Date testStartDate = Date.today().addMonths(-1);
        Date testEndDate = Date.today();

        // Retrieve the RecordTypeId, if needed
        Id recordTypeId;
        Map<String, Schema.RecordTypeInfo> recordTypes = Schema.SObjectType.Session__c.getRecordTypeInfosByName();
        if (recordTypes.containsKey('Test Record Type')) {
            recordTypeId = recordTypes.get('Test Record Type').getRecordTypeId();
        } else {
            System.debug('Record type not found, adjust this logic or add record type to avoid failure');
            return;
        }

        // Initialize Flow Input
        SBA641BatchFlow.FlowInput input = new SBA641BatchFlow.FlowInput();
        input.startDate = testStartDate;
        input.endDate = testEndDate;
        input.varRecordTypeId = recordTypeId;

        List<SBA641BatchFlow.FlowInput> inputs = new List<SBA641BatchFlow.FlowInput> { input };

        // Run the batch and start test
        Test.startTest();
        SBA641BatchFlow.invokeBatch(inputs);
        Test.stopTest();

        // Fetch output records and validate
        List<SBA_641_Output__c> outputRecords = [SELECT Id, PartnerSessionNumber_Counselor__c FROM SBA_641_Output__c];
        
        // Debug output to verify batch processing
        System.debug('Output records: ' + outputRecords);
        
        // Assertion to ensure records are created
        System.assert(!outputRecords.isEmpty(), 'Expected output records to be created');
        System.assertEquals(1, outputRecords.size(), 'Expected one output record');
    }
}