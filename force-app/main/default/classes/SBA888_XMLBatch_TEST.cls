@isTest
public class SBA888_XMLBatch_TEST {

    @testSetup
    static void setupTestData() {
        List<SBA_888_Output__c> sbaRecords = new List<SBA_888_Output__c>();

        sbaRecords.add(new SBA_888_Output__c(
            PartnerTrainingNumber__c = 'PTN123',
            LocationCode__c = 'LC001',
            DateTrainingStarted__c = Date.today().addDays(-30),
            TotalTrainingHours__c = 8,
            TrainingTitle__c = 'Small Business Workshop',
            City_TrainingLocation__c = 'San Francisco',
            State_TrainingLocation__c = 'California',
            ZipCode_TrainingLocation__c = '94103',
            Country_TrainingLocation__c = 'United States',
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
            CoSponsorsName__c = 'Local Chamber of Commerce',
            TrainingPartners_Code_SBA__c = 'Yes',
            TrainingPartners_Other_OtherResources__c = 'Community Partner',
            White_NumberTrained__c = 30
        ));

        insert sbaRecords;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();

        String varQuarterYear = 'Q1_2024';
        String varReportType = 'Annual';

        SBA888_XMLBatch batchJob = new SBA888_XMLBatch(varQuarterYear, varReportType);
        Database.executeBatch(batchJob, 10);

        Test.stopTest();

        List<SBA888_XML_Upload__c> xmlUploads = [SELECT Id, QuarterYear__c FROM SBA888_XML_Upload__c];
        System.assertEquals(1, xmlUploads.size(), 'Expected one SBA888_XML_Upload__c record to be created.');
        System.assertEquals(varQuarterYear, xmlUploads[0].QuarterYear__c, 'Expected Quarter_Year__c to match the passed variable.');

        List<ContentVersion> contentVersions = [SELECT Id, Title FROM ContentVersion WHERE Title LIKE 'SBA888_XML_Report_%'];
        System.assert(contentVersions.size() > 0, 'Expected ContentVersion record to be created.');
    }
}
