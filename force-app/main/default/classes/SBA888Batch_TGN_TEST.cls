@isTest
private class SBA888Batch_TGN_TEST{
    private class SBA888Batch_DBC_TGN_TEST implements Database.BatchableContext{
        private ID job,childJob;
        public SBA888Batch_DBC_TGN_TEST(ID job,ID childJob){
            this.job=job;
            this.childJob=childJob;
        }
        public ID getChildJobID(){
            return childJob;
        }
        public ID getJobID(){
            return job;
        }
    }
    
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
            Total_Full_Price_Atttendees__c =5,
            Total_Discounted_Attendees__c =4.4,
            Verified__c= true,
            Bypass_Record_Lock__c =true,
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

        // Fetch or create a safe RecordTypeId for SBA_888_Output__c
        Id outputRecordTypeId = Schema.SObjectType.SBA_888_Output__c.getRecordTypeInfosByDeveloperName().get('Q4_2024').getRecordTypeId();

        // Insert a sample SBA_888_Output__c record
        SBA_888_Output__c outputRecord = new SBA_888_Output__c(
            PartnerTrainingNumber__c = testEvent.EDMIS_Key__c,
            LocationCode__c = testEvent.EDMIS_Location_Id__c,
            Total_NumberTrained__c = testEvent.Total_Trained__c,
            ProgramFormatType__c = 'Online', 
            TrainingTopic__c = 'Business Start-up/Preplanning',
            Quarter_Year__c = 'Q3_2025',
            RecordTypeId = outputRecordTypeId
        );

        insert outputRecord;
    }
    @isTest
    private static void execute_TGN_TEST(){
        Test.startTest();
        Id recordTypeId = Schema.SObjectType.SBA_888_Output__c.getRecordTypeInfosByDeveloperName()
            .get('Q4_2025').getRecordTypeId();
        SBA888Batch obj = new SBA888Batch(Date.today()-100,Date.today()+1,recordTypeId,'Q4_2025');
        
        Database.executeBatch(obj,1);
       // obj.execute(new SBA888Batch_DBC_TGN_TEST('01205000002NNdaAAG','001x00000000000AAA'),new List<conference360__Event__c>{new conference360__Event__c()});
    //    obj = new SBA888Batch(null,null,'','');
    //    obj.execute(new SBA888Batch_DBC_TGN_TEST('01205000002NNdaAAG','001x00000000000AAA'),new List<conference360__Event__c>{new conference360__Event__c()});
    //    obj = new SBA888Batch(Date.today(),Date.today(),'a','a');//
    //    obj.execute(null,null);
    //    obj = new SBA888Batch(null,null,'','');
     //   obj.execute(null,null);
     //   
     
        
      
        Test.stopTest();
    }
    @isTest
    private static void finish_TGN_TEST(){
        Test.startTest();
        SBA888Batch obj = new SBA888Batch(Date.today(),Date.today(),'a','a');
        obj.finish(new SBA888Batch_DBC_TGN_TEST('001x00000000000AAA','001x00000000000AAA'));
        obj = new SBA888Batch(null,null,'','');
        obj.finish(new SBA888Batch_DBC_TGN_TEST('001x00000000000AAA','001x00000000000AAA'));
        obj = new SBA888Batch(Date.today(),Date.today(),'a','a');
        obj.finish(null);
        obj = new SBA888Batch(null,null,'','');
        obj.finish(null);
        Test.stopTest();
    }
}