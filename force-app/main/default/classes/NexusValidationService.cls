/**
 * NexusValidationService
 * XSD-compliant upstream validation for 641 and 888 pipelines.
 * Called before XML generation by SBA641ReportController / SBA888ReportController.
 * Stateless — no DML, no SOQL.
 *
 * XSD authority: SBA_NEXUS_Counseling-2-14.xsd, SBA_NEXUS_Training-2-25-2025.xsd
 */
public with sharing class NexusValidationService {

    public class ValidationResult {
        @AuraEnabled public String recordId;
        @AuraEnabled public String partnerNumber;
        @AuraEnabled public String field;
        @AuraEnabled public String severity;     // 'ERROR' | 'WARNING'
        @AuraEnabled public String message;
        @AuraEnabled public String displayLabel;

        public ValidationResult(String recordId, String partnerNumber,
                                  String field, String severity, String message) {
            this.recordId      = recordId;
            this.partnerNumber = partnerNumber;
            this.field         = field;
            this.severity      = severity;
            this.message       = message;
            this.displayLabel  = partnerNumber + ' — ' + field + ': ' + message;
        }
    }

    // XSD-valid enum sets
    private static final Set<String> VALID_RACE = new Set<String>{
        'Asian','Black or African American','Middle Eastern',
        'Native American/Alaska Native','Native Hawaiian/Other Pacific Islander',
        'North African','White','Prefer not to say','Prefer to Self-Describe'
    };
    private static final Set<String> VALID_ETHNICITY = new Set<String>{
        'Hispanic or Latino','Non Hispanic or Latino','Prefer not to say'
    };
    private static final Set<String> VALID_SEX = new Set<String>{ 'Male','Female','' };
    private static final Set<String> VALID_MILITARY = new Set<String>{
        'Active Duty','Member of National Guard','Member of the Reserve',
        'No military service','Service Disabled Veteran','Spouse of Military Member',
        'Veteran','Prefer not to say'
    };
    private static final Set<String> VALID_SESSION_TYPE = new Set<String>{
        'Face-to-face','Online','Prepare Only','Telephone','Training','Update Only'
    };

    // ── 641 validation ───────────────────────────────────────────────────────

    public static List<ValidationResult> validate641Records(List<SBA_641_Output__c> records) {
        List<ValidationResult> out = new List<ValidationResult>();
        for (SBA_641_Output__c r : records) {
            String id = r.Id;
            String pn = String.isNotBlank(r.PartnerClientNumber__c) ? r.PartnerClientNumber__c : r.Id;

            if (String.isBlank(r.PartnerClientNumber__c)) err(out,id,pn,'PartnerClientNumber','Required — cannot be blank');
            if (String.isBlank(r.LocationCode__c))        err(out,id,pn,'LocationCode','Required — cannot be blank');
            if (String.isBlank(r.LastClientNamePart1__c)) err(out,id,pn,'LastName (Part1)','Required per XSD PersonType');
            if (String.isBlank(r.FirstClientNamePart1__c))err(out,id,pn,'FirstName (Part1)','Required per XSD PersonType');
            if (String.isBlank(r.PartnerSessionNumber_Counselor__c)) err(out,id,pn,'PartnerSessionNumber','Required — cannot be blank');

            // Race
            if (String.isBlank(r.RaceClientIntake__c)) {
                err(out,id,pn,'Race','XSD requires at least one Race code — field is blank');
            } else {
                List<String> codes = SBA641NormalizationHelper.getRaceCodes(r.RaceClientIntake__c);
                if (codes.isEmpty()) err(out,id,pn,'Race','No valid codes resolved from: "' + r.RaceClientIntake__c + '"');
                for (String code : codes) {
                    if (!VALID_RACE.contains(code)) warn(out,id,pn,'Race','Value "' + code + '" not in XSD enum');
                }
            }

            // Ethnicity
            if (String.isNotBlank(r.EthnicityClientIntake__c)) {
                String eth = SBA641NormalizationHelper.normalizeEthnicity(r.EthnicityClientIntake__c);
                if (!VALID_ETHNICITY.contains(eth))
                    warn(out,id,pn,'Ethnicity','"' + r.EthnicityClientIntake__c + '" will normalize to "' + eth + '"');
            }

            // Sex (XSD change #140)
            if (String.isNotBlank(r.SexClientIntake__c) && !VALID_SEX.contains(r.SexClientIntake__c))
                warn(out,id,pn,'Sex','"' + r.SexClientIntake__c + '" not in XSD enum (Male/Female/empty)');

            // Phone
            phoneCheck(out,id,pn,r.PrimaryPhonePart1__c,'PrimaryPhone (Part1)');
            phoneCheck(out,id,pn,r.Primary_PhonePart3__c,'PrimaryPhone (Part3)');

            // Country — non-standard warns; will normalize to 'United States'
            countryCheck(out,id,pn,r.CountryAddressPart1__c,'Country (Part1)');
            countryCheck(out,id,pn,r.Country_AddressPart3__c,'Country (Part3)');

            // Military status
            if (String.isNotBlank(r.MilitaryStatusClientIntake__c)
                    && !VALID_MILITARY.contains(r.MilitaryStatusClientIntake__c))
                warn(out,id,pn,'MilitaryStatus','"' + r.MilitaryStatusClientIntake__c + '" not in XSD enum');

            // Session type
            if (String.isNotBlank(r.SessionType_CounselorRecord__c)
                    && !VALID_SESSION_TYPE.contains(r.SessionType_CounselorRecord__c))
                warn(out,id,pn,'SessionType','"' + r.SessionType_CounselorRecord__c + '" not in XSD enum');

            // Date counseled
            if (r.DateCounseled_CounselorRecord__c == null)
                warn(out,id,pn,'DateCounseled','Blank — recommended for XSD compliance');
        }
        return out;
    }

    // ── 888 validation ───────────────────────────────────────────────────────

    public static List<ValidationResult> validate888Records(List<SBA_888_Output__c> records) {
        List<ValidationResult> out = new List<ValidationResult>();
        for (SBA_888_Output__c r : records) {
            String id = r.Id;
            String pn = String.isNotBlank(r.PartnerTrainingNumber__c) ? r.PartnerTrainingNumber__c : r.Id;

            if (String.isBlank(r.PartnerTrainingNumber__c)) err(out,id,pn,'PartnerTrainingNumber','Required — cannot be blank');
            if (String.isBlank(r.LocationCode__c))          err(out,id,pn,'LocationCode','Required — cannot be blank');
            if (r.Total_NumberTrained__c == null || r.Total_NumberTrained__c <= 0)
                err(out,id,pn,'TotalNumberTrained','Must be > 0');
            if (r.DateTrainingStarted__c == null)
                warn(out,id,pn,'DateTrainingStarted','Blank — recommended');
            if (String.isBlank(r.TrainingTopic__c))
                warn(out,id,pn,'TrainingTopic','Blank — will emit empty code');
        }
        return out;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static void err(List<ValidationResult> o, String id, String pn, String f, String m) {
        o.add(new ValidationResult(id,pn,f,'ERROR',m));
    }
    private static void warn(List<ValidationResult> o, String id, String pn, String f, String m) {
        o.add(new ValidationResult(id,pn,f,'WARNING',m));
    }
    private static void phoneCheck(List<ValidationResult> o, String id, String pn, String raw, String lbl) {
        if (String.isBlank(raw)) return;
        String d = raw.replaceAll('[^0-9]','');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        if      (d.length() > 10) warn(o,id,pn,lbl,'Has ' + d.length() + ' digits — will truncate to 10');
        else if (d.length() < 10) err(o,id,pn,lbl,'Only ' + d.length() + ' digits — must correct before generating');
    }
    private static void countryCheck(List<ValidationResult> o, String id, String pn, String raw, String lbl) {
        if (String.isBlank(raw)) return;
        if (raw != 'United States' && raw != 'USA' && raw != 'US')
            warn(o,id,pn,lbl,'"' + raw + '" is non-standard — will normalize to "United States"');
    }
}
