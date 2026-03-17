@isTest
public class SBA641_XMLBatch_TEST {

    @testSetup
    static void setupTestData() {
        List<SBA_641_Output__c> records = new List<SBA_641_Output__c>();

        records.add(new SBA_641_Output__c(
            PartnerClientNumber__c = '12345',
            LocationCode__c = 'LOC123',
            LastClientNamePart1__c = 'Doe',
            FirstClientNamePart1__c = 'John',
            EmailClientRequest__c = 'johndoe@example.com',
            PrimaryPhonePart1__c = '(555) 555-5555',
            SecondaryPhonePart1__c = '(555) 555-5556',
            Street1AddressPart1__c = '123 Main St',
            CityAddressPart1__c = 'Anytown',
            StateAddressPart1__c = 'CA',
            ZipCodeAddressPart1__c = '90210',
            CountryAddressPart1__c = 'USA',
            SurveyAgreement__c = true,
            DateClientSignature__c = Date.today(),
            OnFileClientSignature__c = true,
            RaceClientIntake__c = 'White',
            EthnicityClientIntake__c = 'Hispanic or Latino',
            SexClientIntake__c = 'Male',
            DisabilityClientIntake__c = 'No',
            MilitaryStatusClientIntake__c = 'No military service',
            Media_ClientIntake__c = 'Lender',
            Other_Media_ClientIntake__c = 'Community Partner',
            CurrentlyInBusiness_ClientIntake__c = 'Yes',
            CurrentlyExporting_ClientIntake__c = true,
            CompanyName_ClientIntake__c = 'ACME Inc',
            BusinessOwnership_Female__c = 0,
            ConductingBusinessOnline_ClientIntake__c = 'Yes',
            Certified8a_ClientIntake__c = 'Yes',
            TotalNumberofEmployees_ClientIntake__c = 100,
            NumberOfEmployeesInExportingBusiness__c = 10,
            GrossRevenues_ClientAnnualIncomePart2__c = 500000,
            ProfitLoss_ClientAnnualIncomePart2__c = 50000,
            ExportGrossRevenuesOrSales__c = 20000,
            LegalEntity_ClientIntake__c = 'Corporation',
            LegalEntity_Other_ClientIntake__c = 'Other',
            ExportCountries_ClientIntake__c = 'Mexico,Canada',
            PartnerSessionNumber_Counselor__c = '123456',
            DateCounseled_CounselorRecord__c = Date.today(),
            CounselorName_CounselorRecord__c = 'Jane Smith',
            CounselingHours_Contact__c = 2.0,
            CounselingHours_Prepare__c = 1.5,
            CounselingHours_Travel__c = 0.5
        ));

        insert records;
    }

    @isTest
    static void testSBA641_XMLBatch() {
        Test.startTest();

        String varQuarterYear = 'Q1_2024';
        String varReportType = 'Counseling';

        SBA641_XMLBatch batchJob = new SBA641_XMLBatch(varQuarterYear, varReportType);
        Database.executeBatch(batchJob, 10);

        Test.stopTest();

        List<SBA641_XML_Upload__c> xmlUploads = [SELECT Id, QuarterYear__c FROM SBA641_XML_Upload__c];
        System.assertEquals(1, xmlUploads.size(), 'Expected one SBA641_XML_Upload__c record.');
        System.assertEquals(varQuarterYear, xmlUploads[0].QuarterYear__c, 'QuarterYear__c should match input.');

        List<ContentVersion> contentVersions = [SELECT Id, Title, VersionData FROM ContentVersion WHERE Title LIKE 'SBA641_XML_Report_%'];
        System.assertEquals(1, contentVersions.size(), 'Expected one ContentVersion record.');
    }
}
