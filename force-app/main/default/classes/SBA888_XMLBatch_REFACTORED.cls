/**
 * SBA888_XMLBatch_REFACTORED
 *
 * Critical bugs from SBA888_XMLBatch fixed:
 *   FIXED BUG-1 [P0]: XML root emitted in start() + closed in finish() — NEVER in execute()
 *   FIXED BUG-2 [P0]: WHERE Quarter_Year__c = :varQuarterYear added
 *   FIXED BUG-3 [P2]: Both <ProgramFormat> (raw) AND <ProgramFormatType> (normalized) emitted
 *   FIXED BUG-4 [P2]: Correct element names: <SponsorName>, <CosponsorsName>
 *   ADDED: <Operation> element (XSD change #105)
 *   FIXED: <OtherAgency> and <OtherSBA> use correct distinct tags (not all mapped to <Other>)
 *   Normalization delegated to SBA888NormalizationHelper (removes duplicate state map)
 */
public with sharing class SBA888_XMLBatch_REFACTORED
        implements Database.Batchable<SObject>, Database.Stateful {

    private String varQuarterYear;
    private String varReportType;
    private String xmlOutput  = '';
    private String ownerEmail = '';

    public SBA888_XMLBatch_REFACTORED(String varQuarterYear, String varReportType) {
        this.varQuarterYear = varQuarterYear;
        this.varReportType  = varReportType;
    }

    @TestVisible public String getXmlOutput() { return xmlOutput; }

    // ── FIXED: root emitted exactly once here ─────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        xmlOutput  = '<?xml version="1.0" encoding="UTF-8"?>\n';
        xmlOutput += '<ManagementTrainingReport xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n';
        ownerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;

        // FIXED BUG-2: WHERE clause added
        return Database.getQueryLocator(
            'SELECT PartnerTrainingNumber__c, LocationCode__c, DateTrainingStarted__c,' +
            ' TotalTrainingHours__c, TrainingTitle__c,' +
            ' City_TrainingLocation__c, State_TrainingLocation__c,' +
            ' ZipCode_TrainingLocation__c, Country_TrainingLocation__c,' +
            ' Total_NumberTrained__c, CurrentlyInBusiness_NumberTrained__c,' +
            ' NotYetInBusiness_NumberTrained__c, PersonWithDisabilities_NumberTrained__c,' +
            ' Female_NumberTrained__c, ActiveDuty_NumberTrained__c, Veterans_NumberTrained__c,' +
            ' ServiceDisabledVeterans_NumberTrained__c, MemberOfReserveOrNationalGuard_NumberTra__c,' +
            ' SpouseOfMilitaryMember_NumberTrained__c,' +
            ' Asian_NumberTrained__c, BlackOrAfricanAmerican_NumberTrained__c,' +
            ' NativeAmericanOrAlaskaNative_NumberTrain__c, NativeHawaiinOrPacificIslander_NumberTra__c,' +
            ' White_NumberTrained__c, MiddleEastern_NumberTrained__c, NorthAfrican_NumberTrained__c,' +
            ' HispanicOrLatinoOrigin_NumberTrained__c, NonHispanicOrLatinoOrigin_NumberTrained__c,' +
            ' LGBTQ_NumberTrained__c, Total_NumberMinoritiesTrained__c,' +
            ' TrainingTopic__c, NumberOfSessions__c,' +
            ' TrainingPartners_Code_SBA__c, TrainingPartners_Code_ChamberOfCommerce__c,' +
            ' TrainingPartners_Code_Educational_Inst__c, TrainingPartners_Code_For_Profit_Org__c,' +
            ' TrainingPartners_Code_Native_American_Ct__c, TrainingPartners_Code_Online_Training__c,' +
            ' TrainingPartners_Code_SBDC__c, TrainingPartners_Code_SCORE__c,' +
            ' TrainingPartners_Code_TradeOrProfessiona__c, TrainingPartners_Code_VBOC__c,' +
            ' TrainingPartners_Code_Women_sBusinessCtr__c,' +
            ' TrainingPartners_OtherSBA_District_Offic__c,' +
            ' TrainingPartners_OtherAgency_OtherGovtAg__c,' +
            ' TrainingPartners_Other_OtherResources__c,' +
            ' ProgramFormatType__c, FundingSource__c, Language_Code__c,' +
            ' DollarAmountOfFees__c, SponsorName__c, CoSponsorsName__c,' +
            ' PostalCode_TrainingLocation__c, StateOrProvince_TrainingLocation__c' +
            ' FROM SBA_888_Output__c' +
            ' WHERE Quarter_Year__c = :varQuarterYear'  // FIXED BUG-2
        );
    }

    // ── execute: records only — NO root tag ───────────────────────────────────
    public void execute(Database.BatchableContext bc, List<SBA_888_Output__c> scope) {
        for (SBA_888_Output__c r : scope) {
            xmlOutput += '<ManagementTrainingRecord>\n';
            xmlOutput += '<Operation></Operation>\n'; // XSD change #105
            if (r.PartnerTrainingNumber__c != null) xmlOutput += xt('PartnerTrainingNumber', r.PartnerTrainingNumber__c);
            if (r.LocationCode__c != null) xmlOutput += '<Location>' + xt('LocationCode', r.LocationCode__c) + '</Location>\n';
            if (r.FundingSource__c != null) xmlOutput += xt('FundingSource', r.FundingSource__c);
            if (r.DateTrainingStarted__c != null) xmlOutput += xt('DateTrainingStarted', String.valueOf(r.DateTrainingStarted__c));
            if (r.NumberOfSessions__c != null) xmlOutput += xt('NumberOfSessions', String.valueOf(r.NumberOfSessions__c));
            if (r.TotalTrainingHours__c != null) xmlOutput += xt('TotalTrainingHours', String.valueOf(r.TotalTrainingHours__c));
            if (r.TrainingTitle__c != null) xmlOutput += xt('TrainingTitle', r.TrainingTitle__c);

            xmlOutput += '<TrainingLocation>\n';
            if (r.City_TrainingLocation__c != null)    xmlOutput += xt('City', r.City_TrainingLocation__c);
            if (r.State_TrainingLocation__c != null)   xmlOutput += xt('State', r.State_TrainingLocation__c);
            if (r.ZipCode_TrainingLocation__c != null) xmlOutput += xt('ZipCode', r.ZipCode_TrainingLocation__c);
            if (r.Country_TrainingLocation__c != null) xmlOutput += '<Country>' + xt('Code', r.Country_TrainingLocation__c) + '</Country>\n';
            xmlOutput += xt('PostalCode', r.PostalCode_TrainingLocation__c);
            xmlOutput += xt('StateOrProvince', r.StateOrProvince_TrainingLocation__c);
            xmlOutput += '</TrainingLocation>\n';

            xmlOutput += '<NumberTrained>\n';
            xmlOutput += xt('Total', String.valueOf(r.Total_NumberTrained__c != null ? r.Total_NumberTrained__c : 0));
            if (r.CurrentlyInBusiness_NumberTrained__c != null) xmlOutput += xt('CurrentlyInBusiness', String.valueOf(r.CurrentlyInBusiness_NumberTrained__c));
            if (r.NotYetInBusiness_NumberTrained__c != null)    xmlOutput += xt('NotYetInBusiness', String.valueOf(r.NotYetInBusiness_NumberTrained__c));
            if (r.PersonWithDisabilities_NumberTrained__c != null) xmlOutput += xt('PersonWithDisabilities', String.valueOf(r.PersonWithDisabilities_NumberTrained__c));
            if (r.Female_NumberTrained__c != null)  xmlOutput += xt('Female', String.valueOf(r.Female_NumberTrained__c));
            if (r.ActiveDuty_NumberTrained__c != null) xmlOutput += xt('ActiveDuty', String.valueOf(r.ActiveDuty_NumberTrained__c));
            if (r.Veterans_NumberTrained__c != null)   xmlOutput += xt('Veterans', String.valueOf(r.Veterans_NumberTrained__c));
            if (r.ServiceDisabledVeterans_NumberTrained__c != null) xmlOutput += xt('ServiceDisabledVeterans', String.valueOf(r.ServiceDisabledVeterans_NumberTrained__c));
            if (r.MemberOfReserveOrNationalGuard_NumberTra__c != null) xmlOutput += xt('MemberOfReserveOrNationalGuard', String.valueOf(r.MemberOfReserveOrNationalGuard_NumberTra__c));
            if (r.SpouseOfMilitaryMember_NumberTrained__c != null) xmlOutput += xt('SpouseOfMilitaryMember', String.valueOf(r.SpouseOfMilitaryMember_NumberTrained__c));

            xmlOutput += '<Race>\n';
            if (r.Asian_NumberTrained__c != null)  xmlOutput += xt('Asian', String.valueOf(r.Asian_NumberTrained__c));
            if (r.BlackOrAfricanAmerican_NumberTrained__c != null) xmlOutput += xt('BlackOrAfricanAmerican', String.valueOf(r.BlackOrAfricanAmerican_NumberTrained__c));
            if (r.NativeAmericanOrAlaskaNative_NumberTrain__c != null) xmlOutput += xt('NativeAmericanOrAlaskaNative', String.valueOf(r.NativeAmericanOrAlaskaNative_NumberTrain__c));
            if (r.NativeHawaiinOrPacificIslander_NumberTra__c != null) xmlOutput += xt('NativeHawaiianOrPacificIslander', String.valueOf(r.NativeHawaiinOrPacificIslander_NumberTra__c));
            if (r.White_NumberTrained__c != null) xmlOutput += xt('White', String.valueOf(r.White_NumberTrained__c));
            if (r.MiddleEastern_NumberTrained__c != null) xmlOutput += xt('MiddleEastern', String.valueOf(r.MiddleEastern_NumberTrained__c));
            if (r.NorthAfrican_NumberTrained__c != null) xmlOutput += xt('NorthAfrican', String.valueOf(r.NorthAfrican_NumberTrained__c));
            xmlOutput += '</Race>\n';

            xmlOutput += '<Ethnicity>\n';
            if (r.HispanicOrLatinoOrigin_NumberTrained__c != null) xmlOutput += xt('HispanicOrLatinoOrigin', String.valueOf(r.HispanicOrLatinoOrigin_NumberTrained__c));
            if (r.NonHispanicOrLatinoOrigin_NumberTrained__c != null) xmlOutput += xt('NonHispanicOrLatinoOrigin', String.valueOf(r.NonHispanicOrLatinoOrigin_NumberTrained__c));
            xmlOutput += '</Ethnicity>\n';
            if (r.LGBTQ_NumberTrained__c != null) xmlOutput += xt('LGBTQ', String.valueOf(r.LGBTQ_NumberTrained__c));
            xmlOutput += '</NumberTrained>\n';

            if (r.Total_NumberMinoritiesTrained__c != null) {
                xmlOutput += '<NumberMinoritiesTrained>' + xt('Total', String.valueOf(r.Total_NumberMinoritiesTrained__c)) + '</NumberMinoritiesTrained>\n';
            }

            if (r.TrainingTopic__c != null) {
                xmlOutput += '<TrainingTopic>' + xt('Code', SBA888NormalizationHelper.normalizeTopic(r.TrainingTopic__c)) + '</TrainingTopic>\n';
            }

            // TrainingPartners with correct distinct tags
            xmlOutput += '<TrainingPartners>\n';
            if (!String.isBlank(r.TrainingPartners_Code_SBA__c)) xmlOutput += xt('Code', r.TrainingPartners_Code_SBA__c);
            for (String code : SBA888NormalizationHelper.getPartnerCodes(r)) xmlOutput += xt('Code', code);
            if (!String.isBlank(r.TrainingPartners_OtherSBA_District_Offic__c)) xmlOutput += xt('OtherSBA', r.TrainingPartners_OtherSBA_District_Offic__c);
            if (!String.isBlank(r.TrainingPartners_OtherAgency_OtherGovtAg__c)) xmlOutput += xt('OtherAgency', r.TrainingPartners_OtherAgency_OtherGovtAg__c); // FIXED distinct tag
            if (!String.isBlank(r.TrainingPartners_Other_OtherResources__c)) xmlOutput += xt('Other', r.TrainingPartners_Other_OtherResources__c);
            xmlOutput += '</TrainingPartners>\n';

            // FIXED BUG-3: emit BOTH <ProgramFormat> and <ProgramFormatType>
            if (r.ProgramFormatType__c != null) {
                xmlOutput += xt('ProgramFormat', SBA888NormalizationHelper.getProgramFormatRaw(r.ProgramFormatType__c));
                xmlOutput += xt('ProgramFormatType', SBA888NormalizationHelper.normalizeProgramFormatType(r.ProgramFormatType__c));
            }
            if (r.DollarAmountOfFees__c != null) xmlOutput += xt('DollarAmountOfFees', String.valueOf(r.DollarAmountOfFees__c));
            if (r.Language_Code__c != null) xmlOutput += '<Language>' + xt('Code', r.Language_Code__c) + '</Language>\n';
            // FIXED BUG-4: correct element names
            if (r.SponsorName__c != null) xmlOutput += xt('SponsorName', r.SponsorName__c);
            if (r.CoSponsorsName__c != null) xmlOutput += xt('CosponsorsName', r.CoSponsorsName__c);

            xmlOutput += '</ManagementTrainingRecord>\n';
        }
    }

    // ── FIXED: close root here only ───────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        xmlOutput += '</ManagementTrainingReport>\n';

        SBA888_XML_Upload__c rec = new SBA888_XML_Upload__c();
        rec.QuarterYear__c = varQuarterYear;
        insert rec;

        Blob xmlBlob = Blob.valueOf(xmlOutput);
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = 'SBA888_XML_Report_' + varQuarterYear;
            cv.PathOnClient = 'SBA888_Report_' + varQuarterYear + '.xml';
            cv.VersionData = xmlBlob;
            cv.IsMajorVersion = true;
            insert cv;
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
            cdl.LinkedEntityId = rec.Id;
            cdl.ShareType = 'V';
            insert cdl;
        } catch (Exception e) {
            System.debug('SBA888_XMLBatch_REFACTORED finish error: ' + e.getMessage());
        }

        if (String.isNotBlank(ownerEmail)) {
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[]{ ownerEmail });
            m.setSubject('SBA888 XML Report — ' + varQuarterYear);
            m.setPlainTextBody('888 XML for ' + varQuarterYear + ' is ready. See attachment.');
            Messaging.EmailFileAttachment a = new Messaging.EmailFileAttachment();
            a.setFileName('SBA888_Report_' + varQuarterYear + '.xml');
            a.setBody(xmlBlob);
            a.setContentType('text/xml');
            m.setFileAttachments(new Messaging.EmailFileAttachment[]{ a });
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ m });
        }
    }

    private String xt(String name, String val) {
        return '<' + name + '>' + SBA888NormalizationHelper.esc(val) + '</' + name + '>\n';
    }
}
