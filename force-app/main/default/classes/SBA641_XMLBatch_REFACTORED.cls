/**
 * SBA641_XMLBatch_REFACTORED
 *
 * All bugs from SBA641_XMLBatch fixed:
 *   FIXED BUG-1: XML root emitted in start() + closed in finish() — NEVER in execute()
 *   FIXED BUG-2: No phone padding; invalid phones emit '' (flagged ERROR upstream)
 *   FIXED BUG-3: Race splits on ';', cleans space-duplicates, translates, deduplicates
 *                → emits multiple <Code> tags per XSD maxOccurs="unbounded"
 *   FIXED BUG-4: normalizeCountry() — any non-blank → 'United States'
 *   FIXED BUG-5: normalizeEthnicity() — 'No' → 'Non Hispanic or Latino'
 *   ADDED: <Operation> element (XSD change #105)
 *   ADDED: <Employee_Owned> field (XSD change #139)
 *   UPDATED: <Sex> field (XSD change #140 — renamed from Gender)
 *   REMOVED: SexualOrientation (XSD change #141)
 *   FIXED: FundingSource now populated from record (was static empty tag)
 *   Normalization delegated to SBA641NormalizationHelper
 *   Batch size: 200 (was 10)
 */
public with sharing class SBA641_XMLBatch_REFACTORED
        implements Database.Batchable<SObject>, Database.Stateful {

    private String varQuarterYear;
    private String varReportType;
    private List<String> xmlParts = new List<String>(); // PERF: List avoids quadratic string copy cost
    private String ownerEmail = '';

    public SBA641_XMLBatch_REFACTORED(String varQuarterYear, String varReportType) {
        this.varQuarterYear = varQuarterYear;
        this.varReportType  = varReportType;
    }

    @TestVisible public String getXmlOutput() { return String.join(xmlParts, ''); }

    // ── FIXED: root emitted exactly once here ─────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        xmlParts.add('<?xml version="1.0" encoding="UTF-8"?>\n');
        xmlParts.add('<CounselingInformation xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n');
        ownerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;

        return Database.getQueryLocator(
            'SELECT PartnerClientNumber__c, LocationCode__c,' +
            ' LastClientNamePart1__c, FirstClientNamePart1__c, MiddleClientNamePart1__c,' +
            ' EmailClientRequest__c, PrimaryPhonePart1__c, SecondaryPhonePart1__c,' +
            ' Street1AddressPart1__c, CityAddressPart1__c, StateAddressPart1__c,' +
            ' ZipCodeAddressPart1__c, CountryAddressPart1__c,' +
            ' SurveyAgreement__c, DateClientSignature__c, OnFileClientSignature__c,' +
            ' RaceClientIntake__c, SelfDescribedRaceClientIntake__c,' +
            ' EthnicityClientIntake__c, SexClientIntake__c, DisabilityClientIntake__c,' +
            ' MilitaryStatusClientIntake__c, BranchOfService_ClientIntake__c,' +
            ' Media_ClientIntake__c, Other_Media_ClientIntake__c, Internet_Media_ClientIntake__c,' +
            ' CurrentlyInBusiness_ClientIntake__c, CurrentlyExporting_ClientIntake__c,' +
            ' CompanyName_ClientIntake__c, BusinessType_ClientIntake__c,' +
            ' BusinessOwnership_Female__c, ConductingBusinessOnline_ClientIntake__c,' +
            ' Certified8a_ClientIntake__c, EmployeeOwned_ClientIntake__c,' +
            ' Rural_vs_Urban_ClientIntake__c, FIPS_Code_ClientIntake__c,' +
            ' TotalNumberofEmployees_ClientIntake__c, NumberOfEmployeesInExportingBusiness__c,' +
            ' GrossRevenues_ClientAnnualIncomePart2__c, ProfitLoss_ClientAnnualIncomePart2__c,' +
            ' ExportGrossRevenuesOrSales__c, LegalEntity_ClientIntake__c, LegalEntity_Other_ClientIntake__c,' +
            ' CounselingSeeking_ClientIntake__c, CounselingSeekingOther_ClientIntake__c,' +
            ' ExportCountries_ClientIntake__c,' +
            ' PartnerSessionNumber_Counselor__c, FundingSource_CounselorRecord__c,' +
            ' DateCounseled_CounselorRecord__c, CounselorName_CounselorRecord__c,' +
            ' CounselingHours_Contact__c, CounselingHours_Prepare__c, CounselingHours_Travel__c,' +
            ' FirstClientNamePart3__c, LastClientNamePart3__c, Email_CounselorRecord__c,' +
            ' Primary_PhonePart3__c, Secondary_PhonePart3__c,' +
            ' Language_CounselorRecord__c, LanguageOther_CounselorRecord__c,' +
            ' BusinessStartDatePart3__c, TotalNumberOfEmployees_CounselorRecord__c,' +
            ' NumberOfEmployeesExportingBusiness_Part3__c,' +
            ' GrossRevenues_ClientAnnualIncomePart3__c, GrowthIndicator_ClientAnnualIncomePart3__c,' +
            ' ProfitLoss_ClientAnnualIncomePart3__c, ExportGrossRevenuesOrSales_Part3__c,' +
            ' Certifications_CounselorRecord__c, CounselingProvided_CounselorRecord__c,' +
            ' CounselingProvidedOtherCounselorRecord__c,' +
            ' ReportableImpact__c, DateofReportableImpact__c,' +
            ' SBALoanAmount_CounselorRecord__c, NonSBALoanAmount_CounselorRecord__c,' +
            ' EquityCapitalReceived_CounselorRecord__c,' +
            ' SBALoanAmountTxnNmbCounselorRecord__c, NonSBALoanAmountTxnNmbCounselorRecord__c,' +
            ' EquityCapitalReceivedTxnNmbCounselorRec__c,' +
            ' ReferredClient_CounselorRecord__c, ReferredClientOther_CounselorRecord__c,' +
            ' SessionType_CounselorRecord__c,' +
            ' ExportCountries_CounselorRecord__c,' +
            ' DateTrainingStarted_CounselorRecord__c, PartnerTrainingNumber_CounselorRecord__c,' +
            ' EmployeesTrained_CounselorRecord__c, HoursTrained_CounselorRecord__c,' +
            ' Street1_AddressPart3__c, City_AddressPart3__c, State_AddressPart3__c,' +
            ' ZipCode_AddressPart3__c, Country_AddressPart3__c,' +
            ' VerifiedToBeInBusiness_CounselorRecord__c, CounselorNotes_CounselorRecord__c,' +
            ' CurrentlyExporting_CounselorRecord_Part3__c' +
            ' FROM SBA_641_Output__c' +
            ' WHERE Quarter_Year__c = :varQuarterYear'
        );
    }

    // ── execute: records only — NO root tag ───────────────────────────────────
    public void execute(Database.BatchableContext bc, List<SBA_641_Output__c> scope) {
        for (SBA_641_Output__c r : scope) {
            xmlParts.add('<CounselingRecord>\n');
            xmlParts.add('<Operation></Operation>\n'); // XSD change #105
            xmlParts.add(xt('PartnerClientNumber', r.PartnerClientNumber__c));
            xmlParts.add('<Location>' + xt('LocationCode', r.LocationCode__c) + '</Location>\n');

            // ClientRequest
            xmlParts.add('<ClientRequest>\n');
            xmlParts.add('<ClientNamePart1>'
                + xt('Last', r.LastClientNamePart1__c) + xt('First', r.FirstClientNamePart1__c)
                + xt('Middle', r.MiddleClientNamePart1__c) + '</ClientNamePart1>\n';
            xmlParts.add(xt('Email', r.EmailClientRequest__c));

            String ph1p = SBA641NormalizationHelper.normalizePhone(r.PrimaryPhonePart1__c);
            String ph1s = SBA641NormalizationHelper.normalizePhone(r.SecondaryPhonePart1__c);
            xmlParts.add('<PhonePart1>' + xt('Primary', ph1p != null ? ph1p : '') + xt('Secondary', ph1s != null ? ph1s : '') + '</PhonePart1>\n');

            String c1 = SBA641NormalizationHelper.normalizeCountry(r.CountryAddressPart1__c); // FIXED BUG-4
            xmlParts.add('<AddressPart1>'
                + xt('Street1', r.Street1AddressPart1__c) + '<Street2></Street2>'
                + xt('City', r.CityAddressPart1__c)
                + xt('State', SBA641NormalizationHelper.expandState(r.StateAddressPart1__c))
                + xt('ZipCode', r.ZipCodeAddressPart1__c) + '<Zip4Code></Zip4Code>'
                + '<Country>' + xt('Code', c1 != null ? c1 : '') + '</Country>'
                + '<PostalCode></PostalCode><StateOrProvince></StateOrProvince></AddressPart1>\n';

            xmlParts.add(xt('SurveyAgreement', r.SurveyAgreement__c == true ? 'Yes' : 'No'));
            xmlParts.add('<ClientSignature>'
                + xt('Date', r.DateClientSignature__c != null ? String.valueOf(r.DateClientSignature__c) : '')
                + xt('OnFile', r.OnFileClientSignature__c == true ? 'Yes' : 'No')
                + '</ClientSignature>\n';
            xmlParts.add('</ClientRequest>\n');

            // ClientIntake
            xmlParts.add('<ClientIntake>\n');

            // FIXED BUG-3: multi-value race
            List<String> raceCodes = SBA641NormalizationHelper.getRaceCodes(r.RaceClientIntake__c);
            xmlParts.add('<Race>\n');
            if (raceCodes.isEmpty()) {
                xmlParts.add('<Code>Prefer not to say</Code>\n'); // XSD requires at least one Code
            } else {
                for (String code : raceCodes) xmlParts.add(xt('Code', code));
            }
            xmlParts.add(xt('SelfDescribedRace', r.SelfDescribedRaceClientIntake__c));
            xmlParts.add('</Race>\n');

            // FIXED BUG-5: correct ethnicity mapping
            xmlParts.add(xt('Ethnicity', SBA641NormalizationHelper.normalizeEthnicity(r.EthnicityClientIntake__c)));
            xmlParts.add(xt('Sex', r.SexClientIntake__c)); // XSD change #140
            xmlParts.add(xt('Disability', r.DisabilityClientIntake__c));
            xmlParts.add(xt('MilitaryStatus', r.MilitaryStatusClientIntake__c));
            xmlParts.add(xt('BranchOfService', r.BranchOfService_ClientIntake__c));

            if (String.isBlank(r.Media_ClientIntake__c) && String.isBlank(r.Other_Media_ClientIntake__c)) {
                xmlParts.add('<Media />\n');
            } else {
                String otherMedia = (r.Media_ClientIntake__c == 'Other' && String.isBlank(r.Other_Media_ClientIntake__c))
                    ? 'Undetermined' : r.Other_Media_ClientIntake__c;
                xmlParts.add('<Media>' + xt('Code', r.Media_ClientIntake__c) + xt('Other', otherMedia) + '</Media>\n');
            }

            xmlParts.add(xt('Internet', r.Internet_Media_ClientIntake__c));
            xmlParts.add(xt('CurrentlyInBusiness', r.CurrentlyInBusiness_ClientIntake__c));
            xmlParts.add(xt('CurrentlyExporting', r.CurrentlyExporting_ClientIntake__c == true ? 'Yes' : 'No'));
            xmlParts.add(xt('CompanyName', r.CompanyName_ClientIntake__c));
            xmlParts.add(xt('BusinessType', r.BusinessType_ClientIntake__c));
            xmlParts.add('<BusinessOwnership>' + xt('Female', String.valueOf(r.BusinessOwnership_Female__c != null ? r.BusinessOwnership_Female__c : 0)) + '</BusinessOwnership>\n');
            xmlParts.add(xt('ConductingBusinessOnline', r.ConductingBusinessOnline_ClientIntake__c));
            xmlParts.add(xt('ClientIntake_Certified8a', r.Certified8a_ClientIntake__c != null ? r.Certified8a_ClientIntake__c : 'No'));
            if (String.isNotBlank(r.EmployeeOwned_ClientIntake__c)) xmlParts.add(xt('Employee_Owned', r.EmployeeOwned_ClientIntake__c)); // XSD change #139
            xmlParts.add(xt('TotalNumberOfEmployees', String.valueOf(r.TotalNumberofEmployees_ClientIntake__c != null ? r.TotalNumberofEmployees_ClientIntake__c : 0)));
            xmlParts.add(xt('NumberOfEmployeesInExportingBusiness', String.valueOf(r.NumberOfEmployeesInExportingBusiness__c != null ? r.NumberOfEmployeesInExportingBusiness__c : 0)));

            xmlParts.add('<ClientAnnualIncomePart2>'
                + xt('GrossRevenues', String.valueOf(r.GrossRevenues_ClientAnnualIncomePart2__c != null ? r.GrossRevenues_ClientAnnualIncomePart2__c : 0))
                + xt('ProfitLoss', String.valueOf(r.ProfitLoss_ClientAnnualIncomePart2__c != null ? r.ProfitLoss_ClientAnnualIncomePart2__c : 0))
                + xt('ExportGrossRevenuesOrSales', String.valueOf(r.ExportGrossRevenuesOrSales__c != null ? r.ExportGrossRevenuesOrSales__c : 0))
                + '</ClientAnnualIncomePart2>\n';

            xmlParts.add('<LegalEntity>' + xt('Code', r.LegalEntity_ClientIntake__c) + xt('Other', r.LegalEntity_Other_ClientIntake__c) + '</LegalEntity>\n');
            xmlParts.add(xt('Rural_vs_Urban', String.isBlank(r.Rural_vs_Urban_ClientIntake__c) ? 'Undetermined' : r.Rural_vs_Urban_ClientIntake__c));
            xmlParts.add(xt('FIPS_Code', r.FIPS_Code_ClientIntake__c));
            xmlParts.add('<CounselingSeeking>' + xt('Code', r.CounselingSeeking_ClientIntake__c) + xt('Other', r.CounselingSeekingOther_ClientIntake__c) + '</CounselingSeeking>\n');
            xmlParts.add(exportCountries(r.ExportCountries_ClientIntake__c));
            xmlParts.add('</ClientIntake>\n');

            // CounselorRecord
            xmlParts.add('<CounselorRecord>\n');
            xmlParts.add(xt('PartnerSessionNumber', r.PartnerSessionNumber_Counselor__c));
            xmlParts.add(xt('FundingSource', r.FundingSource_CounselorRecord__c)); // FIXED: was static empty
            xmlParts.add('<ClientNamePart3>' + xt('Last', r.LastClientNamePart3__c) + xt('First', r.FirstClientNamePart3__c) + '<Middle></Middle></ClientNamePart3>\n');
            xmlParts.add(xt('Email', r.Email_CounselorRecord__c));

            String ph3p = SBA641NormalizationHelper.normalizePhone(r.Primary_PhonePart3__c);
            String ph3s = SBA641NormalizationHelper.normalizePhone(r.Secondary_PhonePart3__c);
            xmlParts.add('<PhonePart3>' + xt('Primary', ph3p != null ? ph3p : '') + xt('Secondary', ph3s != null ? ph3s : '') + '</PhonePart3>\n');

            String c3 = SBA641NormalizationHelper.normalizeCountry(r.Country_AddressPart3__c); // FIXED BUG-4
            xmlParts.add('<AddressPart3>'
                + xt('Street1', r.Street1_AddressPart3__c) + '<Street2></Street2>'
                + xt('City', r.City_AddressPart3__c)
                + xt('State', SBA641NormalizationHelper.expandState(r.State_AddressPart3__c))
                + xt('ZipCode', r.ZipCode_AddressPart3__c) + '<Zip4Code></Zip4Code>'
                + '<Country>' + xt('Code', c3 != null ? c3 : '') + '</Country>'
                + '<PostalCode></PostalCode><StateOrProvince></StateOrProvince></AddressPart3>\n';

            xmlParts.add(xt('VerifiedToBeInBusiness', r.VerifiedToBeInBusiness_CounselorRecord__c));
            xmlParts.add(xt('ReportableImpact', r.ReportableImpact__c));
            xmlParts.add(xt('DateOfReportableImpact', r.DateofReportableImpact__c != null ? String.valueOf(r.DateofReportableImpact__c) : ''));
            xmlParts.add(xt('CurrentlyExporting', r.CurrentlyExporting_CounselorRecord_Part3__c == true ? 'Yes' : 'No'));
            xmlParts.add(xt('BusinessStartDatePart3', r.BusinessStartDatePart3__c != null ? String.valueOf(r.BusinessStartDatePart3__c) : ''));
            xmlParts.add(xt('TotalNumberOfEmployees', r.TotalNumberOfEmployees_CounselorRecord__c != null ? String.valueOf(r.TotalNumberOfEmployees_CounselorRecord__c) : ''));
            xmlParts.add(xt('NumberOfEmployeesInExportingBusiness', r.NumberOfEmployeesExportingBusiness_Part3__c != null ? String.valueOf(r.NumberOfEmployeesExportingBusiness_Part3__c) : ''));

            xmlParts.add('<ClientAnnualIncomePart3>'
                + xt('GrossRevenues', r.GrossRevenues_ClientAnnualIncomePart3__c != null ? String.valueOf(r.GrossRevenues_ClientAnnualIncomePart3__c) : '')
                + xt('ProfitLoss', r.ProfitLoss_ClientAnnualIncomePart3__c != null ? String.valueOf(r.ProfitLoss_ClientAnnualIncomePart3__c) : '')
                + xt('ExportGrossRevenuesOrSales', r.ExportGrossRevenuesOrSales_Part3__c != null ? String.valueOf(r.ExportGrossRevenuesOrSales_Part3__c) : '')
                + xt('GrowthIndicator', r.GrowthIndicator_ClientAnnualIncomePart3__c)
                + '</ClientAnnualIncomePart3>\n';

            xmlParts.add('<ResourcePartnerServiceContributed>'
                + xt('SBALoanAmount', r.SBALoanAmount_CounselorRecord__c != null ? String.valueOf(r.SBALoanAmount_CounselorRecord__c) : '')
                + xt('NonSBALoanAmount', r.NonSBALoanAmount_CounselorRecord__c != null ? String.valueOf(r.NonSBALoanAmount_CounselorRecord__c) : '')
                + xt('EquityCapitalReceived', r.EquityCapitalReceived_CounselorRecord__c != null ? String.valueOf(r.EquityCapitalReceived_CounselorRecord__c) : '')
                + xt('SBALoanAmountTxnNmb', r.SBALoanAmountTxnNmbCounselorRecord__c != null ? String.valueOf(r.SBALoanAmountTxnNmbCounselorRecord__c) : '')
                + xt('NonSBALoanAmountTxnNmb', r.NonSBALoanAmountTxnNmbCounselorRecord__c != null ? String.valueOf(r.NonSBALoanAmountTxnNmbCounselorRecord__c) : '')
                + xt('EquityCapitalReceivedTxnNmb', r.EquityCapitalReceivedTxnNmbCounselorRec__c != null ? String.valueOf(r.EquityCapitalReceivedTxnNmbCounselorRec__c) : '')
                + '<NumberOfContractsReceived></NumberOfContractsReceived>'
                + '</ResourcePartnerServiceContributed>\n';

            if (String.isBlank(r.Certifications_CounselorRecord__c)) {
                xmlParts.add('<Certifications />\n');
            } else {
                xmlParts.add('<Certifications>\n');
                for (String cert : r.Certifications_CounselorRecord__c.split(','))
                    xmlParts.add(xt('Code', cert.trim()));
                xmlParts.add('<Other></Other></Certifications>\n');
            }

            xmlParts.add('<SBAFinancialAssistance />\n');
            xmlParts.add('<CounselingProvided>'
                + xt('Code', r.CounselingProvided_CounselorRecord__c)
                + xt('Other', r.CounselingProvidedOtherCounselorRecord__c)
                + '</CounselingProvided>\n';

            if (String.isBlank(r.ReferredClient_CounselorRecord__c)) {
                xmlParts.add('<ReferredClient />\n');
            } else {
                xmlParts.add('<ReferredClient>'
                    + xt('Code', r.ReferredClient_CounselorRecord__c)
                    + xt('Other', r.ReferredClientOther_CounselorRecord__c)
                    + '</ReferredClient>\n';
            }

            xmlParts.add(xt('SessionType', r.SessionType_CounselorRecord__c));
            xmlParts.add('<Language>' + xt('Code', r.Language_CounselorRecord__c) + xt('Other', r.LanguageOther_CounselorRecord__c) + '</Language>\n');
            xmlParts.add(xt('DateCounseled', r.DateCounseled_CounselorRecord__c != null ? String.valueOf(r.DateCounseled_CounselorRecord__c) : ''));
            xmlParts.add(xt('CounselorName', r.CounselorName_CounselorRecord__c));

            Decimal chrs = (r.CounselingHours_Contact__c != null && r.CounselingHours_Contact__c > 0)
                ? r.CounselingHours_Contact__c : 0.5;
            xmlParts.add('<CounselingHours>'
                + xt('Contact', String.valueOf(chrs))
                + xt('Prepare', r.CounselingHours_Prepare__c != null ? String.valueOf(r.CounselingHours_Prepare__c) : '')
                + xt('Travel',  r.CounselingHours_Travel__c  != null ? String.valueOf(r.CounselingHours_Travel__c)  : '')
                + '</CounselingHours>\n';

            xmlParts.add(xt('CounselorNotes', r.CounselorNotes_CounselorRecord__c));
            xmlParts.add(exportCountries(r.ExportCountries_CounselorRecord__c));

            xmlParts.add('<TrainingSession>'
                + xt('DateTrainingStarted', r.DateTrainingStarted_CounselorRecord__c != null ? String.valueOf(r.DateTrainingStarted_CounselorRecord__c) : '')
                + xt('PartnerTrainingNumber', r.PartnerTrainingNumber_CounselorRecord__c)
                + xt('EmployeesTrained', r.EmployeesTrained_CounselorRecord__c != null ? String.valueOf(r.EmployeesTrained_CounselorRecord__c) : '')
                + xt('HoursTrained', r.HoursTrained_CounselorRecord__c != null ? String.valueOf(r.HoursTrained_CounselorRecord__c) : '')
                + '</TrainingSession>\n';

            xmlParts.add('</CounselorRecord>\n</CounselingRecord>\n');
        }
    }

    // ── FIXED: close root here only ───────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        xmlParts.add('</CounselingInformation>\n');

        SBA641_XML_Upload__c rec = new SBA641_XML_Upload__c();
        rec.QuarterYear__c = varQuarterYear;
        insert rec;

        Blob xmlBlob = Blob.valueOf(String.join(xmlParts, ''));
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = 'SBA641_XML_Report_' + varQuarterYear;
            cv.PathOnClient = 'SBA641_Report_' + varQuarterYear + '.xml';
            cv.VersionData = xmlBlob;
            cv.IsMajorVersion = true;
            insert cv;
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
            cdl.LinkedEntityId = rec.Id;
            cdl.ShareType = 'V';
            insert cdl;
        } catch (Exception e) {
            System.debug('SBA641_XMLBatch_REFACTORED finish error: ' + e.getMessage());
        }

        if (String.isNotBlank(ownerEmail)) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject('SBA641 XML Report — ' + varQuarterYear);
            m.setPlainTextBody('641 XML for ' + varQuarterYear + ' is ready. See attachment.');
            Messaging.EmailFileAttachment a = new Messaging.EmailFileAttachment();
            a.setFileName('SBA641_Report_' + varQuarterYear + '.xml');
            a.setBody(xmlBlob);
            a.setContentType('text/xml');
            m.setFileAttachments(new Messaging.EmailFileAttachment[]{ a });
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m });
        }
    }

    private String xt(String name, String val) {
        return '<' + name + '>' + SBA641NormalizationHelper.esc(val) + '</' + name + '>\n';
    }
    private String exportCountries(String raw) {
        if (String.isBlank(raw)) return '<ExportCountries />\n';
        String x = '<ExportCountries>\n';
        for (String c : raw.split(';')) x += xt('Code', c.trim());
        return x + '</ExportCountries>\n';
    }
}
