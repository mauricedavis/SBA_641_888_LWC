/**
 * SBA641NormalizationHelper
 * All 641 field normalization. Stateless — no DML, no SOQL.
 * XSD authority: SBA_NEXUS_Counseling-2-14.xsd
 */
public with sharing class SBA641NormalizationHelper {

    // ── Race ──────────────────────────────────────────────────────────────────
    // Source: Contact.hed__Race__c (Multi-Select Picklist, semicolon-delimited)
    //         → SBA_641_Output__c.RaceClientIntake__c (Text 80)
    // XSD: <Race><Code maxOccurs="unbounded"> — strict enum, multi-value allowed
    //
    // Data anomalies observed in sandbox:
    //   1. Space-duplicate artifacts:  'White White' → 'White'
    //   2. Concatenated multi-values:  'White Asian' → ['White','Asian']
    //      (occurs when Text(80) field truncates the semicolon separator)
    //   3. Truncated values: 'Black or African Ame' → 'Black or African American'
    //      (Text(80) field cuts off long values)

    // XSD-valid race values (lowercase keys for case-insensitive matching)
    private static final Map<String,String> RACE_MAP = new Map<String,String>{
        'asian'                                      => 'Asian',
        'black or african american'                  => 'Black or African American',
        'black'                                      => 'Black or African American',
        'middle eastern'                             => 'Middle Eastern',
        'native american/alaska native'              => 'Native American/Alaska Native',
        'native hawaiian/other pacific islander'     => 'Native Hawaiian/Other Pacific Islander',
        'north african'                              => 'North African',
        'white'                                      => 'White',
        'prefer not to say'                          => 'Prefer not to say',
        'prefer to self-describe'                    => 'Prefer to Self-Describe'
    };

    // Truncation repair map — maps known truncated prefixes to full XSD values
    // Keys must be lowercase; ordered from longest to shortest for correct matching
    private static final Map<String,String> TRUNCATION_MAP = new Map<String,String>{
        'native hawaiian/other pacific islan'        => 'Native Hawaiian/Other Pacific Islander',
        'native hawaiian/other pacific isla'         => 'Native Hawaiian/Other Pacific Islander',
        'native hawaiian/other pacific isl'          => 'Native Hawaiian/Other Pacific Islander',
        'native hawaiian/other pacific is'           => 'Native Hawaiian/Other Pacific Islander',
        'native hawaiian/other pacific i'            => 'Native Hawaiian/Other Pacific Islander',
        'native american/alaska nativ'               => 'Native American/Alaska Native',
        'native american/alaska nati'                => 'Native American/Alaska Native',
        'black or african american'                  => 'Black or African American',
        'black or african ame'                       => 'Black or African American',
        'black or african am'                        => 'Black or African American',
        'black or african a'                         => 'Black or African American',
        'prefer not to say'                          => 'Prefer not to say'
    };

    // Known concatenated multi-value patterns (no semicolon, space-separated XSD values)
    // Ordered longest-first so greedy matching works correctly
    private static final List<String> CONCAT_PATTERNS = new List<String>{
        'native hawaiian/other pacific islander',
        'native american/alaska native',
        'black or african american',
        'prefer to self-describe',
        'prefer not to say',
        'middle eastern',
        'north african',
        'asian',
        'white'
    };

    /**
     * Main entry point. Accepts semicolon-delimited or concatenated race values,
     * returns a deduplicated list of XSD-valid <Code> strings.
     */
    public static List<String> getRaceCodes(String raw) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) return result;
        Set<String> seen = new Set<String>();

        for (String token : raw.split(';')) {
            String cleaned = token.trim();
            if (String.isBlank(cleaned)) continue;

            // Step 1: Remove exact space-duplicate artifact ('White White' → 'White')
            cleaned = removeSpaceDuplicate(cleaned);

            // Step 2: Try direct RACE_MAP lookup
            String direct = RACE_MAP.get(cleaned.toLowerCase());
            if (direct != null) {
                addUnique(seen, result, direct);
                continue;
            }

            // Step 3: Try truncation repair
            String repaired = repairTruncation(cleaned);
            if (repaired != null) {
                addUnique(seen, result, repaired);
                continue;
            }

            // Step 4: Try greedy parse of concatenated values (e.g. 'White Asian')
            List<String> parsed = parseConcatenated(cleaned);
            if (!parsed.isEmpty()) {
                for (String v : parsed) addUnique(seen, result, v);
                continue;
            }

            // Step 5: Unknown value — pass through as-is (validation will flag it)
            addUnique(seen, result, cleaned);
        }
        return result;
    }

    // ── Step 1: Space-duplicate removal ──────────────────────────────────────
    // 'White White' → 'White'
    // 'Black or African American Black or African American' → 'Black or African American'

    @TestVisible
    static String removeSpaceDuplicate(String token) {
        if (String.isBlank(token) || !token.contains(' ')) return token;
        for (Integer i = 1; i < token.length(); i++) {
            if (token.charAt(i) == 32) { // 32 = ASCII space
                String first  = token.substring(0, i);
                String second = token.substring(i + 1);
                if (first.equalsIgnoreCase(second)) return first;
            }
        }
        return token;
    }

    // ── Step 3: Truncation repair ─────────────────────────────────────────────
    // 'Black or African Ame' → 'Black or African American'
    // 'Native Hawaiian/Other Pacific Islan' → 'Native Hawaiian/Other Pacific Islander'

    private static String repairTruncation(String token) {
        String lower = token.toLowerCase();
        if (TRUNCATION_MAP.containsKey(lower)) return TRUNCATION_MAP.get(lower);
        // Prefix match — try each entry
        for (String prefix : TRUNCATION_MAP.keySet()) {
            if (lower.startsWith(prefix) || prefix.startsWith(lower)) {
                return TRUNCATION_MAP.get(prefix);
            }
        }
        return null;
    }

    // ── Step 4: Greedy concatenated parse ─────────────────────────────────────
    // 'White Asian' → ['White', 'Asian']
    // 'White Native American/Alaska Native' → ['White', 'Native American/Alaska Native']
    // 'Prefer not to say Black or African American' → ['Prefer not to say', 'Black or African American']
    // 'North African Native American/Alaska' → ['North African', 'Native American/Alaska Native']

    private static List<String> parseConcatenated(String token) {
        List<String> result = new List<String>();
        String remaining = token.toLowerCase().trim();

        while (String.isNotBlank(remaining)) {
            Boolean matched = false;
            for (String pattern : CONCAT_PATTERNS) {
                if (remaining.startsWith(pattern)) {
                    result.add(RACE_MAP.get(pattern));
                    remaining = remaining.substring(pattern.length()).trim();
                    matched = true;
                    break;
                }
            }
            // Try truncation repair on remaining
            if (!matched) {
                String repaired = repairTruncation(remaining);
                if (repaired != null) {
                    result.add(repaired);
                    remaining = '';
                    matched = true;
                }
            }
            if (!matched) break; // can't parse remainder — caller will pass through
        }

        // Only return if we consumed the entire string
        return String.isBlank(remaining) ? result : new List<String>();
    }

    // ── Dedup helper ──────────────────────────────────────────────────────────

    private static void addUnique(Set<String> seen, List<String> result, String val) {
        String key = val.toLowerCase();
        if (!seen.contains(key)) {
            seen.add(key);
            result.add(val);
        }
    }

    // ── Country ───────────────────────────────────────────────────────────────

    public static String normalizeCountry(String raw) {
        if (String.isBlank(raw)) return null;
        return 'United States';
    }

    // ── Ethnicity ──────────────────────────────────────────────────────────────
    // FIXED: 'No' → 'Non Hispanic or Latino' (not 'Prefer not to say')

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

    public static String normalizePhone(String raw) {
        if (String.isBlank(raw)) return '';
        String d = raw.replaceAll('[^0-9]', '');
        if (d.length() == 11 && d.startsWith('1')) d = d.substring(1);
        if (d.length() > 10)  return d.substring(0, 10);
        if (d.length() < 10)  return null;
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
