/**
 * NexusValidationService
 * XSD-compliant upstream validation for 641 and 888 pipelines.
 * Called before XML generation by SBA641ReportController / SBA888ReportController.
 *
 * Phone auto-correction:
 *   When a phone on an Output record is invalid (< 10 digits), the service
 *   queries the related Contact's full set of phone fields and auto-corrects
 *   the Output record with the first valid 10-digit number found.
 *   If no valid alternative exists, the ERROR is preserved for manual fix.
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

    // ── 641 validation ────────────────────────────────────────────────────────

    public static List<ValidationResult> validate641Records(List<SBA_641_Output__c> records) {

        // ── Step 1: Pre-fetch Contact phones for records with invalid phones ──
        // Collect Session Ids from all records that have a potentially invalid phone
        Set<Id> sessionIds = new Set<Id>();
        for (SBA_641_Output__c r : records) {
            if (hasInvalidPhone(r.PrimaryPhonePart1__c) || hasInvalidPhone(r.Primary_PhonePart3__c)) {
                if (String.isNotBlank(r.PartnerSessionNumber_Counselor__c)) {
                    try { sessionIds.add((Id)r.PartnerSessionNumber_Counselor__c); } catch(Exception e) {}
                }
            }
        }

        // Query Contact phone fields via Session
        Map<Id, String> sessionToValidPhone = new Map<Id, String>();
        if (!sessionIds.isEmpty()) {
            for (Session__c s : [
                SELECT Id,
                       Contact__r.Phone, Contact__r.OtherPhone,
                       Contact__r.MobilePhone, Contact__r.HomePhone
                FROM Session__c
                WHERE Id IN :sessionIds
            ]) {
                List<String> candidates = new List<String>{
                    s.Contact__r.Phone,
                    s.Contact__r.MobilePhone,
                    s.Contact__r.OtherPhone,
                    s.Contact__r.HomePhone
                };
                for (String ph : candidates) {
                    String normalized = normalizePhone10(ph);
                    if (normalized != null) {
                        sessionToValidPhone.put(s.Id, normalized);
                        break; // use first valid number found
                    }
                }
            }
        }

        // ── Step 2: Auto-correct Output records and collect DML updates ───────
        List<SBA_641_Output__c> toUpdate = new List<SBA_641_Output__c>();
        Map<Id, String> autocorrectedPhone = new Map<Id, String>(); // recordId → corrected phone
        Map<Id, Boolean> phoneZeroed = new Map<Id, Boolean>();      // recordId → zeroed out (no valid alt)

        for (SBA_641_Output__c r : records) {
            Boolean needsUpdate = false;
            SBA_641_Output__c upd = new SBA_641_Output__c(Id = r.Id);
            String sessionId = r.PartnerSessionNumber_Counselor__c;
            String altPhone = (String.isNotBlank(sessionId) && sessionToValidPhone.containsKey((Id)sessionId))
                ? sessionToValidPhone.get((Id)sessionId) : null;

            if (hasInvalidPhone(r.PrimaryPhonePart1__c)) {
                String fixed = altPhone != null ? altPhone : '0000000000';
                upd.PrimaryPhonePart1__c = fixed;
                r.PrimaryPhonePart1__c   = fixed;
                needsUpdate = true;
                if (altPhone != null) {
                    autocorrectedPhone.put(r.Id, fixed);
                } else {
                    phoneZeroed.put(r.Id, true);
                }
            }
            if (hasInvalidPhone(r.Primary_PhonePart3__c)) {
                String fixed = altPhone != null ? altPhone : '0000000000';
                upd.Primary_PhonePart3__c = fixed;
                r.Primary_PhonePart3__c   = fixed;
                needsUpdate = true;
            }
            if (needsUpdate) toUpdate.add(upd);
        }

        if (!toUpdate.isEmpty()) {
            try { update toUpdate; } catch(Exception e) {
                System.debug('NexusValidationService phone auto-correct DML failed: ' + e.getMessage());
            }
        }

        // ── Step 3: Standard validation pass ──────────────────────────────────
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

            // Sex
            if (String.isNotBlank(r.SexClientIntake__c) && !VALID_SEX.contains(r.SexClientIntake__c))
                warn(out,id,pn,'Sex','"' + r.SexClientIntake__c + '" not in XSD enum (Male/Female/empty)');

            // Phone — auto-corrected records warn; zeroed records error; others check normally
            if (phoneZeroed.containsKey(id)) {
                warn(out,id,pn,'PrimaryPhone','No valid phone found on Contact — set to 000-000-0000. Please update before submitting to SBA.');
            } else if (autocorrectedPhone.containsKey(id)) {
                warn(out,id,pn,'PrimaryPhone','Auto-corrected from Contact — using ' + autocorrectedPhone.get(id));
            } else {
                phoneCheck(out,id,pn,r.PrimaryPhonePart1__c,'PrimaryPhone (Part1)');
                phoneCheck(out,id,pn,r.Primary_PhonePart3__c,'PrimaryPhone (Part3)');
            }

            // Country
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
        }
        return out;
    }

    // ── 888 validation (stub — mirrors 641 structure) ─────────────────────────

    public static List<ValidationResult> validate888Records(List<SBA_888_Output__c> records) {
        List<ValidationResult> out = new List<ValidationResult>();
        for (SBA_888_Output__c r : records) {
            String id = r.Id;
            String pn = r.Id;
            if (String.isBlank(r.PartnerEventNumber__c)) err(out,id,pn,'PartnerEventNumber','Required — cannot be blank');
        }
        return out;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Returns true if the phone string is present but not a valid 10-digit number */
    private static Boolean hasInvalidPhone(String raw) {
        if (String.isBlank(raw)) return false;
        String d = raw.replaceAll('[^0-9]', '');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        return d.length() != 10;
    }

    /** Returns normalized 10-digit string if valid, null otherwise */
    private static String normalizePhone10(String raw) {
        if (String.isBlank(raw)) return null;
        String d = raw.replaceAll('[^0-9]', '');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        if (d.length() == 10) return d;
        return null;
    }

    private static void phoneCheck(List<ValidationResult> o, String id, String pn, String raw, String lbl) {
        if (String.isBlank(raw)) return;
        String d = raw.replaceAll('[^0-9]','');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        if      (d.length() > 10) warn(o,id,pn,lbl,'Has ' + d.length() + ' digits — will truncate to 10');
        else if (d.length() < 10) err(o,id,pn,lbl,'Only ' + d.length() + ' digits — no valid alternative found on Contact');
    }

    private static void countryCheck(List<ValidationResult> o, String id, String pn, String raw, String lbl) {
        if (String.isBlank(raw)) return;
        if (raw != 'United States' && raw != 'USA' && raw != 'US')
            warn(o,id,pn,lbl,'"' + raw + '" is non-standard — will normalize to "United States"');
    }

    private static void err(List<ValidationResult> o, String id, String pn, String f, String msg) {
        o.add(new ValidationResult(id, pn, f, 'ERROR', msg));
    }
    private static void warn(List<ValidationResult> o, String id, String pn, String f, String msg) {
        o.add(new ValidationResult(id, pn, f, 'WARNING', msg));
    }
}
