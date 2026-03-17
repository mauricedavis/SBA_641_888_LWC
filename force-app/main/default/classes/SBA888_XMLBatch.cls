/**
 * SBA888_XMLBatch — ORIGINAL (source-tracked from sandbox)
 *
 * CRITICAL BUGS (see SBA888_XMLBatch_REFACTORED for fixes):
 *
 * BUG-1 [P0 — CRITICAL] XML root tag emitted in execute()
 *   Every batch chunk emits <?xml ...?> and <ManagementTrainingReport>.
 *   Any quarter with >200 events produces multiple root tags → XML is unparseable.
 *   Fix: emit root in start() only; close in finish() only.
 *
 * BUG-2 [P0 — CRITICAL] No Quarter_Year__c filter
 *   start() query has NO WHERE clause → every run includes ALL SBA_888_Output__c
 *   records from every quarter ever loaded.
 *   Fix: WHERE Quarter_Year__c = :varQuarterYear
 *
 * BUG-3 [P2] <ProgramFormat> missing
 *   Sample XML requires both <ProgramFormat> (raw) and <ProgramFormatType> (normalized).
 *   Batch only emits <ProgramFormatType>.
 *
 * BUG-4 [P2] <CosponsorsName> tag name mismatch
 *   Batch emits <CoSponsors> but XSD element is <CosponsorsName>.
 *   Similarly emits <Sponsor> instead of <SponsorName>.
 */
public with sharing class SBA888_XMLBatch implements Database.Batchable<SObject>, Database.Stateful {

    private String varQuarterYear;
    private String varReportType;
    private String xmlOutput = '';
    private String jobOwnerEmail = '';

    public SBA888_XMLBatch(String varQuarterYear, String varReportType) {
        this.varQuarterYear = varQuarterYear;
        this.varReportType  = varReportType;
    }

    public static String escapeXml(String input) {
        if (input == null) return '';
        input = input.replaceAll('&', '&amp;');
        input = input.replaceAll('<', '&lt;');
        input = input.replaceAll('>', '&gt;');
        input = input.replaceAll('"', '&quot;');
        input = input.replaceAll('\'', '&apos;');
        return input;
    }

    public static String getStateFullName(String stateAbbreviation) {
        Map<String, String> stateMap = new Map<String, String>{
            'AL' => 'Alabama', 'AK' => 'Alaska', 'AZ' => 'Arizona', 'AR' => 'Arkansas', 'CA' => 'California',
            'CO' => 'Colorado', 'CT' => 'Connecticut', 'DE' => 'Delaware', 'FL' => 'Florida', 'GA' => 'Georgia',
            'HI' => 'Hawaii', 'ID' => 'Idaho', 'IL' => 'Illinois', 'IN' => 'Indiana', 'IA' => 'Iowa', 'KS' => 'Kansas',
            'KY' => 'Kentucky', 'LA' => 'Louisiana', 'ME' => 'Maine', 'MD' => 'Maryland', 'MA' => 'Massachusetts',
            'MI' => 'Michigan', 'MN' => 'Minnesota', 'MS' => 'Mississippi', 'MO' => 'Missouri', 'MT' => 'Montana',
            'NE' => 'Nebraska', 'NV' => 'Nevada', 'NH' => 'New Hampshire', 'NJ' => 'New Jersey', 'NM' => 'New Mexico',
            'NY' => 'New York', 'NC' => 'North Carolina', 'ND' => 'North Dakota', 'OH' => 'Ohio', 'OK' => 'Oklahoma',
            'OR' => 'Oregon', 'PA' => 'Pennsylvania', 'RI' => 'Rhode Island', 'SC' => 'South Carolina',
            'SD' => 'South Dakota', 'TN' => 'Tennessee', 'TX' => 'Texas', 'UT' => 'Utah', 'VT' => 'Vermont',
            'VA' => 'Virginia', 'WA' => 'Washington', 'WV' => 'West Virginia', 'WI' => 'Wisconsin', 'WY' => 'Wyoming'
        };
        return stateMap.containsKey(stateAbbreviation) ? stateMap.get(stateAbbreviation) : stateAbbreviation;
    }

    // BUG-2: NO WHERE CLAUSE — returns ALL SBA_888_Output__c records from all quarters
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT PartnerTrainingNumber__c, LocationCode__c, DateTrainingStarted__c, ' +
                       'TotalTrainingHours__c, TrainingTitle__c, City_TrainingLocation__c, State_TrainingLocation__c, ' +
                       'ZipCode_TrainingLocation__c, Country_TrainingLocation__c, Total_NumberTrained__c, ' +
                       'CurrentlyInBusiness_NumberTrained__c, NotYetInBusiness_NumberTrained__c, ' +
                       'PersonWithDisabilities_NumberTrained__c, Female_NumberTrained__c, ' +
                       'Veterans_NumberTrained__c, TrainingTopic__c, ' +
                       'LGBTQ_NumberTrained__c, ActiveDuty_NumberTrained__c, Asian_NumberTrained__c, ' +
                       'BlackOrAfricanAmerican_NumberTrained__c, DollarAmountOfFees__c, ' +
                       'FundingSource__c, HispanicOrLatinoOrigin_NumberTrained__c, Language_Code__c, ' +
                       'MemberOfReserveOrNationalGuard_NumberTra__c, MiddleEastern_NumberTrained__c, ' +
                       'NativeAmericanOrAlaskaNative_NumberTrain__c, NativeHawaiinOrPacificIslander_NumberTra__c, ' +
                       'NonHispanicOrLatinoOrigin_NumberTrained__c, NorthAfrican_NumberTrained__c, NumberOfSessions__c, ' +
                       'PostalCode_TrainingLocation__c, ProgramFormatType__c, ServiceDisabledVeterans_NumberTrained__c, ' +
                       'SpouseOfMilitaryMember_NumberTrained__c, Total_NumberMinoritiesTrained__c, SponsorName__c, ' +
                       'CoSponsorsName__c, TrainingPartners_Code_SBA__c, TrainingPartners_OtherAgency_OtherGovtAg__c, ' +
                       'TrainingPartners_Code_ChamberOfCommerce__c, TrainingPartners_Code_Educational_Inst__c, ' +
                       'TrainingPartners_Code_For_Profit_Org__c, TrainingPartners_Code_Native_American_Ct__c, ' +
                       'TrainingPartners_Code_Online_Training__c, TrainingPartners_Code_SBDC__c, ' +
                       'TrainingPartners_Code_SCORE__c, TrainingPartners_Code_TradeOrProfessiona__c, ' +
                       'TrainingPartners_Code_VBOC__c, TrainingPartners_Code_Women_sBusinessCtr__c, ' +
                       'TrainingPartners_Other_OtherResources__c, TrainingPartners_OtherSBA_District_Offic__c, ' +
                       'White_NumberTrained__c, StateOrProvince_TrainingLocation__c ' +
                       'FROM SBA_888_Output__c '; // BUG-2: no WHERE clause

        return Database.getQueryLocator(query);
    }

    // BUG-1: XML root tag emitted on every execute() call
    public void execute(Database.BatchableContext bc, List<SBA_888_Output__c> scope) {
        xmlOutput += '<?xml version="1.0" encoding="UTF-8"?>\n';        // BUG-1
        xmlOutput += '<ManagementTrainingReport xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'; // BUG-1

        for (SBA_888_Output__c record : scope) {
            xmlOutput += '<ManagementTrainingRecord>\n';
            if (record.PartnerTrainingNumber__c != null) xmlOutput += '<PartnerTrainingNumber>' + escapeXml(record.PartnerTrainingNumber__c) + '</PartnerTrainingNumber>\n';
            if (record.LocationCode__c != null) xmlOutput += '<Location><LocationCode>' + escapeXml(record.LocationCode__c) + '</LocationCode></Location>\n';
            if (record.FundingSource__c != null) xmlOutput += '<FundingSource>' + escapeXml(record.FundingSource__c) + '</FundingSource>\n';
            if (record.DateTrainingStarted__c != null) xmlOutput += '<DateTrainingStarted>' + String.valueOf(record.DateTrainingStarted__c) + '</DateTrainingStarted>\n';
            if (record.NumberOfSessions__c != null) xmlOutput += '<NumberOfSessions>' + String.valueOf(record.NumberOfSessions__c) + '</NumberOfSessions>\n';
            if (record.TotalTrainingHours__c != null) xmlOutput += '<TotalTrainingHours>' + String.valueOf(record.TotalTrainingHours__c) + '</TotalTrainingHours>\n';
            if (record.TrainingTitle__c != null) xmlOutput += '<TrainingTitle>' + escapeXml(record.TrainingTitle__c) + '</TrainingTitle>\n';

            xmlOutput += '<TrainingLocation>\n';
            if (record.City_TrainingLocation__c != null) xmlOutput += '<City>' + escapeXml(record.City_TrainingLocation__c) + '</City>\n';
            if (record.State_TrainingLocation__c != null) xmlOutput += '<State>' + escapeXml(record.State_TrainingLocation__c) + '</State>\n';
            if (record.ZipCode_TrainingLocation__c != null) xmlOutput += '<ZipCode>' + escapeXml(record.ZipCode_TrainingLocation__c) + '</ZipCode>\n';
            if (record.Country_TrainingLocation__c != null) xmlOutput += '<Country><Code>' + escapeXml(record.Country_TrainingLocation__c) + '</Code></Country>\n';
            xmlOutput += '</TrainingLocation>\n';

            xmlOutput += '<NumberTrained>\n';
            if (record.Total_NumberTrained__c != null) xmlOutput += '<Total>' + String.valueOf(record.Total_NumberTrained__c) + '</Total>\n';
            if (record.CurrentlyInBusiness_NumberTrained__c != null) xmlOutput += '<CurrentlyInBusiness>' + String.valueOf(record.CurrentlyInBusiness_NumberTrained__c) + '</CurrentlyInBusiness>\n';
            if (record.NotYetInBusiness_NumberTrained__c != null) xmlOutput += '<NotYetInBusiness>' + String.valueOf(record.NotYetInBusiness_NumberTrained__c) + '</NotYetInBusiness>\n';
            if (record.PersonWithDisabilities_NumberTrained__c != null) xmlOutput += '<PersonWithDisabilities>' + String.valueOf(record.PersonWithDisabilities_NumberTrained__c) + '</PersonWithDisabilities>\n';
            if (record.Female_NumberTrained__c != null) xmlOutput += '<Female>' + String.valueOf(record.Female_NumberTrained__c) + '</Female>\n';
            if (record.ActiveDuty_NumberTrained__c != null) xmlOutput += '<ActiveDuty>' + String.valueOf(record.ActiveDuty_NumberTrained__c) + '</ActiveDuty>\n';
            if (record.Veterans_NumberTrained__c != null) xmlOutput += '<Veterans>' + String.valueOf(record.Veterans_NumberTrained__c) + '</Veterans>\n';
            if (record.ServiceDisabledVeterans_NumberTrained__c != null) xmlOutput += '<ServiceDisabledVeterans>' + String.valueOf(record.ServiceDisabledVeterans_NumberTrained__c) + '</ServiceDisabledVeterans>\n';
            if (record.MemberOfReserveOrNationalGuard_NumberTra__c != null) xmlOutput += '<MemberOfReserveOrNationalGuard>' + String.valueOf(record.MemberOfReserveOrNationalGuard_NumberTra__c) + '</MemberOfReserveOrNationalGuard>\n';
            if (record.SpouseOfMilitaryMember_NumberTrained__c != null) xmlOutput += '<SpouseOfMilitaryMember>' + String.valueOf(record.SpouseOfMilitaryMember_NumberTrained__c) + '</SpouseOfMilitaryMember>\n';
            xmlOutput += '<Race>\n';
            if (record.Asian_NumberTrained__c != null) xmlOutput += '<Asian>' + String.valueOf(record.Asian_NumberTrained__c) + '</Asian>\n';
            if (record.BlackOrAfricanAmerican_NumberTrained__c != null) xmlOutput += '<BlackOrAfricanAmerican>' + String.valueOf(record.BlackOrAfricanAmerican_NumberTrained__c) + '</BlackOrAfricanAmerican>\n';
            if (record.NativeAmericanOrAlaskaNative_NumberTrain__c != null) xmlOutput += '<NativeAmericanOrAlaskaNative>' + String.valueOf(record.NativeAmericanOrAlaskaNative_NumberTrain__c) + '</NativeAmericanOrAlaskaNative>\n';
            if (record.NativeHawaiinOrPacificIslander_NumberTra__c != null) xmlOutput += '<NativeHawaiianOrPacificIslander>' + String.valueOf(record.NativeHawaiinOrPacificIslander_NumberTra__c) + '</NativeHawaiianOrPacificIslander>\n';
            if (record.White_NumberTrained__c != null) xmlOutput += '<White>' + String.valueOf(record.White_NumberTrained__c) + '</White>\n';
            if (record.MiddleEastern_NumberTrained__c != null) xmlOutput += '<MiddleEastern>' + String.valueOf(record.MiddleEastern_NumberTrained__c) + '</MiddleEastern>\n';
            if (record.NorthAfrican_NumberTrained__c != null) xmlOutput += '<NorthAfrican>' + String.valueOf(record.NorthAfrican_NumberTrained__c) + '</NorthAfrican>\n';
            xmlOutput += '</Race>\n';
            xmlOutput += '<Ethnicity>\n';
            if (record.HispanicOrLatinoOrigin_NumberTrained__c != null) xmlOutput += '<HispanicOrLatinoOrigin>' + String.valueOf(record.HispanicOrLatinoOrigin_NumberTrained__c) + '</HispanicOrLatinoOrigin>\n';
            if (record.NonHispanicOrLatinoOrigin_NumberTrained__c != null) xmlOutput += '<NonHispanicOrLatinoOrigin>' + String.valueOf(record.NonHispanicOrLatinoOrigin_NumberTrained__c) + '</NonHispanicOrLatinoOrigin>\n';
            xmlOutput += '</Ethnicity>\n';
            if (record.LGBTQ_NumberTrained__c != null) xmlOutput += '<LGBTQ>' + String.valueOf(record.LGBTQ_NumberTrained__c) + '</LGBTQ>\n';
            xmlOutput += '</NumberTrained>\n';

            if (record.Total_NumberMinoritiesTrained__c != null) {
                xmlOutput += '<NumberMinoritiesTrained>\n';
                xmlOutput += '<Total>' + String.valueOf(record.Total_NumberMinoritiesTrained__c) + '</Total>\n';
                xmlOutput += '</NumberMinoritiesTrained>\n';
            }
            if (record.TrainingTopic__c != null) {
                xmlOutput += '<TrainingTopic>\n';
                xmlOutput += '<Code>' + escapeXml(record.TrainingTopic__c) + '</Code>\n';
                xmlOutput += '</TrainingTopic>\n';
            }

            xmlOutput += '<TrainingPartners>\n';
            if (!String.isBlank(record.TrainingPartners_Code_SBA__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_SBA__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_ChamberOfCommerce__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_ChamberOfCommerce__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_Educational_Inst__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_Educational_Inst__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_For_Profit_Org__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_For_Profit_Org__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_Native_American_Ct__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_Native_American_Ct__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_Online_Training__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_Online_Training__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_SBDC__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_SBDC__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_SCORE__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_SCORE__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_TradeOrProfessiona__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_TradeOrProfessiona__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_VBOC__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_VBOC__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_Code_Women_sBusinessCtr__c)) xmlOutput += '<Code>' + escapeXml(record.TrainingPartners_Code_Women_sBusinessCtr__c) + '</Code>\n';
            if (!String.isBlank(record.TrainingPartners_OtherAgency_OtherGovtAg__c)) xmlOutput += '<Other>' + escapeXml(record.TrainingPartners_OtherAgency_OtherGovtAg__c) + '</Other>\n';
            if (!String.isBlank(record.TrainingPartners_Other_OtherResources__c)) xmlOutput += '<Other>' + escapeXml(record.TrainingPartners_Other_OtherResources__c) + '</Other>\n';
            if (!String.isBlank(record.TrainingPartners_OtherSBA_District_Offic__c)) xmlOutput += '<Other>' + escapeXml(record.TrainingPartners_OtherSBA_District_Offic__c) + '</Other>\n';
            xmlOutput += '</TrainingPartners>\n';

            // BUG-3: only <ProgramFormatType>, missing <ProgramFormat>
            if (record.ProgramFormatType__c != null) xmlOutput += '<ProgramFormatType>' + escapeXml(record.ProgramFormatType__c) + '</ProgramFormatType>\n';
            if (record.DollarAmountOfFees__c != null) xmlOutput += '<DollarAmountOfFees>' + String.valueOf(record.DollarAmountOfFees__c) + '</DollarAmountOfFees>\n';
            if (record.Language_Code__c != null) xmlOutput += '<Language><Code>' + escapeXml(record.Language_Code__c) + '</Code></Language>\n';
            // BUG-4: wrong element names (<CoSponsors> vs <CosponsorsName>, <Sponsor> vs <SponsorName>)
            if (record.CoSponsorsName__c != null) xmlOutput += '<CoSponsors>' + escapeXml(record.CoSponsorsName__c) + '</CoSponsors>\n';
            if (record.SponsorName__c != null) xmlOutput += '<Sponsor>' + escapeXml(record.SponsorName__c) + '</Sponsor>\n';

            xmlOutput += '</ManagementTrainingRecord>\n';
        }

        // BUG-1: closing root tag also in execute()
        xmlOutput += '</ManagementTrainingReport>\n';

        if (jobOwnerEmail == '') {
            jobOwnerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
        }
    }

    public void finish(Database.BatchableContext bc) {
        SBA888_XML_Upload__c xmlRecord = new SBA888_XML_Upload__c();
        xmlRecord.QuarterYear__c = varQuarterYear;
        insert xmlRecord;

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'SBA888_XML_Report_' + varQuarterYear;
        contentVersion.PathOnClient = 'SBA888_Report_' + varQuarterYear + '.xml';
        contentVersion.VersionData = Blob.valueOf(xmlOutput);
        contentVersion.IsMajorVersion = true;
        insert contentVersion;

        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId;
        contentDocumentLink.LinkedEntityId = xmlRecord.Id;
        contentDocumentLink.ShareType = 'V';
        insert contentDocumentLink;

        if (!String.isBlank(jobOwnerEmail)) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { jobOwnerEmail });
            email.setSubject('SBA888 XML Report for ' + varQuarterYear);
            email.setPlainTextBody('Please find the attached SBA888 XML report.');
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('SBA888_Report.xml');
            attachment.setBody(Blob.valueOf(xmlOutput));
            attachment.setContentType('text/xml');
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}
