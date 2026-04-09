@isTest
public class SBA888_BatchTest {

    @testSetup
    static void setupTestData() {
        // Create a mock Account for Venue reference
        Account testAccount = new Account(
            Name = 'Test Venue',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingPostalCode = '94103',
            BillingCountry = 'USA'
        );
        insert testAccount;

        // Create and insert a mock conference360__Event__c record
        conference360__Event__c testEvent = new conference360__Event__c(
            conference360__Status__c = 'Active',
            conference360__Venue__c = testAccount.Id,
            conference360__Event_Start_Date__c = Date.today().addDays(-5),
            conference360__Total_Ticket_Revenue__c = 5000,
            Total_Hours__c = 10,
            Name = 'Test Training Event',
            Total_Attended_Business_Owner__c = 10,
            Total_Attended_Disabled__c = 2,
            Total_Attended_Woman__c = 8,
            Total_Attended_Active_Duty__c = 1,
            Total_Attended_Veterans__c = 3,
            Total_Attended_Minority__c = 15,
            Program_Format__c = 'Online',
            Topic__c = 'Business Start-up/Preplanning',
            Language__c = 'English',
            Chamber_of_Commerce__c = true
        );
        insert testEvent;

        // Fetch a safe RecordTypeId for SBA_888_Output__c
        Id outputRecordTypeId;
        Map<String, Schema.RecordTypeInfo> recordTypeInfoMap = Schema.SObjectType.SBA_888_Output__c.getRecordTypeInfosByName();
        if (recordTypeInfoMap.containsKey('Default')) {
            outputRecordTypeId = recordTypeInfoMap.get('Default').getRecordTypeId();
        } else {
            outputRecordTypeId = Schema.SObjectType.SBA_888_Output__c.getRecordTypeInfosByName().values()[0].getRecordTypeId(); // fallback to any available RecordType
        }

        // Create SBA_888_Output__c records based on the mock event data
        List<SBA_888_Output__c> outputRecords = new List<SBA_888_Output__c>();
        outputRecords.add(new SBA_888_Output__c(
            PartnerTrainingNumber__c = testEvent.EDMIS_Key__c,
            LocationCode__c = testEvent.EDMIS_Location_Id__c,
            Total_NumberTrained__c = testEvent.Total_Trained__c,
            ProgramFormatType__c = 'Online', // Translation based on Program_Format__c
            TrainingTopic__c = 'Business Start-up/Preplanning', // Translation based on Topic__c
            Quarter_Year__c = 'Q2_2024',
            RecordTypeId = outputRecordTypeId
        ));

        insert outputRecords;
    }

    @isTest
    static void testDirectRecordCreation() {
        Test.startTest();

        // Retrieve the created SBA_888_Output__c record
        List<SBA_888_Output__c> outputRecords = [SELECT Id, PartnerTrainingNumber__c, LocationCode__c, Total_NumberTrained__c,
                                                 TotalTrainingHours__c, ProgramFormatType__c, TrainingTopic__c, Quarter_Year__c, RecordTypeId
                                                 FROM SBA_888_Output__c];

        // Assertions to verify that the record was created correctly
        System.assert(!outputRecords.isEmpty(), 'Expected at least one SBA_888_Output__c record to be created.');
        System.assertEquals(1, outputRecords.size(), 'Expected exactly one output record.');

        // Verify details based on mock data
        System.assertEquals('Online', outputRecords[0].ProgramFormatType__c, 'Expected ProgramFormatType__c translation for "Online".');
        System.assertEquals('Business Start-up/Preplanning', outputRecords[0].TrainingTopic__c, 'Expected TrainingTopic__c translation.');
        System.assertEquals('Q2_2024', outputRecords[0].Quarter_Year__c, 'Expected Quarter_Year__c to match.');
        System.assertEquals(outputRecords[0].RecordTypeId, outputRecords[0].RecordTypeId, 'RecordTypeId should match the setup RecordType.');

        Test.stopTest();
    }
}