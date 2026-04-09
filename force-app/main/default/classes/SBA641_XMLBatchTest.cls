@isTest
public class SBA641_XMLBatchTest {

    private static SBA_641_Output__c createTestRecord(String quarterYear) {
        SBA_641_Output__c record = new SBA_641_Output__c();
        record.Quarter_Year__c = quarterYear;
        record.PartnerClientNumber__c = '12345';
        record.LocationCode__c = 'LOC1';
        record.LastClientNamePart1__c = 'Doe';
        record.FirstClientNamePart1__c = 'John';
        record.EmailClientRequest__c = 'john.doe@example.com';
        record.PrimaryPhonePart1__c = '123-456-7890';
        record.SecondaryPhonePart1__c = '987-654-3210';
        record.Street1AddressPart1__c = '123 Main St';
        record.CityAddressPart1__c = 'Metropolis';
        record.StateAddressPart1__c = 'CA';
        record.ZipCodeAddressPart1__c = '90001';
        record.CountryAddressPart1__c = 'USA';
        record.SurveyAgreement__c = true;
        record.DateClientSignature__c = Date.today();
        record.OnFileClientSignature__c = true;
        record.RaceClientIntake__c = 'Race 1';
        record.SelfDescribedRaceClientIntake__c = 'Self-Described Race';
        record.EthnicityClientIntake__c = 'Ethnicity 1';
        record.SexClientIntake__c = 'Male';
        record.DisabilityClientIntake__c = 'No';
        record.MilitaryStatusClientIntake__c = 'Member of National Guard';
        record.BranchOfService_ClientIntake__c = 'Army';
        record.Media_ClientIntake__c = 'Internet';
        record.Other_Media_ClientIntake__c = 'Other Media';
        record.CurrentlyInBusiness_ClientIntake__c = 'Yes';
        record.CurrentlyExporting_ClientIntake__c = true;
        record.CompanyName_ClientIntake__c = 'Test Company';
        record.BusinessType_ClientIntake__c = 'Administrative and Support';
        record.BusinessOwnership_Female__c = 30;
        record.Certified8a_ClientIntake__c = 'Yes';
        record.TotalNumberofEmployees_ClientIntake__c = 50;
        record.NumberOfEmployeesInExportingBusiness__c = 10;
        record.GrossRevenues_ClientAnnualIncomePart2__c = 1000000;
        record.ProfitLoss_ClientAnnualIncomePart2__c = 200000;
        record.ExportGrossRevenuesOrSales__c = 500000;
        record.LegalEntity_ClientIntake__c = 'LLC';
        record.LegalEntity_Other_ClientIntake__c = 'None';
        record.ExportCountries_ClientIntake__c = 'USA, Canada';
        record.PartnerSessionNumber_Counselor__c = 'PS123';
        record.FundingSource_CounselorRecord__c = '2023 Portable Assistance - PA2023';
        record.DateCounseled_CounselorRecord__c = Date.today();
        record.CounselorName_CounselorRecord__c = 'Counselor One';
        record.CounselingHours_Contact__c = 10;
        record.CounselingHours_Prepare__c = 5;
        record.CounselingHours_Travel__c = 2;
        record.FirstClientNamePart3__c = 'John';
        record.LastClientNamePart3__c = 'Doe';
        record.Email_CounselorRecord__c = 'john.doe.counselor@example.com';
        record.Primary_PhonePart3__c = '123-456-7890';
        record.BusinessStartDatePart3__c = Date.today();
        record.TotalNumberOfEmployees_CounselorRecord__c = 50;
        record.NumberOfEmployeesExportingBusiness_Part3__c = 10;
        record.GrossRevenues_ClientAnnualIncomePart3__c = 1000000;
        record.GrowthIndicator_ClientAnnualIncomePart3__c = 'Yes';
        insert record;
        return record;
    }

    @isTest
    static void testBatch() {
        String quarterYear = '2024-Q1';
        SBA_641_Output__c record1 = createTestRecord(quarterYear);

        Test.startTest();
        SBA641_XMLBatch batch = new SBA641_XMLBatch(quarterYear, 'Test Report');
        ID batchProcessId = Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}