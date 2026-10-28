@isTest
public class SBA888_XMLBatch_TEST {

    @testSetup
    static void setupTestData() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'SBA_888_Output__c'
            AND DeveloperName = 'Q1_2024'
            LIMIT 1
        ];
        if (rts.isEmpty()) return; // RecordType not present — skip insert

        insert new SBA_888_Output__c(
            RecordTypeId = rts[0].Id,
            PartnerTrainingNumber__c = 'PTN123',
            LocationCode__c = '1234',
            DateTrainingStarted__c = Date.today().addDays(-30),
            TotalTrainingHours__c = 8,
            TrainingTitle__c = 'Small Business Workshop',
            City_TrainingLocation__c = 'San Francisco',
            State_TrainingLocation__c = 'California',
            ZipCode_TrainingLocation__c = '94103',
            Country_TrainingLocation__c = 'US',
            Total_NumberTrained__c = 100,
            CurrentlyInBusiness_NumberTrained__c = 60,
            NotYetInBusiness_NumberTrained__c = 40,
            PersonWithDisabilities_NumberTrained__c = 5,
            Female_NumberTrained__c = 40,
            Veterans_NumberTrained__c = 10,
            TrainingTopic__c = 'eCommerce',
            LGBTQ_NumberTrained__c = 3,
            ActiveDuty_NumberTrained__c = 2,
            Asian_NumberTrained__c = 10,
            BlackOrAfricanAmerican_NumberTrained__c = 8,
            DollarAmountOfFees__c = 2000,
            HispanicOrLatinoOrigin_NumberTrained__c = 15,
            Language_Code__c = 'English',
            MemberOfReserveOrNationalGuard_NumberTra__c = 4,
            NativeAmericanOrAlaskaNative_NumberTrain__c = 2,
            NativeHawaiinOrPacificIslander_NumberTra__c = 1,
            NonHispanicOrLatinoOrigin_NumberTrained__c = 85,
            NorthAfrican_NumberTrained__c = 1,
            NumberOfSessions__c = 3,
            ProgramFormatType__c = 'Online',
            ServiceDisabledVeterans_NumberTrained__c = 1,
            SpouseOfMilitaryMember_NumberTrained__c = 2,
            Total_NumberMinoritiesTrained__c = 40,
            SponsorName__c = 'SBA',
            CoSponsorsName__c = 'Local Chamber',
            TrainingPartners_Code_SBA__c = 'Yes',
            TrainingPartners_Other_OtherResources__c = 'Community Partner',
            White_NumberTrained__c = 30
        );
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        SBA888_XMLBatch batchJob = new SBA888_XMLBatch('Q1_2024', 'Annual');
        Id jobId = Database.executeBatch(batchJob, 200);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Batch job should have been enqueued.');
    }

    @isTest
    static void testOneArgConstructor() {
        Test.startTest();
        SBA888_XMLBatch batchJob = new SBA888_XMLBatch('Q1_2024');
        Id jobId = Database.executeBatch(batchJob, 200);
        Test.stopTest();
        System.assertNotEquals(null, jobId, '1-arg constructor batch job should have been enqueued.');
    }

    @isTest
    static void testFourArgConstructor() {
        Test.startTest();
        SBA888_XMLBatch batchJob = new SBA888_XMLBatch(
            Date.today().addDays(-90), Date.today(), 'Q1_2024', 'Annual'
        );
        Id jobId = Database.executeBatch(batchJob, 200);
        Test.stopTest();
        System.assertNotEquals(null, jobId, '4-arg constructor batch job should have been enqueued.');
    }

    // ── SBA888_XMLBatch_REFACTORED coverage ───────────────────────────────────
    @isTest
    static void testRefactoredBatchExecution() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'SBA_888_Output__c'
            AND DeveloperName = 'Q1_2024'
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            insert new SBA_888_Output__c(
                RecordTypeId = rts[0].Id,
                Quarter_Year__c = 'Q3_2026',
                PartnerTrainingNumber__c = 'PTN-REF-001',
                LocationCode__c = '5678',
                DateTrainingStarted__c = Date.today().addDays(-5),
                TotalTrainingHours__c = 4,
                TrainingTitle__c = 'Refactored Workshop',
                Total_NumberTrained__c = 5,
                NumberOfSessions__c = 1,
                ProgramFormatType__c = 'Online',
                Language_Code__c = 'English',
                TrainingTopic__c = 'eCommerce',
                TrainingPartners_Code_SBDC__c = 'SBDC',
                DollarAmountOfFees__c = 50,
                HispanicOrLatinoOrigin_NumberTrained__c = 1,
                Female_NumberTrained__c = 2,
                White_NumberTrained__c = 3
            );
        }
        Test.startTest();
        SBA888_XMLBatch_REFACTORED batchJob = new SBA888_XMLBatch_REFACTORED('Q3_2026', 'Annual');
        Id jobId = Database.executeBatch(batchJob, 200);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'REFACTORED batch job should have been enqueued.');
        List<SBA888_XML_Upload__c> uploads = [SELECT Id FROM SBA888_XML_Upload__c WHERE QuarterYear__c = 'Q3_2026'];
        System.assertEquals(1, uploads.size(), 'REFACTORED finish() should insert an upload record');
    }
}