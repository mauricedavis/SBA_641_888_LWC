/**
 * SBA641NormalizationHelper
 * All 641 field normalization. Stateless — no DML, no SOQL.
 * XSD authority: SBA_NEXUS_Counseling-2-14.xsd
 */
public with sharing class SBA641NormalizationHelper {

    // ── Race ──────────────────────────────────────────────────────────────────
    // Source: Contact.hed__Race__c (Multi-Select Picklist, semicolon-delimited)
    //         → SBA_641_Output__c.RaceClientIntake__c (Text 80)
    // XSD: <Race><Code maxOccurs="unbounded"> — full country names, strict enum
    // Data anomalies in sandbox: space-duplicate artifacts (e.g. 'White White')

    private static final Map<String,String> RACE_MAP = new Map<String,String>{
        'asian'                                    => 'Asian',
        'black or african american'                => 'Black or African American',
        'black'                                    => 'Black or African American', // legacy alias
        'middle eastern'                           => 'Middle Eastern',
        'native american/alaska native'            => 'Native American/Alaska Native',
        'native hawaiian/other pacific islander'   => 'Native Hawaiian/Other Pacific Islander',
        'north african'                            => 'North African',
        'white'                                    => 'White',
        'prefer not to say'                        => 'Prefer not to say', // case fix
        'prefer to self-describe'                  => 'Prefer to Self-Describe'
    };

    public static List<String> getRaceCodes(String raw) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) return result;
        Set<String> seen = new Set<String>();
        for (String token : raw.split(';')) {
            String clean = removeSpaceDuplicate(token.trim());
            if (String.isBlank(clean)) continue;
            String xsd = RACE_MAP.get(clean.toLowerCase());
            if (xsd == null) xsd = clean; // unknown — pass through
            String key = xsd.toLowerCase();
            if (!seen.contains(key)) { seen.add(key); result.add(xsd); }
        }
        return result;
    }

    /** Removes space-duplicate artifact: 'White White' → 'White' */
    @TestVisible
    static String removeSpaceDuplicate(String token) {
        if (String.isBlank(token) || !token.contains(' ')) return token;
        for (Integer i = 1; i < token.length(); i++) {
            if (token.charAt(i) == 32) { // 32 = ASCII space; charAt() returns Integer in Apex
                String first  = token.substring(0, i);
                String second = token.substring(i + 1);
                if (first.equalsIgnoreCase(second)) return first;
            }
        }
        return token;
    }

    // ── Country ───────────────────────────────────────────────────────────────
    // XSD CountryList <Code> = full country name ('United States'), NOT 2-letter code.
    // All Michigan SBDC clients are domestic. County names and zip codes normalize to US.
    // Blank → null (omit tag, XSD minOccurs='0').

    public static String normalizeCountry(String raw) {
        if (String.isBlank(raw)) return null;
        return 'United States';
    }

    // ── Ethnicity ──────────────────────────────────────────────────────────────
    // XSD enum (exact): 'Hispanic or Latino' | 'Non Hispanic or Latino' | 'Prefer not to say'
    // FIXED: 'No' → 'Non Hispanic or Latino' (was incorrectly 'Prefer not to say' in original)

    public static String normalizeEthnicity(String raw) {
        if (String.isBlank(raw)) return '';
        String v = raw.trim();
        if (v.equalsIgnoreCase('Yes') || v.equalsIgnoreCase('Hispanic or Latino'))
            return 'Hispanic or Latino';
        if (v.equalsIgnoreCase('No') || v.equalsIgnoreCase('Not Hispanic or Latino')
                || v.equalsIgnoreCase('Non Hispanic or Latino'))
            return 'Non Hispanic or Latino';
        if (v.equalsIgnoreCase('Prefer not to say') || v.equalsIgnoreCase('Unknown/Not Stated'))
            return 'Prefer not to say';
        return v;
    }

    // ── Phone ─────────────────────────────────────────────────────────────────
    // XSD PhoneType: xs:integer pattern [0-9]{10} (exactly 10 digits).
    // FIXED: returns null for short phones (do NOT pad with '9').

    public static String normalizePhone(String raw) {
        if (String.isBlank(raw)) return '';
        String d = raw.replaceAll('[^0-9]', '');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        if (d.length() > 10)  return d.substring(0, 10);
        if (d.length() < 10)  return null; // invalid — flag upstream, never pad
        return d;
    }

    // ── State expansion ───────────────────────────────────────────────────────

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

    public static String expandState(String raw) {
        if (String.isBlank(raw)) return '';
        String full = STATE_MAP.get(raw.trim().toUpperCase());
        return full != null ? full : raw.trim();
    }

    // ── XML escaping ──────────────────────────────────────────────────────────

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
