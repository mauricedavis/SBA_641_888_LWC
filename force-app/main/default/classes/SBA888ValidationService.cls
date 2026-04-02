/**
 * SBA888ValidationService
 * Validates SBA_888_Output__c records against SBA_NEXUS_Training-2-14.xsd requirements.
 * Returns ERROR and WARNING results for display in the sba888ReportingWizard.
 *
 * XSD-based rules:
 *   Required fields: PartnerTrainingNumber, LocationCode, DateTrainingStarted,
 *     NumberOfSessions, TotalTrainingHours, TrainingTitle, NumberTrained.Total,
 *     TrainingTopic, TrainingPartners, ProgramFormatType, Language
 *   Numeric ranges: LocationCode 1-9999999, TotalTrainingHours 0.01-9999.99,
 *     DollarAmountOfFees 0-1000000000, NumberTrained.Total >= 1
 *   Enum validation: TrainingTopic, ProgramFormatType, Language
 */
public with sharing class SBA888ValidationService {

    // ── Result types ──────────────────────────────────────────────────────────
    public class ValidationResult {
        @AuraEnabled public String recordId;
        @AuraEnabled public String partnerTrainingNumber;
        @AuraEnabled public String severity;  // ERROR | WARNING
        @AuraEnabled public String field;
        @AuraEnabled public String message;
    }

    public class ValidationSummary {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public Integer warningCount;
        @AuraEnabled public List<ValidationResult> results;
    }

    // ── Valid XSD enum sets ────────────────────────────────────────────────────
    private static final Set<String> VALID_TOPICS = new Set<String>{
        'Business Accounting/Budget', 'Business Financial/Cash Flow',
        'Business Financing/Capital Sources', 'Business Operations/Management',
        'Business Plan', 'Business Start-up/Preplanning', 'Buy/Sell Business',
        'Credit Counseling', 'Customer Relations', 'Cyber Security/Cyber Awareness',
        'Disaster Planning/Recovery', 'eCommerce', 'Franchising',
        'Government Contracting', 'Human Resources/Managing Employees',
        'Intellectual Property Training', 'International Trade', 'Legal Issues',
        'Marketing/Sales', 'Tax Planning', 'Technology', 'Other'
    };

    private static final Set<String> VALID_FORMAT_TYPES = new Set<String>{
        'Hybrid', 'In-person', 'On Demand', 'Online'
    };

    private static final Set<String> VALID_LANGUAGES = new Set<String>{
        'English', 'Spanish', 'Arabic', 'Armenian', 'ASL-American Sign Language',
        'Assamese', 'Borana', 'Burmese', 'Catalan/Valencian', 'Chinese-Cantonese',
        'Chinese-Mandarin', 'Chinese-Other', 'Chuukese', 'Croatian', 'Czech',
        'Farsi', 'Finnish', 'French', 'Fukien', 'Galician', 'German', 'Hmong',
        'Hungarian', 'Inupiat/Inupiaq', 'Italian', 'Japanese', 'Kamba', 'Kannada',
        'Khmer', 'Kikuyu/Gikuyu', 'Korean', 'Kosraean', 'Luo', 'Marshallese',
        'Palauan', 'Panjabi/Punjabi', 'Pohnpein', 'Portuguese', 'Russian',
        'Slovenian', 'Somali', 'Swahili', 'Tagalog/Filipino', 'Tajik', 'Tamil',
        'Thai', 'Vietnamese', 'Yapese', 'Yiddish', 'Other'
    };

    private static final Set<String> VALID_PARTNER_CODES = new Set<String>{
        'Chamber Of Commerce', 'Educational Institution', 'For-Profit Organization',
        'Native American Center', 'Online Training Resource', 'SBA', 'SBA District Office',
        'SBDC', 'SCORE', 'Trade or Professional Association', 'VBOC',
        'Women\'s Business Center', 'Other Government Agency', 'Other'
    };

    // ── Main validation entry point ────────────────────────────────────────────
    public static ValidationSummary validate(String quarterYear) {
        List<SBA_888_Output__c> records = [
            SELECT Id, PartnerTrainingNumber__c, LocationCode__c,
                   DateTrainingStarted__c, NumberOfSessions__c, TotalTrainingHours__c,
                   TrainingTitle__c, Total_NumberTrained__c, TrainingTopic__c,
                   ProgramFormatType__c, Language_Code__c, DollarAmountOfFees__c,
                   TrainingPartners_Code_ChamberOfCommerce__c,
                   TrainingPartners_Code_Educational_Inst__c,
                   TrainingPartners_Code_For_Profit_Org__c,
                   TrainingPartners_Code_Native_American_Ct__c,
                   TrainingPartners_Code_Online_Training__c,
                   TrainingPartners_Code_SBA__c,
                   TrainingPartners_OtherSBA_District_Offic__c,
                   TrainingPartners_Code_SBDC__c,
                   TrainingPartners_Code_SCORE__c,
                   TrainingPartners_Code_TradeOrProfessiona__c,
                   TrainingPartners_Code_VBOC__c,
                   TrainingPartners_Code_Women_sBusinessCtr__c,
                   TrainingPartners_OtherAgency_OtherGovtAg__c,
                   TrainingPartners_Other_OtherResources__c
            FROM SBA_888_Output__c
            WHERE RecordType.DeveloperName = :quarterYear
            ORDER BY PartnerTrainingNumber__c ASC
        ];

        List<ValidationResult> results = new List<ValidationResult>();
        Integer errorCount = 0;
        Integer warningCount = 0;

        for (SBA_888_Output__c r : records) {
            String ptn = String.isNotBlank(r.PartnerTrainingNumber__c)
                ? r.PartnerTrainingNumber__c : r.Id;
            List<ValidationResult> recResults = validateRecord(r, ptn);
            for (ValidationResult vr : recResults) {
                if (vr.severity == 'ERROR') errorCount++;
                else warningCount++;
            }
            results.addAll(recResults);
        }

        ValidationSummary summary = new ValidationSummary();
        summary.totalRecords  = records.size();
        summary.errorCount    = errorCount;
        summary.warningCount  = warningCount;
        summary.results       = results;
        return summary;
    }

    // ── Per-record validation ─────────────────────────────────────────────────
    private static List<ValidationResult> validateRecord(SBA_888_Output__c r, String ptn) {
        List<ValidationResult> out = new List<ValidationResult>();
        String id = r.Id;

        // ── Required fields ───────────────────────────────────────────────────
        if (String.isBlank(r.PartnerTrainingNumber__c)) {
            err(out, id, ptn, 'PartnerTrainingNumber', 'Required — cannot be blank');
        } else if (r.PartnerTrainingNumber__c.length() > 20) {
            err(out, id, ptn, 'PartnerTrainingNumber', 'Exceeds max length of 20 characters (' + r.PartnerTrainingNumber__c.length() + ')');
        }

        if (String.isBlank(r.LocationCode__c)) {
            err(out, id, ptn, 'LocationCode', 'Required — cannot be blank');
        } else {
            try {
                Integer loc = Integer.valueOf(r.LocationCode__c);
                if (loc < 1 || loc > 9999999) {
                    err(out, id, ptn, 'LocationCode', 'Must be between 1 and 9,999,999 (current: ' + loc + ')');
                }
            } catch (Exception e) {
                err(out, id, ptn, 'LocationCode', 'Must be a valid integer (current: ' + r.LocationCode__c + ')');
            }
        }

        if (r.DateTrainingStarted__c == null) {
            err(out, id, ptn, 'DateTrainingStarted', 'Required — cannot be blank');
        } else if (r.DateTrainingStarted__c > Date.today()) {
            warn(out, id, ptn, 'DateTrainingStarted', 'Date is in the future: ' + r.DateTrainingStarted__c);
        }

        if (r.NumberOfSessions__c == null) {
            err(out, id, ptn, 'NumberOfSessions', 'Required — cannot be blank');
        } else if (r.NumberOfSessions__c < 0 || r.NumberOfSessions__c > 1000000000) {
            err(out, id, ptn, 'NumberOfSessions', 'Must be between 0 and 1,000,000,000 (current: ' + r.NumberOfSessions__c + ')');
        }

        if (r.TotalTrainingHours__c == null) {
            err(out, id, ptn, 'TotalTrainingHours', 'Required — cannot be blank');
        } else if (r.TotalTrainingHours__c < 0.01 || r.TotalTrainingHours__c > 9999.99) {
            err(out, id, ptn, 'TotalTrainingHours', 'Must be between 0.01 and 9,999.99 (current: ' + r.TotalTrainingHours__c + ')');
        }

        if (String.isBlank(r.TrainingTitle__c)) {
            err(out, id, ptn, 'TrainingTitle', 'Required — cannot be blank');
        } else if (r.TrainingTitle__c.length() > 255) {
            err(out, id, ptn, 'TrainingTitle', 'Exceeds max length of 255 characters (' + r.TrainingTitle__c.length() + ')');
        }

        // ── NumberTrained ─────────────────────────────────────────────────────
        if (r.Total_NumberTrained__c == null) {
            err(out, id, ptn, 'NumberTrained.Total', 'Required — cannot be blank');
        } else if (r.Total_NumberTrained__c < 1) {
            err(out, id, ptn, 'NumberTrained.Total', 'Must be at least 1 (current: ' + r.Total_NumberTrained__c + ')');
        }

        // ── TrainingTopic enum ────────────────────────────────────────────────
        if (String.isBlank(r.TrainingTopic__c)) {
            err(out, id, ptn, 'TrainingTopic', 'Required — cannot be blank');
        } else if (!VALID_TOPICS.contains(r.TrainingTopic__c)) {
            // Check if it maps to a valid value via legacy mapping
            String mapped = SBA888_XMLBatch.mapTopicStatic(r.TrainingTopic__c);
            if (mapped == null || mapped == 'Other') {
                warn(out, id, ptn, 'TrainingTopic', 'Value "' + r.TrainingTopic__c + '" will be mapped to "Other" in the XML');
            }
        }

        // ── TrainingPartners — at least one must be populated ─────────────────
        Boolean hasPartner = String.isNotBlank(r.TrainingPartners_Code_ChamberOfCommerce__c)
            || String.isNotBlank(r.TrainingPartners_Code_Educational_Inst__c)
            || String.isNotBlank(r.TrainingPartners_Code_For_Profit_Org__c)
            || String.isNotBlank(r.TrainingPartners_Code_Native_American_Ct__c)
            || String.isNotBlank(r.TrainingPartners_Code_Online_Training__c)
            || String.isNotBlank(r.TrainingPartners_Code_SBA__c)
            || String.isNotBlank(r.TrainingPartners_OtherSBA_District_Offic__c)
            || String.isNotBlank(r.TrainingPartners_Code_SBDC__c)
            || String.isNotBlank(r.TrainingPartners_Code_SCORE__c)
            || String.isNotBlank(r.TrainingPartners_Code_TradeOrProfessiona__c)
            || String.isNotBlank(r.TrainingPartners_Code_VBOC__c)
            || String.isNotBlank(r.TrainingPartners_Code_Women_sBusinessCtr__c)
            || String.isNotBlank(r.TrainingPartners_OtherAgency_OtherGovtAg__c)
            || String.isNotBlank(r.TrainingPartners_Other_OtherResources__c);
        if (!hasPartner) {
            err(out, id, ptn, 'TrainingPartners', 'Required — at least one training partner must be specified');
        }

        // ── ProgramFormatType enum ────────────────────────────────────────────
        if (String.isBlank(r.ProgramFormatType__c)) {
            err(out, id, ptn, 'ProgramFormatType', 'Required — must be Hybrid, In-person, On Demand, or Online');
        } else if (!VALID_FORMAT_TYPES.contains(r.ProgramFormatType__c)) {
            err(out, id, ptn, 'ProgramFormatType', 'Invalid value "' + r.ProgramFormatType__c + '" — must be Hybrid, In-person, On Demand, or Online');
        }

        // ── Language enum ─────────────────────────────────────────────────────
        if (String.isBlank(r.Language_Code__c)) {
            err(out, id, ptn, 'Language', 'Required — cannot be blank');
        } else {
            for (String lang : r.Language_Code__c.split(';')) {
                String trimmed = lang.trim();
                if (!VALID_LANGUAGES.contains(trimmed)) {
                    warn(out, id, ptn, 'Language', 'Invalid language code "' + trimmed + '" — will be rejected by SBA');
                }
            }
        }

        // ── DollarAmountOfFees range ──────────────────────────────────────────
        if (r.DollarAmountOfFees__c != null) {
            if (r.DollarAmountOfFees__c < 0 || r.DollarAmountOfFees__c > 1000000000) {
                err(out, id, ptn, 'DollarAmountOfFees', 'Must be between 0 and 1,000,000,000 (current: ' + r.DollarAmountOfFees__c + ')');
            }
        }

        return out;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static void err(List<ValidationResult> out, String id, String ptn, String field, String msg) {
        ValidationResult r = new ValidationResult();
        r.recordId             = id;
        r.partnerTrainingNumber = ptn;
        r.severity             = 'ERROR';
        r.field                = field;
        r.message              = msg;
        out.add(r);
    }

    private static void warn(List<ValidationResult> out, String id, String ptn, String field, String msg) {
        ValidationResult r = new ValidationResult();
        r.recordId             = id;
        r.partnerTrainingNumber = ptn;
        r.severity             = 'WARNING';
        r.field                = field;
        r.message              = msg;
        out.add(r);
    }
}
