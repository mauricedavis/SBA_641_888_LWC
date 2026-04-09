@isTest
public class SBA641_XMLBatchFlow_TEST {

    @testSetup
    static void setupTestData() {
        // Create test data for SBA_641_Output__c
        List<SBA_641_Output__c> records = new List<SBA_641_Output__c>();

        records.add(new SBA_641_Output__c(
            PartnerClientNumber__c = '12345',
            LocationCode__c = 'LOC123',
            LastClientNamePart1__c = 'Doe',
            FirstClientNamePart1__c = 'John',
            EmailClientRequest__c = 'johndoe@example.com',
            PrimaryPhonePart1__c = '123-456-7890',
            SecondaryPhonePart1__c = '098-765-4321',
            Street1AddressPart1__c = '123 Elm St',
            CityAddressPart1__c = 'Metropolis',
            StateAddressPart1__c = 'California',
            ZipCodeAddressPart1__c = '94103',
            CountryAddressPart1__c = 'United States',
            SurveyAgreement__c = true,  // Set Boolean value directly
            DateClientSignature__c = Date.today(),
            OnFileClientSignature__c = true,  // Set Boolean value directly
            RaceClientIntake__c = 'White',
            SelfDescribedRaceClientIntake__c = 'Caucasian',
            EthnicityClientIntake__c = 'Not Hispanic',
            SexualOrientationClientIntake__c = 'Not LGBTQ',
            SelfDescribedSexualOrientation__c = 'Straight',
            SexClientIntake__c = 'Male',
            DisabilityClientIntake__c = 'No',
            MilitaryStatusClientIntake__c = 'No military service',
            Media_ClientIntake__c = 'Internet',
            Other_Media_ClientIntake__c = 'N/A',
            CurrentlyInBusiness_ClientIntake__c = 'Yes',
            CurrentlyExporting_ClientIntake__c = true,  // Set Boolean value directly
            CompanyName_ClientIntake__c = 'Doe Enterprises',
            BusinessOwnership_Female__c = 0,
            ConductingBusinessOnline_ClientIntake__c = 'Yes',
            Certified8a_ClientIntake__c = 'No',
            TotalNumberofEmployees_ClientIntake__c = 50,
            NumberOfEmployeesInExportingBusiness__c = 10,
            GrossRevenues_ClientAnnualIncomePart2__c = 1000000,
            ProfitLoss_ClientAnnualIncomePart2__c = 150000,
            ExportGrossRevenuesOrSales__c = 250000,
            LegalEntity_ClientIntake__c = 'LLC',
            LegalEntity_Other_ClientIntake__c = '',
            ExportCountries_ClientIntake__c = 'Canada, Mexico'
        ));
        
        insert records;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        
        // Setup input parameters for the flow
        SBA641_XMLBatchFlow.FlowInput flowInput = new SBA641_XMLBatchFlow.FlowInput();
        flowInput.varQuarterYear = 'Q1_2024';
        flowInput.varReportType = 'Counseling';

        // Add input to list as required by Invocable method
        List<SBA641_XMLBatchFlow.FlowInput> inputs = new List<SBA641_XMLBatchFlow.FlowInput>{ flowInput };

        // Execute the flow invocable method
        SBA641_XMLBatchFlow.invokeBatch(inputs);

        Test.stopTest();
        
        // Verify results, if any output data is expected
        List<SBA_641_Output__c> outputRecords = [SELECT Id, PartnerClientNumber__c FROM SBA_641_Output__c];
        System.assert(outputRecords.size() > 0, 'Expected at least one output record to be processed.');
    }
}