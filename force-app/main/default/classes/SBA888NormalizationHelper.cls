/**
 * SBA888NormalizationHelper
 * All 888 field normalization. Stateless — no DML, no SOQL.
 * XSD authority: SBA_NEXUS_Training-2-25-2025.xsd
 */
public with sharing class SBA888NormalizationHelper {

    // ── Topic translations ─────────────────────────────────────────────────────

    private static final Map<String,String> TOPIC_MAP = new Map<String,String>{
        'Buy/Sell a Business'        => 'Buy/Sell Business',
        'Cash Flow Management'       => 'Business Financial/Cash Flow',
        'COVID-19 Finance/Capital'   => 'Business Financing/Capital Sources',
        'COVID-19 General Support'   => 'Marketing/Sales',
        'Financing/Capital'          => 'Business Financial/Cash Flow',
        'Managing Business'          => 'Business Operations/Management',
        'Rural Business Development' => 'Marketing/Sales',
        'Start-up Assistance'        => 'Business Start-up/Preplanning',
        'Women-Owned Business'       => 'Marketing/Sales',
        'Not Set'                    => 'Other',
        'Technology/Computers'       => 'Technology'
    };

    public static String normalizeTopic(String raw) {
        if (String.isBlank(raw)) return '';
        String mapped = TOPIC_MAP.get(raw.trim());
        return mapped != null ? mapped : raw.trim();
    }

    // ── Program format ─────────────────────────────────────────────────────────

    private static final Map<String,String> FORMAT_TYPE_MAP = new Map<String,String>{
        'Course'         => 'Online',
        'Webinar'        => 'Online',
        'Teleconference' => 'Online',
        'On-line Course' => 'Online',
        'Seminar'        => 'Online'
    };

    public static String normalizeProgramFormatType(String raw) {
        if (String.isBlank(raw)) return '';
        String mapped = FORMAT_TYPE_MAP.get(raw.trim());
        return mapped != null ? mapped : raw.trim();
    }

    public static String getProgramFormatRaw(String raw) {
        return String.isBlank(raw) ? '' : raw.trim();
    }

    // ── State expansion ─────────────────────────────────────────────────────────

    private static final Map<String,String> STATE_MAP = new Map<String,String>{
        'AL'=>'Alabama','AK'=>'Alaska','AZ'=>'Arizona','AR'=>'Arkansas',
        'CA'=>'California','CO'=>'Colorado','CT'=>'Connecticut','DE'=>'Delaware',
        'DC'=>'District of Columbia','FL'=>'Florida','GA'=>'Georgia',
        'HI'=>'Hawaii','ID'=>'Idaho','IL'=>'Illinois','IN'=>'Indiana',
        'IA'=>'Iowa','KS'=>'Kansas','KY'=>'Kentucky','LA'=>'Louisiana',
        'ME'=>'Maine','MD'=>'Maryland','MA'=>'Massachusetts','MI'=>'Michigan',
        'MN'=>'Minnesota','MS'=>'Mississippi','MO'=>'Missouri','MT'=>'Montana',
        'NE'=>'Nebraska','NV'=>'Nevada','NH'=>'New Hampshire','NJ'=>'New Jersey',
        'NM'=>'New Mexico','NY'=>'New York','NC'=>'North Carolina',
        'ND'=>'North Dakota','OH'=>'Ohio','OK'=>'Oklahoma','OR'=>'Oregon',
        'PA'=>'Pennsylvania','RI'=>'Rhode Island','SC'=>'South Carolina',
        'SD'=>'South Dakota','TN'=>'Tennessee','TX'=>'Texas','UT'=>'Utah',
        'VT'=>'Vermont','VA'=>'Virginia','WA'=>'Washington',
        'WV'=>'West Virginia','WI'=>'Wisconsin','WY'=>'Wyoming'
    };

    public static String getStateName(String raw) {
        if (String.isBlank(raw)) return '';
        String full = STATE_MAP.get(raw.trim().toUpperCase());
        return full != null ? full : raw.trim();
    }

    // ── Training partner codes ─────────────────────────────────────────────────
    // NOTE: 'list' is a reserved word in Apex — parameter named 'accumulator'

    private static void addIfNotBlank(List<String> accumulator, String val) {
        if (String.isNotBlank(val)) {
            accumulator.add(val);
        }
    }

    public static List<String> getPartnerCodes(SBA_888_Output__c r) {
        List<String> codes = new List<String>();
        addIfNotBlank(codes, r.TrainingPartners_Code_ChamberOfCommerce__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_Educational_Inst__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_For_Profit_Org__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_Native_American_Ct__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_Online_Training__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_SBDC__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_SCORE__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_TradeOrProfessiona__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_VBOC__c);
        addIfNotBlank(codes, r.TrainingPartners_Code_Women_sBusinessCtr__c);
        return codes;
    }

    // ── XML escaping ───────────────────────────────────────────────────────────

    public static String esc(String s) {
        if (s == null) return '';
        s = s.replaceAll('&',  '&amp;');
        s = s.replaceAll('<',  '&lt;');
        s = s.replaceAll('>',  '&gt;');
        s = s.replaceAll('"',  '&quot;');
        s = s.replaceAll('\'', '&apos;');
        return s;
    }
}
