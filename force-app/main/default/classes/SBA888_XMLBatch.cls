/**
 * SBA888_XMLBatch
 * Generates SBA Form 888 (Management Training) XML from SBA_888_Output__c records.
 * Uses chunked ContentVersion approach — one ContentVersion per execute() call.
 * Enqueues SBA888_XMLAssembler on finish() to assemble parts into final file.
 *
 * XSD: SBA_NEXUS_Training-2-14.xsd
 * Root: <ManagementTrainingReport>
 * Record: <ManagementTrainingRecord>
 */
public class SBA888_XMLBatch implements Database.Batchable<SObject>, Database.Stateful {

    private String varQuarterYear;
    private String ownerEmail     = '';
    private Integer chunkIndex    = 0;
    private List<Id> chunkCVIds   = new List<Id>();

    public SBA888_XMLBatch(String varQuarterYear) {
        this.varQuarterYear = varQuarterYear;
    }

    // Backward-compatible constructors for SBA888_XMLBatchFlow and test classes
    // Extra parameters (startDate, endDate, recordTypeId) are ignored — 
    // this batch derives dates from the quarterYear and queries by RecordType
    public SBA888_XMLBatch(Date startDate, Date endDate, String varRecordTypeId, String varQuarterYear) {
        this.varQuarterYear = varQuarterYear;
    }

    public SBA888_XMLBatch(String varQuarterYear, String ignored) {
        this.varQuarterYear = varQuarterYear;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        ownerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;

        // Write XML header as chunk 0
        ContentVersion cv0 = new ContentVersion();
        cv0.Title          = 'SBA888_XML_Chunk_' + varQuarterYear + '_000';
        cv0.PathOnClient   = cv0.Title + '.txt';
        cv0.VersionData    = Blob.valueOf('<?xml version="1.0" encoding="UTF-8"?>\n<ManagementTrainingReport>\n');
        cv0.IsMajorVersion = false;
        insert cv0;
        chunkCVIds.add(cv0.Id);
        chunkIndex = 1;

        return Database.getQueryLocator(
            'SELECT Id, PartnerTrainingNumber__c, FundingSource__c, LocationCode__c,' +
            ' DateTrainingStarted__c, NumberOfSessions__c, TotalTrainingHours__c,' +
            ' TrainingTitle__c,' +
            ' City_TrainingLocation__c, State_TrainingLocation__c,' +
            ' ZipCode_TrainingLocation__c, PostalCode_TrainingLocation__c,' +
            ' StateOrProvince_TrainingLocation__c, Country_TrainingLocation__c,' +
            ' Total_NumberTrained__c,' +
            ' CurrentlyInBusiness_NumberTrained__c, NotYetInBusiness_NumberTrained__c,' +
            ' PersonWithDisabilities_NumberTrained__c, Female_NumberTrained__c,' +
            ' ActiveDuty_NumberTrained__c, Veterans_NumberTrained__c,' +
            ' ServiceDisabledVeterans_NumberTrained__c,' +
            ' MemberOfReserveOrNationalGuard_NumberTra__c,' +
            ' SpouseOfMilitaryMember_NumberTrained__c,' +
            ' Asian_NumberTrained__c, BlackOrAfricanAmerican_NumberTrained__c,' +
            ' NativeAmericanOrAlaskaNative_NumberTrain__c,' +
            ' NativeHawaiinOrPacificIslander_NumberTra__c,' +
            ' White_NumberTrained__c, MiddleEastern_NumberTrained__c,' +
            ' NorthAfrican_NumberTrained__c,' +
            ' HispanicOrLatinoOrigin_NumberTrained__c,' +
            ' NonHispanicOrLatinoOrigin_NumberTrained__c,' +
            ' Total_NumberMinoritiesTrained__c,' +
            ' TrainingTopic__c, Language_Code__c, ProgramFormatType__c,' +
            ' DollarAmountOfFees__c,' +
            ' TrainingPartners_Code_ChamberOfCommerce__c,' +
            ' TrainingPartners_Code_Educational_Inst__c,' +
            ' TrainingPartners_Code_For_Profit_Org__c,' +
            ' TrainingPartners_Code_Native_American_Ct__c,' +
            ' TrainingPartners_Code_Online_Training__c,' +
            ' TrainingPartners_Code_SBA__c,' +
            ' TrainingPartners_Code_SBDC__c,' +
            ' TrainingPartners_Code_SCORE__c,' +
            ' TrainingPartners_Code_TradeOrProfessiona__c,' +
            ' TrainingPartners_Code_VBOC__c,' +
            ' TrainingPartners_Code_Women_sBusinessCtr__c,' +
            ' TrainingPartners_OtherSBA_District_Offic__c,' +
            ' TrainingPartners_OtherAgency_OtherGovtAg__c,' +
            ' TrainingPartners_Other_OtherResources__c,' +
            ' SponsorName__c, CoSponsorsName__c' +
            ' FROM SBA_888_Output__c' +
            ' WHERE RecordType.DeveloperName = \'' + varQuarterYear + '\'' +
            ' ORDER BY PartnerTrainingNumber__c ASC'
        );
    }

    public void execute(Database.BatchableContext bc, List<SBA_888_Output__c> scope) {
        List<String> chunk = new List<String>();

        for (SBA_888_Output__c r : scope) {
            chunk.add('<ManagementTrainingRecord>\n');
            chunk.add('<Operation></Operation>\n');
            chunk.add(xt('PartnerTrainingNumber', r.PartnerTrainingNumber__c));

            if (String.isNotBlank(r.FundingSource__c)) {
                chunk.add(xt('FundingSource', r.FundingSource__c));
            }

            chunk.add('<Location>' + xt('LocationCode', r.LocationCode__c) + '</Location>\n');

            if (r.DateTrainingStarted__c != null) {
                chunk.add(xt('DateTrainingStarted', String.valueOf(r.DateTrainingStarted__c)));
            }
            if (r.NumberOfSessions__c != null) {
                chunk.add(xt('NumberOfSessions', String.valueOf(r.NumberOfSessions__c.intValue())));
            }
            if (r.TotalTrainingHours__c != null) {
                chunk.add(xt('TotalTrainingHours', String.valueOf(r.TotalTrainingHours__c)));
            }
            if (String.isNotBlank(r.TrainingTitle__c)) {
                chunk.add(xt('TrainingTitle', r.TrainingTitle__c));
            }

            // TrainingLocation
            Boolean hasLocation = String.isNotBlank(r.City_TrainingLocation__c)
                || String.isNotBlank(r.State_TrainingLocation__c)
                || String.isNotBlank(r.ZipCode_TrainingLocation__c)
                || String.isNotBlank(r.Country_TrainingLocation__c);
            if (hasLocation) {
                chunk.add('<TrainingLocation>\n');
                if (String.isNotBlank(r.City_TrainingLocation__c)) chunk.add(xt('City', r.City_TrainingLocation__c));
                if (String.isNotBlank(r.State_TrainingLocation__c)) chunk.add(xt('State', r.State_TrainingLocation__c));
                if (String.isNotBlank(r.ZipCode_TrainingLocation__c)) chunk.add(xt('ZipCode', r.ZipCode_TrainingLocation__c));
                if (String.isNotBlank(r.PostalCode_TrainingLocation__c)) chunk.add(xt('PostalCode', r.PostalCode_TrainingLocation__c));
                if (String.isNotBlank(r.StateOrProvince_TrainingLocation__c)) chunk.add(xt('StateOrProvince', r.StateOrProvince_TrainingLocation__c));
                if (String.isNotBlank(r.Country_TrainingLocation__c)) {
                    chunk.add('<Country>' + xt('Code', r.Country_TrainingLocation__c) + '</Country>\n');
                }
                chunk.add('</TrainingLocation>\n');
            }

            // NumberTrained
            if (r.Total_NumberTrained__c != null) {
                chunk.add('<NumberTrained>\n');
                chunk.add(xt('Total', String.valueOf(r.Total_NumberTrained__c.intValue())));
                if (r.CurrentlyInBusiness_NumberTrained__c != null) chunk.add(xt('CurrentlyInBusiness', String.valueOf(r.CurrentlyInBusiness_NumberTrained__c.intValue())));
                if (r.NotYetInBusiness_NumberTrained__c != null) chunk.add(xt('NotYetInBusiness', String.valueOf(r.NotYetInBusiness_NumberTrained__c.intValue())));
                if (r.PersonWithDisabilities_NumberTrained__c != null) chunk.add(xt('PersonWithDisabilities', String.valueOf(r.PersonWithDisabilities_NumberTrained__c.intValue())));
                if (r.Female_NumberTrained__c != null) chunk.add(xt('Female', String.valueOf(r.Female_NumberTrained__c.intValue())));
                if (r.ActiveDuty_NumberTrained__c != null) chunk.add(xt('ActiveDuty', String.valueOf(r.ActiveDuty_NumberTrained__c.intValue())));
                if (r.Veterans_NumberTrained__c != null) chunk.add(xt('Veterans', String.valueOf(r.Veterans_NumberTrained__c.intValue())));
                if (r.ServiceDisabledVeterans_NumberTrained__c != null) chunk.add(xt('ServiceDisabledVeterans', String.valueOf(r.ServiceDisabledVeterans_NumberTrained__c.intValue())));
                if (r.MemberOfReserveOrNationalGuard_NumberTra__c != null) chunk.add(xt('MemberOfReserveOrNationalGuard', String.valueOf(r.MemberOfReserveOrNationalGuard_NumberTra__c.intValue())));
                if (r.SpouseOfMilitaryMember_NumberTrained__c != null) chunk.add(xt('SpouseOfMilitaryMember', String.valueOf(r.SpouseOfMilitaryMember_NumberTrained__c.intValue())));

                // Race
                Boolean hasRace = r.Asian_NumberTrained__c != null || r.BlackOrAfricanAmerican_NumberTrained__c != null
                    || r.NativeAmericanOrAlaskaNative_NumberTrain__c != null || r.NativeHawaiinOrPacificIslander_NumberTra__c != null
                    || r.White_NumberTrained__c != null || r.MiddleEastern_NumberTrained__c != null || r.NorthAfrican_NumberTrained__c != null;
                if (hasRace) {
                    chunk.add('<Race>\n');
                    if (r.Asian_NumberTrained__c != null) chunk.add(xt('Asian', String.valueOf(r.Asian_NumberTrained__c.intValue())));
                    if (r.BlackOrAfricanAmerican_NumberTrained__c != null) chunk.add(xt('BlackOrAfricanAmerican', String.valueOf(r.BlackOrAfricanAmerican_NumberTrained__c.intValue())));
                    if (r.NativeAmericanOrAlaskaNative_NumberTrain__c != null) chunk.add(xt('NativeAmericanOrAlaskaNative', String.valueOf(r.NativeAmericanOrAlaskaNative_NumberTrain__c.intValue())));
                    if (r.NativeHawaiinOrPacificIslander_NumberTra__c != null) chunk.add(xt('NativeHawaiianOrPacificIslander', String.valueOf(r.NativeHawaiinOrPacificIslander_NumberTra__c.intValue())));
                    if (r.White_NumberTrained__c != null) chunk.add(xt('White', String.valueOf(r.White_NumberTrained__c.intValue())));
                    if (r.MiddleEastern_NumberTrained__c != null) chunk.add(xt('MiddleEastern', String.valueOf(r.MiddleEastern_NumberTrained__c.intValue())));
                    if (r.NorthAfrican_NumberTrained__c != null) chunk.add(xt('NorthAfrican', String.valueOf(r.NorthAfrican_NumberTrained__c.intValue())));
                    chunk.add('</Race>\n');
                }

                // Ethnicity
                Boolean hasEthnicity = r.HispanicOrLatinoOrigin_NumberTrained__c != null || r.NonHispanicOrLatinoOrigin_NumberTrained__c != null;
                if (hasEthnicity) {
                    chunk.add('<Ethnicity>\n');
                    if (r.HispanicOrLatinoOrigin_NumberTrained__c != null) chunk.add(xt('HispanicOrLatinoOrigin', String.valueOf(r.HispanicOrLatinoOrigin_NumberTrained__c.intValue())));
                    if (r.NonHispanicOrLatinoOrigin_NumberTrained__c != null) chunk.add(xt('NonHispanicOrLatinoOrigin', String.valueOf(r.NonHispanicOrLatinoOrigin_NumberTrained__c.intValue())));
                    chunk.add('</Ethnicity>\n');
                }
                chunk.add('</NumberTrained>\n');
            }

            // NumberUnderservedTrained
            if (r.Total_NumberMinoritiesTrained__c != null) {
                chunk.add('<NumberUnderservedTrained>\n');
                chunk.add(xt('Total', String.valueOf(r.Total_NumberMinoritiesTrained__c.intValue())));
                chunk.add('</NumberUnderservedTrained>\n');
            }

            // TrainingTopic
            if (String.isNotBlank(r.TrainingTopic__c)) {
                chunk.add('<TrainingTopic>\n');
                String topic = r.TrainingTopic__c;
                // Map to valid XSD enum values
                String mappedTopic = mapTopic(topic);
                if (mappedTopic == 'Other') {
                    chunk.add(xt('Code', 'Other'));
                    chunk.add(xt('Other', topic));
                } else {
                    chunk.add(xt('Code', mappedTopic));
                }
                chunk.add('</TrainingTopic>\n');
            }

            // TrainingPartners — one <Code> per partner
            List<String> partnerCodes = buildPartnerCodes(r);
            if (!partnerCodes.isEmpty()) {
                chunk.add('<TrainingPartners>\n');
                for (String code : partnerCodes) {
                    chunk.add(xt('Code', code));
                }
                if (String.isNotBlank(r.TrainingPartners_OtherSBA_District_Offic__c)) {
                    chunk.add(xt('OtherSBA', r.TrainingPartners_OtherSBA_District_Offic__c));
                }
                if (String.isNotBlank(r.TrainingPartners_OtherAgency_OtherGovtAg__c)) {
                    chunk.add(xt('OtherAgency', r.TrainingPartners_OtherAgency_OtherGovtAg__c));
                }
                if (String.isNotBlank(r.TrainingPartners_Other_OtherResources__c)) {
                    chunk.add(xt('Other', r.TrainingPartners_Other_OtherResources__c));
                }
                chunk.add('</TrainingPartners>\n');
            }

            // ProgramFormatType
            if (String.isNotBlank(r.ProgramFormatType__c)) {
                chunk.add(xt('ProgramFormatType', r.ProgramFormatType__c));
            }

            // DollarAmountOfFees
            if (r.DollarAmountOfFees__c != null) {
                chunk.add(xt('DollarAmountOfFees', String.valueOf(r.DollarAmountOfFees__c.intValue())));
            }

            // Language — one <Code> per language
            if (String.isNotBlank(r.Language_Code__c)) {
                chunk.add('<Language>\n');
                for (String lang : r.Language_Code__c.split(';')) {
                    String trimmed = lang.trim();
                    if (String.isNotBlank(trimmed)) chunk.add(xt('Code', trimmed));
                }
                chunk.add('</Language>\n');
            }

            if (String.isNotBlank(r.SponsorName__c)) chunk.add(xt('SponsorName', r.SponsorName__c));
            if (String.isNotBlank(r.CoSponsorsName__c)) chunk.add(xt('CoSponsorsName', r.CoSponsorsName__c));

            chunk.add('</ManagementTrainingRecord>\n');
        }

        // Save chunk as ContentVersion
        if (!chunk.isEmpty()) {
            String padded = String.valueOf(chunkIndex).leftPad(3, '0');
            ContentVersion cv = new ContentVersion();
            cv.Title          = 'SBA888_XML_Chunk_' + varQuarterYear + '_' + padded;
            cv.PathOnClient   = cv.Title + '.txt';
            cv.VersionData    = Blob.valueOf(String.join(chunk, ''));
            cv.IsMajorVersion = false;
            insert cv;
            chunkCVIds.add(cv.Id);
            chunkIndex++;
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Add closing tag as final chunk
        ContentVersion cvClose = new ContentVersion();
        cvClose.Title          = 'SBA888_XML_Chunk_' + varQuarterYear + '_999_CLOSE';
        cvClose.PathOnClient   = cvClose.Title + '.txt';
        cvClose.VersionData    = Blob.valueOf('</ManagementTrainingReport>\n');
        cvClose.IsMajorVersion = false;
        insert cvClose;
        chunkCVIds.add(cvClose.Id);

        System.enqueueJob(new SBA888_XMLAssembler(chunkCVIds, varQuarterYear, ownerEmail));
    }

    // XML tag helper — escapes special chars
    private static String xt(String tag, String val) {
        if (String.isBlank(val)) return '';
        String escaped = val
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
        return '<' + tag + '>' + escaped + '</' + tag + '>\n';
    }

    // Public static version for use by SBA888ValidationService
    public static String mapTopicStatic(String topic) {
        return mapTopic(topic);
    }

    // Map SBA888Batch topic values to valid XSD enum values
    private static String mapTopic(String topic) {
        if (topic == null) return 'Other';
        Map<String, String> topicMap = new Map<String, String>{
            'Business Accounting/Budget'         => 'Business Accounting/Budget',
            'Business Financial/Cash Flow'       => 'Business Financial/Cash Flow',
            'Business Financing/Capital Sources' => 'Business Financing/Capital Sources',
            'Business Operations/Management'     => 'Business Operations/Management',
            'Business Plan'                      => 'Business Plan',
            'Business Start-up/Preplanning'      => 'Business Start-up/Preplanning',
            'Buy/Sell Business'                  => 'Buy/Sell Business',
            'Credit Counseling'                  => 'Credit Counseling',
            'Customer Relations'                 => 'Customer Relations',
            'Cyber Security/Cyber Awareness'     => 'Cyber Security/Cyber Awareness',
            'Disaster Planning/Recovery'         => 'Disaster Planning/Recovery',
            'eCommerce'                          => 'eCommerce',
            'Franchising'                        => 'Franchising',
            'Government Contracting'             => 'Government Contracting',
            'Human Resources/Managing Employees' => 'Human Resources/Managing Employees',
            'Intellectual Property Training'     => 'Intellectual Property Training',
            'International Trade'                => 'International Trade',
            'Legal Issues'                       => 'Legal Issues',
            'Marketing/Sales'                    => 'Marketing/Sales',
            'Tax Planning'                       => 'Tax Planning',
            'Technology'                         => 'Technology',
            // Legacy mappings from SBA888Batch
            'Buy/Sell a Business'                => 'Buy/Sell Business',
            'Cash Flow Management'               => 'Business Financial/Cash Flow',
            'COVID-19 Finance/Capital'           => 'Business Financing/Capital Sources',
            'COVID-19 General Support'           => 'Marketing/Sales',
            'Financing/Capital'                  => 'Business Financial/Cash Flow',
            'Managing Business'                  => 'Business Operations/Management',
            'Rural Business Development'         => 'Marketing/Sales',
            'Start-up Assistance'                => 'Business Start-up/Preplanning',
            'Women-Owned Business'               => 'Marketing/Sales',
            'Technology/Computers'               => 'Technology',
            'Not Set'                            => 'Other',
            'Unknown/Not Stated'                 => 'Other'
        };
        return topicMap.containsKey(topic) ? topicMap.get(topic) : 'Other';
    }

    // Build list of partner Code values from boolean/text fields
    private static List<String> buildPartnerCodes(SBA_888_Output__c r) {
        List<String> codes = new List<String>();
        if (String.isNotBlank(r.TrainingPartners_Code_ChamberOfCommerce__c)) codes.add('Chamber Of Commerce');
        if (String.isNotBlank(r.TrainingPartners_Code_Educational_Inst__c)) codes.add('Educational Institution');
        if (String.isNotBlank(r.TrainingPartners_Code_For_Profit_Org__c)) codes.add('For-Profit Organization');
        if (String.isNotBlank(r.TrainingPartners_Code_Native_American_Ct__c)) codes.add('Native American Center');
        if (String.isNotBlank(r.TrainingPartners_Code_Online_Training__c)) codes.add('Online Training Resource');
        if (String.isNotBlank(r.TrainingPartners_Code_SBA__c)) codes.add('SBA');
        if (String.isNotBlank(r.TrainingPartners_OtherSBA_District_Offic__c)) codes.add('SBA District Office');
        if (String.isNotBlank(r.TrainingPartners_Code_SBDC__c)) codes.add('SBDC');
        if (String.isNotBlank(r.TrainingPartners_Code_SCORE__c)) codes.add('SCORE');
        if (String.isNotBlank(r.TrainingPartners_Code_TradeOrProfessiona__c)) codes.add('Trade or Professional Association');
        if (String.isNotBlank(r.TrainingPartners_Code_VBOC__c)) codes.add('VBOC');
        if (String.isNotBlank(r.TrainingPartners_Code_Women_sBusinessCtr__c)) codes.add('Women\'s Business Center');
        if (String.isNotBlank(r.TrainingPartners_OtherAgency_OtherGovtAg__c)) codes.add('Other Government Agency');
        if (String.isNotBlank(r.TrainingPartners_Other_OtherResources__c)) codes.add('Other');
        return codes;
    }
}