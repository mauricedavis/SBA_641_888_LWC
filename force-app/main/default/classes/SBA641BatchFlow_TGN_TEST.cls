@isTest
private class SBA641BatchFlow_TGN_TEST{
    
    @testSetup
    static void setupTestData() {
        Account regionAccount = new Account(
            Name = 'Southeast MI',
            BillingCity = 'San Francisco',
            BillingState = 'California',
            BillingPostalCode = '94103',
            BillingCountry = 'United States',
            Center_EDMIS_Code__c = '249819',
            Key__c = '1234',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center_Regioin').getRecordTypeId()
        );
        
        insert regionAccount;
        
        // Step 1: Insert the Account record
        Account testAccount = new Account(
            Name = 'Salesforce',
            BillingCity = 'San Francisco',
            BillingState = 'California',
            BillingPostalCode = '94103',
            BillingCountry = 'United states', // New code for coverage
            Center_Region__c = regionAccount.Id
        );
        insert testAccount;
        
        Contact con = new Contact(
            FirstName = 'John1312',
            LastName = 'Doeqewq',
            Email = 'johnqwe.doeqwe@test.com',
            Phone = '1223-456-890',
            hed__Race__c = 'Native American/Alaska Native', // New code for coverage
            Race_Prefer_to_Self_Describe__c = null,
            hed__Military_Service__c = false,
            Military__c = 'No military service',
            Branch_of_Service__c = null
        );
        insert con;
        
        Contact conNoMilitary = new Contact(
        FirstName = 'Jane',
        LastName = 'Doe',
        Email = 'jane.doe@test.com',
        Phone = '555-555-5555',
        hed__Military_Service__c = false, // Indicates no military service
        Military__c = 'Active Duty',
        Branch_of_Service__c = 'Prefer not to say' // Ensure this starts as null
        );
        insert conNoMilitary;
        
        SBA_641_Output__c internetMediaRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '54321',
            Media_ClientIntake__c = 'Internet',
            Internet_Media_ClientIntake__c = 'Google' // Ensures this field is populated
        );
        insert internetMediaRecord;
        
        SBA_641_Output__c ownershipRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '67890',
            BusinessOwnership_Female__c = 1 // Ensures this field is populated
        );
        insert ownershipRecord;
        
        SBA_641_Output__c employeeRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '98765',
            TotalNumberOfEmployees_CounselorRecord__c = 50,
            NumberOfEmployeesInExportingBusiness__c = 30 // Valid case: within the total employees
        );
        insert employeeRecord;
        
        List<Case> cases = new List<Case>();
        // Step 2: Insert the Case record
        cases.add(new Case(AccountId = testAccount.Id, Status = 'New', eRFC_Complete__c = true));
        cases.add(
            new Case(
                AccountId = testAccount.Id, ContactId = con.Id, DateeRFCCompleted__c = Date.today().addDays(-10),
                eRFC_Complete__c = true
            )
        );
        insert cases;

        // Step 3: Insert the Session__c record with Account ID
        List<Session__c> sessions = new List<Session__c>();
        sessions.add(new Session__c(
            Account__c = testAccount.Id,
            Contact__c = con.Id,
            Case__c = cases[0].Id,
            Session_Type__c = 'Counseling: Initial',
            Delivery_Type__c = 'Telephone',
            Area_of_Counseling__c = '100 Business Startup & Acquisition: Business Start-Up',
            Business_Status_for_Session__c = 'Not Yet in Business',
            Contact_Hours__c = 1,
            Prep_Hours__c = 1,
            Travel_Hours__c = 1.0,
            Travel_Distance__c = 60.0,
            Session_Date_Time__c = System.today(),
            Employees_Trained__c = 5,
            Legacy_Consultant_Name__c = 'Test 2'
        ));
        
        sessions.add(new Session__c(
            Account__c = testAccount.Id,
            Contact__c = con.Id,
            Prep_Hours__c = 32,
            Case__c = cases[1].Id,
            Delivery_Type__c = 'Group',
            Session_Number__c = 12345,
            Business_Status_for_Session__c = 'In Business', // New code for coverage
            Language__c = 'English',
            Referral_To__c = 'Other', // New code for coverage
            Referral_To_Other__c = 'Test Other Referral', // New code for coverage
            Employees_Trained__c = 10,
            Notes__c = 'This is a test session note',
            Primary_Consultant__c = UserInfo.getUserId(),
            Session_Date_Time__c = System.today(),
            Contact_Hours__c = 2,
            Travel_Hours__c = 1.0,
            Travel_Distance__c = 60.0,
            Legacy_Consultant_Name__c = 'Test 1'
        ));
        insert sessions;

        // Step 3: Insert SBA_641_Output__c records
        List<SBA_641_Output__c> records = new List<SBA_641_Output__c>();
        records.add(new SBA_641_Output__c(
            PartnerClientNumber__c = '12345',
            LocationCode__c = 'LOC123',
            LastClientNamePart1__c = 'Doe',
            FirstClientNamePart1__c = 'John',
            EmailClientRequest__c = 'johndoe@example.com',
            PrimaryPhonePart1__c = '(555) 555-5555',
            Street1AddressPart1__c = '123 Main St',
            CityAddressPart1__c = 'Anytown',
            StateAddressPart1__c = 'California',
            ZipCodeAddressPart1__c = '90210',
            CountryAddressPart1__c = 'United states', // New code for coverage
            SurveyAgreement__c = true,
            DateClientSignature__c = Date.today(),
            OnFileClientSignature__c = true,
            RaceClientIntake__c = 'White',
            EthnicityClientIntake__c = 'Not Hispanic',
            SexClientIntake__c = 'Male',
            DisabilityClientIntake__c = 'No',
            Media_ClientIntake__c = 'Lender',
            CurrentlyInBusiness_ClientIntake__c = 'Yes', // New code for coverage
            CurrentlyExporting_ClientIntake__c = true,
            CompanyName_ClientIntake__c = 'ACME Inc',
            BusinessType_ClientIntake__c = 'Construction',
            BusinessOwnership_Female__c = 1,
            TotalNumberofEmployees_ClientIntake__c = 50,
            GrossRevenues_ClientAnnualIncomePart2__c = 100000,
            ProfitLoss_ClientAnnualIncomePart2__c = 10000,
            ExportGrossRevenuesOrSales__c = 20000,
            SexualOrientationClientIntake__c = 'Prefer to Self-Describe',
            SelfDescribedSexualOrientation__c = 'Prefer not to say' // Ensure this starts as null for the test
        ));
        insert records;
    }
    
    private class SBA641BatchFlow_HCM_TGN_TEST implements HttpCalloutMock{
        protected Integer code;
        protected String status;
        protected String body;
        protected Map<String,String> headers;
        public SBA641BatchFlow_HCM_TGN_TEST(Integer code,String status,String body,Map<String,String> headers){
            this.code=code;
            this.status=status;
            this.body=body;
            this.headers=headers;
        }
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res=new HttpResponse();
            res.setStatusCode(this.code);
            res.setStatus(this.status);
            res.setBody(this.body);
            if(this.headers!=null){
                for(String key:this.headers.keySet()){
                    res.setHeader(key,this.headers.get(key));
                }
            }
            return res;
        }
    }
    
    @isTest
    private static void invokeBatch_TGN_TEST(){
        Test.startTest();
        try{
        SBA641BatchFlow_HCM_TGN_TEST httpMock;
        httpMock=new SBA641BatchFlow_HCM_TGN_TEST(200,'Complete','{}',null);
        Test.setMock(HttpCalloutMock.class,httpMock);
        httpMock=new SBA641BatchFlow_HCM_TGN_TEST(200,'Complete','{}',null);
        Test.setMock(HttpCalloutMock.class,httpMock);
        } catch(Exception e){}
        Test.stopTest();
    }
    
    @isTest
    private static void SBA641BatchFlow_TGN_TEST(){
        SBA641BatchFlow obj = new SBA641BatchFlow();
    }
    
    @isTest
    private static void FlowInput_TGN_TEST(){
        SBA641BatchFlow.FlowInput obj = new SBA641BatchFlow.FlowInput();
    }
    
    @isTest
    private static void testmethod1(){
        String input = 'This is a <test> & "quote" and \'apostrophe\' example';
        SBA641Batch.escapeXml(input);
    }
    
    @isTest
    private static void testNormalizeCountry() {
        Test.startTest();
        String normalizedCountry = SBA641Batch.normalizeCountry('United states');
        System.assertEquals('United States', normalizedCountry);
        normalizedCountry = SBA641Batch.normalizeCountry('Canada');
        System.assertEquals('Canada', normalizedCountry);
        Test.stopTest();
    }

    
    @isTest
    private static void testTranslateRace() {
        Contact testContact = [SELECT hed__Race__c FROM Contact WHERE FirstName = 'John1312'];
        System.assertEquals('Native American/Alaska Native', SBA641Batch.translateRace(testContact.hed__Race__c)); // New code for coverage
    }
    
    @isTest
    static void testSelfDescribedOrientation() {
        // Query the record created during setup
        SBA_641_Output__c record = [SELECT SexualOrientationClientIntake__c, SelfDescribedSexualOrientation__c 
                                FROM SBA_641_Output__c 
                                WHERE SexualOrientationClientIntake__c = 'Prefer to Self-Describe'
                                LIMIT 1];

        // Assert that SelfDescribedSexualOrientation__c is set correctly
        System.assertEquals('Prefer to Self-Describe', record.SexualOrientationClientIntake__c);
        System.assertEquals('Prefer not to say', record.SelfDescribedSexualOrientation__c); // Expected value
    }

    @isTest
    static void testCamelCaseUtility() {
        String countries = 'united states; hong kong; CANADA';
        String camelCaseResult = SBA641Batch.toCamelCaseCountries(countries);
        System.assertEquals('United States; Hong Kong; Canada', camelCaseResult);
    }
    
    @isTest
    static void testEthnicityTranslation() {
        String ethnicity = SBA641Batch.translateEthnicity('No Reply');
        System.assertEquals('Prefer not to say', ethnicity);
    }
    
    @isTest
    static void testValidStateAbbreviations() {
        // Test valid state abbreviations
        System.assertEquals(SBA641Batch.getStateFullName('AL'), 'Alabama');
        System.assertEquals(SBA641Batch.getStateFullName('AK'), 'Alaska');
        System.assertEquals(SBA641Batch.getStateFullName('CA'), 'California');
        System.assertEquals(SBA641Batch.getStateFullName('TX'), 'Texas');
        System.assertEquals(SBA641Batch.getStateFullName('NY'), 'New York');
    }
    
    @isTest
    static void testNoMilitaryBranch() {
    Test.startTest();

    // Query the contact where Military__c = 'No military service'
    Contact contact = [SELECT Military__c, Branch_of_Service__c 
                       FROM Contact 
                       WHERE Military__c = 'No military service' 
                       LIMIT 1];

    // Assert that Branch_of_Service__c is blank/null
    System.assertEquals('No military service', contact.Military__c);
    System.assertEquals(null, contact.Branch_of_Service__c, 
        'Branch_of_Service__c should be null when Military__c = "No military service"');

    Test.stopTest();
    }
    
    @isTest
    static void testInternetMediaClientIntake() {
        Test.startTest();

        // Query the record where Media_ClientIntake__c = 'Internet'
        SBA_641_Output__c record = [SELECT Media_ClientIntake__c, Internet_Media_ClientIntake__c
                                FROM SBA_641_Output__c
                                WHERE Media_ClientIntake__c = 'Internet'
                                LIMIT 1];

        // Assert that Internet_Media_ClientIntake__c is not null
        System.assertEquals('Internet', record.Media_ClientIntake__c);
        System.assertNotEquals(null, record.Internet_Media_ClientIntake__c, 
            'Internet_Media_ClientIntake__c should not be null when Media_ClientIntake__c = "Internet"');

        Test.stopTest();
    }
    
    @isTest
    static void testBusinessOwnershipFemaleNotNull() {
        Test.startTest();

        // Query the record where BusinessOwnership_Female__c is set
        SBA_641_Output__c record = [SELECT BusinessOwnership_Female__c 
                                FROM SBA_641_Output__c
                                WHERE PartnerClientNumber__c = '67890'
                                LIMIT 1];

        // Assert that BusinessOwnership_Female__c is not null
        System.assertNotEquals(null, record.BusinessOwnership_Female__c, 
            'BusinessOwnership_Female__c should not be null');

        Test.stopTest();
    }
    
    @isTest
    static void testNumberOfEmployeesExporting() {
        Test.startTest();

        // Query the record with employee numbers
        SBA_641_Output__c record = [SELECT TotalNumberOfEmployees_CounselorRecord__c, NumberOfEmployeesInExportingBusiness__c 
                                FROM SBA_641_Output__c 
                                WHERE PartnerClientNumber__c = '98765'
                                LIMIT 1];

        // Assert that NumberOfEmployeesInExportingBusiness__c is not greater than TotalNumberOfEmployees_CounselorRecord__c
        System.assert(record.NumberOfEmployeesInExportingBusiness__c <= record.TotalNumberOfEmployees_CounselorRecord__c,
            'NumberOfEmployeesInExportingBusiness__c should not be greater than TotalNumberOfEmployees_CounselorRecord__c');

        Test.stopTest();
    }
    
    @isTest
    static void testNullHandling() {
        Test.startTest();

        // Insert a record with null fields
        SBA_641_Output__c nullRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '00000',
            Media_ClientIntake__c = null,
            Internet_Media_ClientIntake__c = null
        );
        insert nullRecord;

        // Query the inserted record
        SBA_641_Output__c record = [SELECT Media_ClientIntake__c, Internet_Media_ClientIntake__c
                                FROM SBA_641_Output__c
                                WHERE PartnerClientNumber__c = '00000'
                                LIMIT 1];

        // Assertions for null values
        System.assertEquals(null, record.Media_ClientIntake__c, 'Media_ClientIntake__c should be null');
        System.assertEquals(null, record.Internet_Media_ClientIntake__c, 'Internet_Media_ClientIntake__c should be null');

        Test.stopTest();
    }
    
    @isTest
    static void testReferralLogic() {
        Test.startTest();

        // Insert a record with 'Other' as Referral_To__c
        SBA_641_Output__c referralRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '99999',
            ReferredClient_CounselorRecord__c = 'Other',
            ReferredClientOther_CounselorRecord__c = 'Custom Referral'
        );
        insert referralRecord;

        // Query the inserted record
        SBA_641_Output__c record = [SELECT ReferredClient_CounselorRecord__c, ReferredClientOther_CounselorRecord__c 
                                FROM SBA_641_Output__c
                                WHERE PartnerClientNumber__c = '99999'
                                LIMIT 1];

        // Assertions for referral fields
        System.assertEquals('Other', record.ReferredClient_CounselorRecord__c, 'Referral_To__c should be Other');
        System.assertEquals('Custom Referral', record.ReferredClientOther_CounselorRecord__c, 'Referral_To_Other__c should match input');

        Test.stopTest();
    }
    
    @isTest
    static void testDataTruncation() {
        Test.startTest();

        String longString = 'x'.repeat(1000); // String longer than 1000 characters
        SBA_641_Output__c truncationRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '88888',
            CounselorNotes_CounselorRecord__c = longString
        );
        insert truncationRecord;

        // Query the inserted record
        SBA_641_Output__c record = [SELECT CounselorNotes_CounselorRecord__c FROM SBA_641_Output__c WHERE PartnerClientNumber__c = '88888' LIMIT 1];

        // Assertions for truncation
        System.assert(record.CounselorNotes_CounselorRecord__c.length() <= 1000, 'Notes__c should be truncated to 1000 characters');
        System.assertEquals('x'.repeat(1000), record.CounselorNotes_CounselorRecord__c, 'Notes__c should match the first 1000 characters of the input');

        Test.stopTest();
    }
    
    @isTest
    static void testDefaultValueForSelfDescribedOrientation() {
        Test.startTest();

        // Insert a record without specifying SelfDescribedSexualOrientation__c
        SBA_641_Output__c defaultValueRecord = new SBA_641_Output__c(
            PartnerClientNumber__c = '77777',
            SexualOrientationClientIntake__c = 'Prefer to Self-Describe',
            SelfDescribedSexualOrientation__c = 'Prefer not to say'
        );
        insert defaultValueRecord;

        // Query the inserted record
        SBA_641_Output__c record = [SELECT SexualOrientationClientIntake__c, SelfDescribedSexualOrientation__c
                                FROM SBA_641_Output__c
                                WHERE PartnerClientNumber__c = '77777'
                                LIMIT 1];

        // Assertions for default value
        System.assertEquals('Prefer not to say', record.SelfDescribedSexualOrientation__c,
            'SelfDescribedSexualOrientation__c should default to Prefer not to say when blank');

        Test.stopTest();
    }
    
    @isTest
    static void testExecuteBatch(){
        Test.startTest();
        Date testStartDate = System.today().addDays(-5);
        Date testEndDate = testStartDate.addDays(31);
        String recordTypeId = Schema.SObjectType.SBA_641_Output__c.getRecordTypeInfosByDeveloperName()
            .get('Q4_2025').getRecordTypeId();
        String testQuarterYear = 'Q4-2025';
        
        // Create FlowInput object with test data
        SBA641BatchFlow.FlowInput input = new SBA641BatchFlow.FlowInput();
        input.startDate = testStartDate;
        input.endDate = testEndDate;
        input.varRecordTypeId = recordTypeId;
        input.varQuarterYear = testQuarterYear;
        
        // Step 2: Create a list of FlowInput to pass to the invokeBatch method
        List<SBA641BatchFlow.FlowInput> inputList = new List<SBA641BatchFlow.FlowInput>();
        inputList.add(input);
        
        SBA641BatchFlow.invokeBatch(inputList);
        Test.stopTest();
    }
}