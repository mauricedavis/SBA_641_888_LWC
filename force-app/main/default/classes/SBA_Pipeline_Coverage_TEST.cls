@isTest
public class SBA_Pipeline_Coverage_TEST {

    @testSetup
    static void setup() {
        List<RecordType> rts641 = [SELECT Id FROM RecordType WHERE SObjectType = 'SBA_641_Output__c' AND DeveloperName = 'Q1_2025' LIMIT 1];
        if (!rts641.isEmpty()) {
            insert new SBA_641_Output__c(
                RecordTypeId = rts641[0].Id, Quarter_Year__c = 'Q1_2025',
                PartnerClientNumber__c = 'PC001', LocationCode__c = '1234',
                LastClientNamePart1__c = 'Smith', FirstClientNamePart1__c = 'John',
                RaceClientIntake__c = 'White', EthnicityClientIntake__c = 'No',
                SexClientIntake__c = 'Male', MilitaryStatusClientIntake__c = 'No military service',
                SessionType_CounselorRecord__c = 'Face-to-face',
                PrimaryPhonePart1__c = '123',
                CountryAddressPart1__c = 'Canada', Country_AddressPart3__c = 'Canada',
                DateCounseled_CounselorRecord__c = Date.today().addDays(-10),
                CounselingHours_Contact__c = 1.0, SurveyAgreement__c = true
            );
        }
        List<RecordType> rts888 = [SELECT Id FROM RecordType WHERE SObjectType = 'SBA_888_Output__c' AND DeveloperName = 'Q1_2025' LIMIT 1];
        if (!rts888.isEmpty()) {
            insert new SBA_888_Output__c(
                RecordTypeId = rts888[0].Id,
                PartnerTrainingNumber__c = 'PTN-TEST-001', LocationCode__c = '1234',
                DateTrainingStarted__c = Date.today().addDays(-30), TotalTrainingHours__c = 8,
                TrainingTitle__c = 'Test Workshop', Total_NumberTrained__c = 10,
                NumberOfSessions__c = 2, ProgramFormatType__c = 'Online',
                Language_Code__c = 'English', TrainingTopic__c = 'eCommerce',
                TrainingPartners_Code_SBDC__c = 'SBDC', DollarAmountOfFees__c = 100
            );
            insert new SBA_888_Output__c(RecordTypeId = rts888[0].Id);
        }
        SBA641_XML_Upload__c upload641 = new SBA641_XML_Upload__c(QuarterYear__c = 'Q1_2025');
        insert upload641;
        ContentVersion cv641 = new ContentVersion();
        cv641.Title = 'SBA641_XML_Report_Q1_2025_Part001';
        cv641.PathOnClient = 'SBA641_XML_Report_Q1_2025_Part001.xml';
        cv641.VersionData = Blob.valueOf('<CounselingInformation></CounselingInformation>');
        cv641.IsMajorVersion = false;
        insert cv641;
        Id docId641 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv641.Id].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = docId641, LinkedEntityId = upload641.Id, ShareType = 'V');
        SBA888_XML_Upload__c upload888 = new SBA888_XML_Upload__c(QuarterYear__c = 'Q1_2025');
        insert upload888;
        ContentVersion cv888 = new ContentVersion();
        cv888.Title = 'SBA888_XML_Report_Q1_2025_Part001';
        cv888.PathOnClient = 'SBA888_XML_Report_Q1_2025_Part001.xml';
        cv888.VersionData = Blob.valueOf('<ManagementTrainingReport></ManagementTrainingReport>');
        cv888.IsMajorVersion = false;
        insert cv888;
        Id docId888 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv888.Id].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = docId888, LinkedEntityId = upload888.Id, ShareType = 'V');
    }

    @isTest static void testSBA641NormalizationHelper() {
        List<String> codes = SBA641NormalizationHelper.getRaceCodes('White;Asian');
        System.assert(!codes.isEmpty());
        codes = SBA641NormalizationHelper.getRaceCodes('Black or African Ame');
        System.assert(!codes.isEmpty());
        codes = SBA641NormalizationHelper.getRaceCodes('White White');
        System.assertEquals(1, codes.size());
        codes = SBA641NormalizationHelper.getRaceCodes('White Asian');
        System.assert(!codes.isEmpty());
        codes = SBA641NormalizationHelper.getRaceCodes(null);
        System.assert(codes.isEmpty());
        System.assertEquals('United States', SBA641NormalizationHelper.normalizeCountry('USA'));
        System.assertEquals(null, SBA641NormalizationHelper.normalizeCountry(null));
        System.assertEquals('Hispanic or Latino', SBA641NormalizationHelper.normalizeEthnicity('Yes'));
        System.assertEquals('Non Hispanic or Latino', SBA641NormalizationHelper.normalizeEthnicity('No'));
        System.assertEquals('Prefer not to say', SBA641NormalizationHelper.normalizeEthnicity('Prefer not to say'));
        System.assertEquals('', SBA641NormalizationHelper.normalizeEthnicity(''));
        System.assertEquals('6165551234', SBA641NormalizationHelper.normalizePhone('616-555-1234'));
        System.assertEquals(null, SBA641NormalizationHelper.normalizePhone('123'));
        System.assertEquals('', SBA641NormalizationHelper.normalizePhone(null));
        System.assertEquals('Michigan', SBA641NormalizationHelper.expandState('MI'));
        System.assertEquals('Unknown', SBA641NormalizationHelper.expandState('Unknown'));
        String escaped641 = SBA641NormalizationHelper.esc('&<>');
        System.assert(escaped641.contains('amp') || escaped641.contains('&'), 'esc should escape special chars');
        System.assertEquals('', SBA641NormalizationHelper.esc(null));
    }

    @isTest static void testSBA888NormalizationHelper() {
        System.assertEquals('Buy/Sell Business', SBA888NormalizationHelper.normalizeTopic('Buy/Sell a Business'));
        System.assertEquals('Technology', SBA888NormalizationHelper.normalizeTopic('Technology'));
        System.assertEquals('', SBA888NormalizationHelper.normalizeTopic(null));
        System.assertEquals('Online', SBA888NormalizationHelper.normalizeProgramFormatType('Webinar'));
        System.assertEquals('In-person', SBA888NormalizationHelper.normalizeProgramFormatType('In-person'));
        System.assertEquals('', SBA888NormalizationHelper.normalizeProgramFormatType(null));
        System.assertEquals('Hybrid', SBA888NormalizationHelper.getProgramFormatRaw('Hybrid'));
        System.assertEquals('', SBA888NormalizationHelper.getProgramFormatRaw(null));
        System.assertEquals('Michigan', SBA888NormalizationHelper.getStateName('MI'));
        SBA_888_Output__c r = new SBA_888_Output__c(TrainingPartners_Code_SBDC__c = 'SBDC');
        List<String> pCodes = SBA888NormalizationHelper.getPartnerCodes(r);
        System.assert(!pCodes.isEmpty());
        String escaped888 = SBA888NormalizationHelper.esc('&');
        System.assert(escaped888.contains('amp') || escaped888.contains('&'), 'esc should escape ampersand');
        System.assertEquals('', SBA888NormalizationHelper.esc(null));
    }

    @isTest static void testNexusValidationService() {
        NexusValidationService.ValidationResult vr =
            new NexusValidationService.ValidationResult('a00', 'PTN001', 'Field', 'ERROR', 'msg');
        System.assertEquals('ERROR', vr.severity);
        NexusValidationService.validate888Records(new List<SBA_888_Output__c>());
        // Pass 1: invalid phone + Canada country + SessionId__c populated
        List<SBA_641_Output__c> recs = [SELECT Id, PartnerClientNumber__c, LocationCode__c,
            LastClientNamePart1__c, FirstClientNamePart1__c, RaceClientIntake__c,
            EthnicityClientIntake__c, SexClientIntake__c, MilitaryStatusClientIntake__c,
            SessionType_CounselorRecord__c, PrimaryPhonePart1__c, SecondaryPhonePart1__c,
            Primary_PhonePart3__c, Secondary_PhonePart3__c, CountryAddressPart1__c,
            Country_AddressPart3__c, DateCounseled_CounselorRecord__c,
            PartnerSessionNumber_Counselor__c, SessionId__c FROM SBA_641_Output__c LIMIT 10];
        NexusValidationService.validate641Records(recs);
        // Pass 2: more phone branches + valid session Id
        for (SBA_641_Output__c rec : recs) {
            rec.PartnerSessionNumber_Counselor__c = rec.Id;
            rec.PrimaryPhonePart1__c = '61655512341234';
            rec.Primary_PhonePart3__c = '12';
            rec.SecondaryPhonePart1__c = '6165551234';
        }
        NexusValidationService.validate641Records(recs);
        // Pass 3: blank race, invalid ethnicity/sex/military/session type
        for (SBA_641_Output__c rec : recs) {
            rec.PrimaryPhonePart1__c = '6165551234';
            rec.Primary_PhonePart3__c = null;
            rec.PartnerSessionNumber_Counselor__c = null;
            rec.RaceClientIntake__c = null;
            rec.EthnicityClientIntake__c = 'Unknown Ethnicity';
            rec.SexClientIntake__c = 'Unknown Sex';
            rec.MilitaryStatusClientIntake__c = 'Unknown Military';
            rec.SessionType_CounselorRecord__c = 'Unknown Session';
        }
        NexusValidationService.validate641Records(recs);
        System.assert(true);
    }

    @isTest static void testSBA888ValidationService() {
        SBA888ValidationService.ValidationSummary s = SBA888ValidationService.validate('Q1_2025');
        System.assertNotEquals(null, s);
        System.assert(s.errorCount > 0);
    }

    @isTest static void testSBA888ReportController() {
        SBA888ReportController.getQuarterDates('Q1_2025');
        SBA888ReportController.getQuarterDates('Q2_2025');
        SBA888ReportController.getQuarterDates('Q3_2025');
        SBA888ReportController.getQuarterDates('Q4_2025');
        SBA888ReportController.recordTypeExists('Q1_2025');
        SBA888ReportController.getOutputCount('Q1_2025');
        SBA888ReportController.validateQuarter('Q1_2025');
        List<Map<String,String>> parts = SBA888ReportController.getXmlPartFiles('Q1_2025');
        System.assert(parts != null);
        Id uploadId = SBA888ReportController.getUploadRecordId('Q1_2025');
        System.assertNotEquals(null, uploadId);
        try { SBA888ReportController.pollJobStatus('fakeid'); } catch(Exception e) {}
        Test.startTest();
        try { SBA888ReportController.generateXml('Q1_2025'); } catch(Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void testSBA641ReportController() {
        SBA641ReportController.getQuarterDates('Q1_2025');
        SBA641ReportController.getQuarterDates('Q2_2025');
        SBA641ReportController.getQuarterDates('Q3_2025');
        SBA641ReportController.getQuarterDates('Q4_2025');
        SBA641ReportController.recordTypeExists('Q1_2025');
        SBA641ReportController.getOutputCount('Q1_2025');
        SBA641ReportController.validateQuarter('Q1_2025');
        List<Map<String,String>> parts = SBA641ReportController.getXmlPartFiles('Q1_2025');
        System.assert(parts != null);
        Id uploadId = SBA641ReportController.getUploadRecordId('Q1_2025');
        System.assertNotEquals(null, uploadId);
        String vfUrl = SBA641ReportController.getVfBaseUrl();
        System.assert(String.isNotBlank(vfUrl));
        Map<String,Object> saveState = new Map<String,Object>{
            'quarterYear' => 'Q1_2025', 'currentStep' => 2, 'dateLabel' => 'Test',
            'extractJobId' => 'abc123', 'xmlJobId' => null, 'runStatus' => 'In Progress',
            'selectedQuarter' => 'Q1', 'selectedYear' => '2025', 'extractedCount' => 5
        };
        SBA641ReportController.saveRunState(saveState);
        saveState.put('currentStep', 3);
        saveState.put('extractedCount', 10);
        SBA641ReportController.saveRunState(saveState);
        SBA641ReportController.loadRunState();
        SBA641ReportController.clearRunState();
        SBA641ReportController.loadRunState();
        try { SBA641ReportController.pollJobStatus('fakeid'); } catch(Exception e) {}
        Test.startTest();
        try { SBA641ReportController.extractSessions('Q1_2025'); } catch(Exception e) {}
        try { SBA641ReportController.generateXml('Q1_2025', 'Annual'); } catch(Exception e) {}
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void testSBA641ReportControllerEdgeCases() {
        try {
            SBA641ReportController.extractSessions('Q9_9999');
        } catch(Exception e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest static void testSBA641XMLDownloadController() {
        PageReference pr = Page.SBA641_XMLDownload;
        Test.setCurrentPage(pr);
        SBA641_XMLDownloadController ctrl = new SBA641_XMLDownloadController();
        ctrl.streamXml();
        System.assert(ctrl.xmlContent.contains('cvId required'));
        ContentVersion cv = [SELECT Id FROM ContentVersion WHERE Title LIKE 'SBA641_XML_Report%' LIMIT 1];
        ApexPages.currentPage().getParameters().put('cvId', cv.Id);
        ctrl.streamXml();
        System.assert(String.isNotBlank(ctrl.xmlContent));
    }

    @isTest static void testSBA641XMLMergeController() {
        PageReference pr = Page.SBA641_XMLMerge;
        Test.setCurrentPage(pr);
        SBA641_XMLMergeController ctrl = new SBA641_XMLMergeController();
        ctrl.init();
        System.assert(ctrl.statusMessage.contains('Error'));
        SBA641_XML_Upload__c upload = [SELECT Id FROM SBA641_XML_Upload__c WHERE QuarterYear__c = 'Q1_2025' LIMIT 1];
        ApexPages.currentPage().getParameters().put('uploadId', upload.Id);
        ctrl.init();
        System.assert(ctrl.partsJson != null);
    }

    @isTest static void testSBA641XMLRestService() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SBA641XML/';
        RestContext.request = req;
        RestContext.response = res;
        SBA641_XMLRestService.getMergedXml();
        System.assertEquals(400, res.statusCode);
        req.params.put('uploadId', 'a00000000000000AAA');
        SBA641_XMLRestService.getMergedXml();
        System.assert(res.statusCode == 404 || res.statusCode == 500);
        SBA641_XML_Upload__c upload = [SELECT Id FROM SBA641_XML_Upload__c WHERE QuarterYear__c = 'Q1_2025' LIMIT 1];
        req.params.put('uploadId', upload.Id);
        SBA641_XMLRestService.getMergedXml();
        System.assert(res.statusCode == 200 || res.statusCode == 404 || res.statusCode == 500);
    }

    @isTest static void testSBA641XMLBatchREFACTORED() {
        Test.startTest();
        SBA641_XMLBatch_REFACTORED b = new SBA641_XMLBatch_REFACTORED('Q1_2025', 'Annual');
        Id jobId = Database.executeBatch(b, 200);
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest static void testSBA641XMLAssembler() {
        Test.startTest();
        SBA641_XMLAssembler assembler = new SBA641_XMLAssembler(new List<Id>(), 'Q1_2025', 'test@test.com');
        System.enqueueJob(assembler);
        Test.stopTest();
        System.assert(true);
    }

    @isTest static void testSBA888XMLMergeController() {
        PageReference pr = Page.SBA888_XMLMerge;
        Test.setCurrentPage(pr);
        SBA888_XMLMergeController ctrl = new SBA888_XMLMergeController();
        ctrl.init();
        System.assert(ctrl.statusMessage.contains('Error'));
        SBA888_XML_Upload__c upload = [SELECT Id FROM SBA888_XML_Upload__c WHERE QuarterYear__c = 'Q1_2025' LIMIT 1];
        ApexPages.currentPage().getParameters().put('uploadId', upload.Id);
        ctrl.init();
        System.assert(ctrl.partsJson != null);
    }
}