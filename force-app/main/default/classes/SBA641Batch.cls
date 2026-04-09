public with sharing class SBA641Batch implements Database.Batchable<SObject>, Database.Stateful {
    private Integer processedRecordsCount = 0;

    private Date startDate;
    private Date endDate;
    private String varRecordTypeId;
    private String varQuarterYear;   // Store the Quarter_Year value
    private String xmlOutput = '';  // To store the generated XML content
    private Map<String, String> counselingMapping = new Map<String, String>(); // Map for Area_of_Counseling__c to CounselingSeeking_ClientIntake__c

    // Constructor to initialize the date range, RecordTypeId, and counseling mappings
    public SBA641Batch(Date startDate, Date endDate, String varRecordTypeId, String varQuarterYear) {
        this.startDate = startDate;
        this.endDate = endDate;
        this.varRecordTypeId = varRecordTypeId;
        this.varQuarterYear = varQuarterYear;    // Assign the passed varQuarterYear value
        this.initializeCounselingMapping(); // Initialize the mapping
    }
    
    public static String normalizeCountry(String country) {
    if ('United states'.equalsIgnoreCase(country)) {
        return 'United States';
    }
    return country;
    }
    
    
    
    // Define allowed values for LegalEntity_ClientIntake__c
    Set<String> allowedLegalEntities = new Set<String>{
        'Corporation', 'LLC', 'Partnership', 'Sole Proprietor', 'S-Corporation', 'Other'
    };
        
    // Helper method to clean the phone #'s
    private static String cleanPhoneNumber(String phone) {
    if (String.isBlank(phone)) {
        return ''; // Return an empty string if the phone is null or blank
    }
    // Remove all non-digit characters from the phone number
    return phone.replaceAll('[^0-9]', '');
    }

    // Method to translate EthnicityClientIntake__c values
    public static String translateEthnicity(String originalValue) {
        if (originalValue == 'No Reply') {
            return 'Prefer not to say';
        } else if (originalValue == 'Arab or Middle Eastern') {
            return 'Middle Eastern';
        } else if (originalValue == 'American Native or Alaskan Native') {
            return 'Native American/Alaska Native';
        }
        return originalValue; // Return original value if no match
    }

    //Camel Case Utility Method for converting ExportCountries
    public static String toCamelCaseCountries(String input) {
    if (String.isBlank(input)) {
        return '';
    }

    List<String> wordsToExclude = new List<String>{'and', 'of', 'the'};
    List<String> countries = input.split(';');
    List<String> transformedCountries = new List<String>();

    for (String country : countries) {
        String[] words = country.trim().toLowerCase().split(' ');
        for (Integer i = 0; i < words.size(); i++) {
            if (i == 0 || !wordsToExclude.contains(words[i])) {
                words[i] = words[i].capitalize();
            }
        }
        transformedCountries.add(String.join(words, ' '));
    }

    return String.join(transformedCountries, '; ');
    }

    // Method to populate the counselingMapping map
    private void initializeCounselingMapping() {
        counselingMapping.put('100 Business Startup & Acquisition: Business Start-Up', 'Business Start-up/Preplanning');
        counselingMapping.put('101 Business Startup & Acquisition: Business Planning', 'Business Start-up/Preplanning');
        counselingMapping.put('102 Business Startup & Acquisition: Start-up Financial Planning', 'Business Start-up/Preplanning');
        counselingMapping.put('104 Business Startup & Acquisition: Franchisee Assistance', 'Business Start-up/Preplanning');
        counselingMapping.put('105 Business Startup & Acquisition: Legal Assistance', 'Business Start-up/Preplanning');
        counselingMapping.put('106 Business Startup & Acquisition: Business Acquisition', 'Business Start-up/Preplanning');
        counselingMapping.put('108 Business Startup & Acquisition: Business Plan Review', 'Business Start-up/Preplanning');
        counselingMapping.put('200 Sources of Capital: Sources of Capital', 'Business Financing/Capital Sources');
        counselingMapping.put('201 Sources of Capital: Loan Pkg Development', 'Business Financing/Capital Sources');
        counselingMapping.put('202 Sources of Capital: SBA Loan Guarantee App', 'Business Financing/Capital Sources');
        counselingMapping.put('204 Sources of Capital: Venture Capital', 'Business Financing/Capital Sources');
        counselingMapping.put('300 Marketing & Sales: Marketing & Sales', 'Marketing/Sales');
        counselingMapping.put('301 Marketing & Sales: Marketing Plan', 'Marketing/Sales');
        counselingMapping.put('302 Marketing & Sales: Market/Feasibility Study', 'Marketing/Sales');
        counselingMapping.put('303 Marketing & Sales: Advertising & Promotion', 'Marketing/Sales');
        counselingMapping.put('304 Marketing & Sales: Pricing Strategy', 'Marketing/Sales');
        counselingMapping.put('305 Marketing & Sales: Market Penetration', 'Marketing/Sales');
        counselingMapping.put('306 Marketing & Sales: Business Expansion', 'Marketing/Sales');
        counselingMapping.put('307 Marketing & Sales: Franchisor Assistance', 'Franchising');
        counselingMapping.put('308 Marketing & Sales: Site Location', 'Marketing/Sales');
        counselingMapping.put('309 Marketing & Sales: Licensing Agreements', 'Marketing/Sales');
        counselingMapping.put('310 Marketing & Sales: Business Relocation', 'Marketing/Sales');
        counselingMapping.put('311 Marketing & Sales: Marketing Upgrade', 'Marketing/Sales');
        counselingMapping.put('312 Marketing & Sales: Market Research', 'Marketing/Sales');
        counselingMapping.put('316 Marketing & Sales: Website/Social Media', 'Marketing/Sales');
        counselingMapping.put('317 Marketing & Sales: E-Commerce', 'eCommerce');
        counselingMapping.put('400 Government Procurement: Govt Procurement Assistance', 'Government Contracting');
        counselingMapping.put('402 Government Procurement: Marketing to the Government', 'Government Contracting');
        counselingMapping.put('408 Government Procurement: Minority Business Certification', 'Government Contracting');
        counselingMapping.put('500 Accounting & Recordkeeping: Accounting & Recordkeeping', 'Business Accounting/Budget');
        counselingMapping.put('501 Accounting & Recordkeeping: Job Costing Systems', 'Business Accounting/Budget');
        counselingMapping.put('504 Accounting & Recordkeeping: Legal Aspects', 'Business Accounting/Budget');
        counselingMapping.put('505 Accounting & Recordkeeping: Bookkeeping', 'Business Accounting/Budget');
        counselingMapping.put('506 Accounting & Recordkeeping: Fiscal Fitness', 'Business Accounting/Budget');
        counselingMapping.put('600 Financial Analysis & Cost Control: Financial Analysis & Review', 'Business Financial/Cash Flow');
        counselingMapping.put('601 Financial Analysis & Cost Control: Cash Flow Projections/Analysis', 'Business Financial/Cash Flow');
        counselingMapping.put('602 Financial Analysis & Cost Control: Financial Statement Analysis', 'Business Financial/Cash Flow');
        counselingMapping.put('603 Financial Analysis & Cost Control: Tax Planning', 'Business Financial/Cash Flow');
        counselingMapping.put('605 Financial Analysis & Cost Control: Business Valuation', 'Business Financial/Cash Flow');
        counselingMapping.put('606 Financial Analysis & Cost Control: A/R Collections', 'Business Financial/Cash Flow');
        counselingMapping.put('700 Inventory Control: Inventory Control', 'Business Operations/Management');
        counselingMapping.put('801 Engineering R&D: Engineering', 'Technology');
        counselingMapping.put('802 Engineering R&D: Research & Development', 'Technology');
        counselingMapping.put('900 Personnel/Human Resources: Personnel/Human Resources', 'Human Resources/Managing Employees');
        counselingMapping.put('901 Personnel/Human Resources: Employee/Admin Manuals', 'Human Resources/Managing Employees');
        counselingMapping.put('902 Personnel/Human Resources: EEO & Legal Aspects', 'Human Resources/Managing Employees');
        counselingMapping.put('903 Personnel/Human Resources: Compensation', 'Human Resources/Managing Employees');
        counselingMapping.put('904 Personnel/Human Resources: Recruiting/Employee Selection', 'Human Resources/Managing Employees');
        counselingMapping.put('905 Personnel/Human Resources: Training Programs', 'Human Resources/Managing Employees');
        counselingMapping.put('906 Personnel/Human Resources: Job Descriptions', 'Human Resources/Managing Employees');
        counselingMapping.put('907 Personnel/Human Resources: Family-Owned Business', 'Human Resources/Managing Employees');
        counselingMapping.put('908 Personnel/Human Resources: Worker Safety', 'Human Resources/Managing Employees');
        counselingMapping.put('909 Personnel/Human Resources: Contract Employees', 'Human Resources/Managing Employees');
        counselingMapping.put('910 Personnel/Human Resources: Workers Compensation', 'Human Resources/Managing Employees');
        counselingMapping.put('1000 Computer Systems: Computer Systems Planning', 'Technology');
        counselingMapping.put('1002 Computer Systems: Point of Sale Systems', 'Technology');
        counselingMapping.put('1003 Computer Systems: Financial & Accounting Systems', 'Technology');
        counselingMapping.put('1101 International Trade: Export Planning', 'International Trade');
        counselingMapping.put('1102 International Trade: Export Marketing', 'International Trade');
        counselingMapping.put('1103 International Trade: Importing', 'International Trade');
        counselingMapping.put('1104 International Trade: FTZ Assistance', 'International Trade');
        counselingMapping.put('1106 International Trade: Export Readiness Assessment', 'International Trade');
        counselingMapping.put('1107 International Trade: Landed Cost Assistance', 'International Trade');
        counselingMapping.put('1108 International Trade: EEA - Early Export Assistance', 'International Trade');
        counselingMapping.put('1110 International Trade: Market Research', 'International Trade');
        counselingMapping.put('1200 Business Liquidation: Business Liquidation', 'Buy/Sell Business');
        counselingMapping.put('1201 Business Liquidation: Bankruptcy', 'Buy/Sell Business');
        counselingMapping.put('1202 Business Liquidation: Business Valuation', 'Buy/Sell Business');
        counselingMapping.put('1203 Business Liquidation: Contractual/Legal Aspects', 'Buy/Sell Business');
        counselingMapping.put('1300 Technology: Technology', 'Technology');
        counselingMapping.put('1301 Technology: Inventor Assistance', 'Technology');
        counselingMapping.put('1303 Technology: Preliminary Patent Search', 'Technology');
        counselingMapping.put('1304 Technology: Preliminary Trademark Search', 'Technology');
        counselingMapping.put('1307 Technology: Strategic Business Plan', 'Technology');
        counselingMapping.put('1310 Technology: Roadmapping', 'Technology');
        counselingMapping.put('1312 Technology: Business Assessment', 'Technology');
        counselingMapping.put('1313 Technology: Cybersecurity', 'Cyber Security/Cyber Awareness');
        counselingMapping.put('1501 Other Assistance: Customer Follow-Up', 'Customer Relations');
        counselingMapping.put('1502 Other Assistance: Management Team', 'Human Resources/Managing Employees');
        counselingMapping.put('1503 Other Assistance: Strategic Planning', 'Business Operations/Management');
        counselingMapping.put('1504 Other Assistance: Forecasting', 'Business Financial/Cash Flow');
        counselingMapping.put('1506 Other Assistance: Technical Evaluation', 'Business Operations/Management');
        counselingMapping.put('1507 Other Assistance: Advisory Board', 'Business Operations/Management');
        counselingMapping.put('1508 Other Assistance: Customer Referral', 'Business Operations/Management');
        counselingMapping.put('1513 Other Assistance: Strategic Needs Assessment', 'Business Operations/Management');
        counselingMapping.put('1516 Other Assistance: Focus Four', 'Business Operations/Management');
        counselingMapping.put('1519 Other Assistance: Process Improvement', 'Business Operations/Management');
        counselingMapping.put('1520 Other Assistance: Transition Planning', 'Business Operations/Management');
        counselingMapping.put('1521 Other Assistance: Value Builder', 'Business Operations/Management');
        counselingMapping.put('1522 Other Assistance: Training Event', 'Business Operations/Management');
        counselingMapping.put('1600 Grant Assistance: Grant Assistance', 'Business Financing/Capital Sources');
        counselingMapping.put('1601 Grant Assistance: SBIR Phase I Submission', 'Business Financing/Capital Sources');
        counselingMapping.put('1602 Grant Assistance: SBIR Phase II Submission', 'Business Financing/Capital Sources');
        counselingMapping.put('1603 Grant Assistance: SBIR Phase III Assistance', 'Business Financing/Capital Sources');
        counselingMapping.put('1700 IP Assistance: Patent & Trademark', 'Intellectual Property Training');
        counselingMapping.put('1800 Venture Capital/Angel Assistance: Investor Presentation', 'Business Financing/Capital Sources');
        counselingMapping.put('1802 Venture Capital/Angel Assistance: Equity Investment', 'Business Financing/Capital Sources');
        counselingMapping.put('1804 Venture Capital/Angel Assistance: Elevator Pitch', 'Business Financing/Capital Sources');
        counselingMapping.put('1805 Venture Capital/Angel Assistance: Executive Summary', 'Business Financing/Capital Sources');
        counselingMapping.put('Legacy', 'Marketing/Sales');
        counselingMapping.put('9900 COVID-19: General Disaster Support', 'Marketing/Sales');
        counselingMapping.put('9901 COVID-19: Financing/Capital', 'Business Financing/Capital Sources');
        counselingMapping.put('103 Business Startup & Acquisition: Home-Based Business', 'Business Start-up/Preplanning');
        counselingMapping.put('1100 International Trade: International Trade', 'International Trade');
        counselingMapping.put('1400 Energy/Environmental: General Energy Counseling', 'Marketing/Sales');
    }

    // Utility method to escape XML characters
    public static String escapeXml(String input) {
        if (input == null) {
            return '';
        }
        input = input.replaceAll('&', '&amp;');
        input = input.replaceAll('<', '&lt;');
        input = input.replaceAll('>', '&gt;');
        input = input.replaceAll('"', '&quot;');
        input = input.replaceAll('\'', '&apos;');
        return input;
    }
    
        public static String translateRace(String race) {
        if (String.isBlank(race)) {
            return null;
        }

        // Handle specific translations
        if ('American Indian or Alaska Native'.equalsIgnoreCase(race)) {
            return 'Native American/Alaska Native';
        }
        if ('Other'.equalsIgnoreCase(race)) {
            return 'Prefer not to say';
        }
        if ('Arab or Middle Eastern'.equalsIgnoreCase(race)) {
            return 'Middle Eastern';
        }

        // Return the input value if no translation is applied
        return race;
    }
    
    // Define the accepted list of values
    Set<String> acceptedMediaValues = new Set<String>{
    'Boots to Business',
    'Business Owner',
    'Chamber of Commerce',
    'Educational Institution',
    'Internet',
    'Lender',
    'Local Economic Development Official',
    'Magazine/Newspaper',
    'SBA District',
    'SBA Web site',
    'SBDC',
    'SCORE',
    'Television/Radio',
    'USEAC',
    'VBOC',
    'VRE',
    'WBC',
    'Word of Mouth',
    'Other Client',
    'Other'
    };
        
    // Define the business status values
    Set<String> notInBusinessStatuses = new Set<String>{
        'Not Yet In Business',
        'Closed Business',
        'Sold Business'
    };
        
        // Define a map for Delivery_Type__c to SessionType_CounselorRecord__c conversions
        Map<String, String> deliveryTypeMap = new Map<String, String>{
            'Center' => 'Face-to-face',
            'E-Mail' => 'Online',
            'Group' => 'Face-to-face',
            'Mail' => 'Update Only',
            'Client Site' => 'Face-to-face',
            'Satellite' => 'Face-to-face',
            'Telephone' => 'Telephone',
            'Video' => 'Online',
            'Webinar' => 'Online',
            'SMS Text' => 'Update Only'
        };
        
    // Utility method to convert state abbreviations to full state names
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

        if (stateMap.containsKey(stateAbbreviation)) {
            return stateMap.get(stateAbbreviation);
        } else {
            return stateAbbreviation;  // Return the abbreviation if no match is found
        }
    }

    // Start method to query the records for the given date range
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Full SOQL query to retrieve the relevant records from Session__c
        String query = 'SELECT Case__r.Center_Region_Code__c, ' +
                           'Account__r.EDMIS_Key__c, ' +
                           'Case__r.Contact.FirstName, ' +
                           'Case__r.Contact.LastName, ' +
                           'Case__r.Contact.Email, ' +
                           'Case__r.Contact.Phone, ' +
                           'Case__r.Contact.OtherPhone, ' +
                           'Case__r.Contact.hed__Race__c, ' +
                           'Case__r.Contact.Hispanic__c, ' +
                           'Case__r.Contact.Sex__c, ' +
                           'Case__r.Contact.Disabled__c, ' +
                           'Case__r.Contact.Military__c, ' +
                           'Case__r.Contact.Branch_of_Service__c, ' +
                           'Case__r.CreatedDate, ' +
                           'Case__r.Cumulative_Consulting_Hours__c, ' +
                           'Case__r.DateeRFCCompleted__c, ' +
                           'Case__r.eRFC_Complete__c, ' +
                           'Account__r.Center_Region__r.Key__c, ' +
                           'Account__r.BillingPostalCode, ' +
                           'Account__r.Share_With_SBA__c, ' +
                           'Account__r.Start_Date__c, ' +
                           'Account__r.In_Business__c, ' +
                           'Account__r.Industry, ' +
                           'Account__r.Female_Ownership__c, ' +
                           'Account__r.Online_Presence__c, ' +
                           'Account__r.X8_a_Certified__c, ' +
                           'Account__r.Hub_Zone__c, ' +
                           'Account__r.Exporter__c, ' +
                           'Account__r.Total_employees__c, ' +
                           'Account__r.Export_Employees__c, ' +
                           'Account__r.AnnualRevenue, ' +
                           'Account__r.Annual_PL__c, ' +
                           'Account__r.Export_Sales__c, ' +
                           'Account__r.Ownership, ' +
                           'Account__r.Other_Entity_Type__c, ' +
                           'Account__r.Growth_Client__c, ' +
                           'Account__r.Name, ' +
                           'Account__r.ShippingStreet, ' +
                           'Account__r.ShippingCity, ' +
                           'Account__r.ShippingState, ' +
                           'Account__r.BillingStreet, ' +
                           'Account__r.BillingCity, ' +
                           'Account__r.BillingState, ' +
                           'Account__r.BillingCountry, ' +
                           'Account__r.Export_Countries__c, ' +
                           'Account__r.Center_Region__r.BillingPostalCode, ' +
                           'Impact__r.SBA_Loan_Amount__c, ' +
                           'Impact__r.Loan_Obtained_Amount__c, ' +
                           'Impact__r.Other_Amount__c, ' +
                           'Impact__r.SBA_Loan_Type__c, ' +
                           'Impact__c, ' +
                           'Impact__r.New_Business__c, ' +
                           'Impact__r.CloseDate, ' +
                           'Area_of_Counseling__c, ' +
                           'Delivery_Type__c, ' +
                           'Business_Status_for_Session__c, ' +
                           'Language__c, ' +
                           'Language_Other__c, ' +
            			   'Id, ' +
                           'Session_Number__c, ' +
                           'Session_Type__c, ' +
                           'Session_Date__c, ' +
                           'Primary_Consultant__r.FirstName, ' +
                           'Primary_Consultant__r.LastName, ' +
                           'Primary_Consultant__r.Email, ' +
                           'Primary_Consultant__r.Phone, ' +
                           'Primary_Consultant__r.Name, ' +  // Ensure this line is added
                           'Contact_Hours__c, ' +
                           'Prep_Hours__c, ' +
                           'Travel_Hours__c, ' +
                           'Jobs_Created__c, ' +
                           'Employees_Trained__c, ' +
                           'Total_Training_Hours__c, ' +
                           'Referral_To__c, ' +
                           'Referral_To_Other__c, ' +
                           'Notes__c, ' +
                           'Contact__r.Disabled__c, ' +
                           'Contact__r.Military__c, ' +
                           'Contact__r.Branch_of_Service__c, ' +
                           'Contact__r.How_did_you_hear_about_us__c, ' +
                           'Contact__r.How_did_you_hear_about_us_details__c, ' +
                           'Contact__r.Sex__c, ' +
                           'Contact__r.Hispanic__c, ' +
                           'Contact__r.hed__Race__c, ' +
                           'Contact__r.Race_Prefer_to_Self_Describe__c, ' +
                           'Contact__r.FirstName, ' +
                           'Contact__r.LastName, ' +
                           'Contact__r.Email, ' +
                           'Contact__r.Phone, ' +
                           'Contact__r.OtherPhone, ' +
                           'Contact__r.Referred_by__c, ' +
                           'Contact__r.Referred_by_Other_specify__c, ' +
                           'Contact__r.Sexual_Orientation__c, ' +
                           'Contact__r.Sexual_Orientation_Self_Describe__c, ' +
                           'Event__r.EDMIS_Key__c ' +
                           'FROM Session__c ' +
                           'WHERE Delivery_Type__c != \'\' ' +
                           'AND (Case__r.Cumulative_Consulting_Hours__c > 0 OR Total_Training_Hours__c > 0) ' +
                           'AND Case__c != \'\' ' +
                           'AND Account__c != \'\' ' +
                           'AND Session_Date__c >= :startDate ' +   // Inclusive of the start date
                           'AND Session_Date__c <= :endDate ' +     // Inclusive of the end date
                           'AND Session_type__c IN (\'EDMIS Update\', \'Counseling: Initial\', \'Counseling: Follow On\', \'Event Attendance\') ' +
// Removed 07/28/2025      'AND EDMIS_Overall_Validation__c = TRUE AND Verified__c = FALSE ' +
                           'ORDER BY Session_Sort__c, Session_Date_Time__c, Session_Number__c';

        return Database.getQueryLocator(query);
    }

    // Execute method to map and insert records into SBA_641_Output__c
    public void execute(Database.BatchableContext bc, List<Session__c> scope) {
        processedRecordsCount += scope.size(); // Add count of records in the current batch
        List<SBA_641_Output__c> outputRecords = new List<SBA_641_Output__c>();

        for (Session__c session : scope) {
            SBA_641_Output__c newRecord = new SBA_641_Output__c();
            newRecord.RecordTypeId = varRecordTypeId;
            System.debug('Quarter Year Value: ' + varQuarterYear);
            newRecord.Quarter_Year__c = varQuarterYear;

            // Mapping fields from Session__c to SBA_641_Output__c

            // HEADER:  CounselingRecord
            newRecord.PartnerClientNumber__c = session.Account__r.EDMIS_Key__c;
            newRecord.LocationCode__c = session.Case__r.Center_Region_Code__c;
            newRecord.SessionId__c = session.Id;

            // Start of Section: ClientRequest
            newRecord.LastClientNamePart1__c = session.Contact__r.LastName;
            newRecord.FirstClientNamePart1__c = session.Contact__r.FirstName;
            newRecord.EmailClientRequest__c = session.Contact__r.Email;
            newRecord.PrimaryPhonePart1__c = cleanPhoneNumber(session.Contact__r.Phone);
            newRecord.SecondaryPhonePart1__c = cleanPhoneNumber(session.Contact__r.OtherPhone);
            
            // Sub-Section of ClientRequest: AddressPart1
            newRecord.Street1AddressPart1__c = session.Account__r.BillingStreet;
            newRecord.CityAddressPart1__c = session.Account__r.BillingCity;
            newRecord.StateAddressPart1__c = getStateFullName(session.Account__r.BillingState);
            
            // Normalize and set CountryAddressPart1__c
            if (session.Account__r.BillingCountry != null) {
                String normalizedCountry = 'United states'.equalsIgnoreCase(session.Account__r.BillingCountry) 
                    ? 'United States' 
                    : session.Account__r.BillingCountry;
                newRecord.CountryAddressPart1__c = normalizedCountry;
            } else {
                newRecord.CountryAddressPart1__c = null; // Handle null BillingCountry
            }
            
            // Trim BillingPostalCode to the first 5 characters for ZipCodeAddressPart1__c
            if (session.Account__r.BillingPostalCode != null && session.Account__r.BillingPostalCode.length() >= 5) {
                newRecord.ZipCodeAddressPart1__c = session.Account__r.BillingPostalCode.substring(0, 5);
                    } else {
                newRecord.ZipCodeAddressPart1__c = session.Account__r.BillingPostalCode;  // Use as is if shorter than 5 characters
            }
            
            newRecord.SurveyAgreement__c = session.Account__r.Share_with_SBA__c;
            
            if (session.Case__r.DateeRFCCompleted__c != null) {
                // Use Case__r.DateeRFCCompleted__c if it's not null
                xmlOutput += '<DateClientSignature>' + escapeXml(String.valueOf(session.Case__r.DateeRFCCompleted__c)) + '</DateClientSignature>\n';
            } else {
                // Default to Case__r.CreatedDate if DateeRFCCompleted__c is null
                xmlOutput += '<DateClientSignature>' + escapeXml(String.valueOf(session.Case__r.CreatedDate)) + '</DateClientSignature>\n';
            }

            newRecord.DateClientSignature__c = (session.Case__r != null && session.Case__r.DateeRFCCompleted__c != null)
            ? session.Case__r.DateeRFCCompleted__c.date()
            : (session.Case__r == null || session.Case__r.DateeRFCCompleted__c == null)
                ? startDate
                : null;

            newRecord.OnFileClientSignature__c = session.Case__r.eRFC_Complete__c;
            
            // End of Section: ClientRequest
            
            // Start of Section: ClientIntake
            
// Check and convert Race
if (session.Contact__r.hed__Race__c != null) {
    String raceValue = session.Contact__r.hed__Race__c;

    // Normalize 'Prefer Not to Say' to 'Prefer not to say'
    if (raceValue == 'Prefer Not to Say') {
        raceValue = 'Prefer not to say';
    }

    // Translate 'Arab or Middle Eastern' to 'Middle Eastern'
    if (raceValue == 'Arab or Middle Eastern') {
        raceValue = 'Middle Eastern';
    }

    // Translate 'Other' to 'Prefer not to say'
    if (raceValue == 'Other') {
        raceValue = 'Prefer not to say';
    }

    // Translate 'American Indian or Alaska Native' to 'Native American/Alaska Native'
    if (raceValue == 'American Indian or Alaska Native') {
        raceValue = 'Native American/Alaska Native';
    }

    // Truncate the value to 80 characters if necessary
    newRecord.RaceClientIntake__c = raceValue.length() > 80 
        ? raceValue.substring(0, 80) 
        : raceValue;
}



// Check if RaceClientIntake__c requires a SelfDescribedRace value
if (newRecord.RaceClientIntake__c == 'Prefer to Self-Describe') {
    // Check if SelfDescribedRaceClientIntake__c is blank or null
    if (String.isBlank(newRecord.SelfDescribedRaceClientIntake__c)) {
        // Set the value to 'Prefer not to say'
        newRecord.SelfDescribedRaceClientIntake__c = 'Prefer not to say';
    } else {
        // If a value exists, trim it to the first 80 characters if necessary
        String raceValue = newRecord.SelfDescribedRaceClientIntake__c;
        if (raceValue.length() > 80) {
            newRecord.SelfDescribedRaceClientIntake__c = raceValue.substring(0, 80);
        }
    }
} else {
    // If RaceClientIntake__c is not 'Prefer to Self-Describe', clear the SelfDescribedRace field
    newRecord.SelfDescribedRaceClientIntake__c = null;
}


            // Ethnicity translation logic
            String originalValue = session.Case__r != null ? session.Case__r.Contact.Hispanic__c : null;
            if (originalValue != null) {
                String translatedValue = translateEthnicity(originalValue);
                newRecord.EthnicityClientIntake__c = translatedValue;
            } else {
                newRecord.EthnicityClientIntake__c = 'Prefer not to say';
            }

            //newRecord.EthnicityClientIntake__c = session.Contact__r.Hispanic__c;
            
// Translation for SexualOrientation_ClientIntake__c
if (session.Contact__r.Sexual_Orientation__c == 'Non LGBTQ') {
    newRecord.SexualOrientationClientIntake__c = 'Not LGBTQ';
} else {
    newRecord.SexualOrientationClientIntake__c = session.Contact__r.Sexual_Orientation__c;
}

// Set SelfDescribedSexualOrientation__c
newRecord.SelfDescribedSexualOrientation__c = session.Contact__r.Sexual_Orientation_Self_Describe__c;

// Check if SexualOrientationClientIntake__c = 'Prefer to Self-Describe'
if ('Prefer to Self-Describe'.equalsIgnoreCase(newRecord.SexualOrientationClientIntake__c)) {
    // Default SelfDescribedSexualOrientation__c to 'Prefer not to say' if blank/null
    if (String.isBlank(newRecord.SelfDescribedSexualOrientation__c)) {
        newRecord.SelfDescribedSexualOrientation__c = 'Prefer not to say';
    }
}


            // Mapping SexClientIntake__c
            newRecord.SexClientIntake__c = session.Contact__r.Sex__c;
            
            // Translation for Disability_ClientIntake__c
            if (session.Contact__r.Disabled__c == 'No Reply') {
                newRecord.DisabilityClientIntake__c = 'Prefer not to say';
                } else {
                // Keep 'Yes', 'No', and 'Prefer not to say' as is
                newRecord.DisabilityClientIntake__c = session.Contact__r.Disabled__c;
            }
            
            // Map Contact__r.Military__c to MilitaryStatusClientIntake__c with specific translations
            if (session.Contact__r.Military__c != null) {
                if (session.Contact__r.Military__c == 'Member of Reserve') {
                    newRecord.MilitaryStatusClientIntake__c = 'Member of the Reserve';
                } else if (session.Contact__r.Military__c == 'None') {
                    newRecord.MilitaryStatusClientIntake__c = 'No military service';
                } else if (session.Contact__r.Military__c == 'Member of the National Guard') {
                    newRecord.MilitaryStatusClientIntake__c = 'Member of National Guard';
                } else if (session.Contact__r.Military__c == 'Unknown/Not Stated') {
                    newRecord.MilitaryStatusClientIntake__c = 'No military service';
                } else {
            // For allowed values in the picklist, map directly
                    newRecord.MilitaryStatusClientIntake__c = session.Contact__r.Military__c;
                }
            }
            
// Explicitly define handling for each MilitaryStatus_ClientIntake__c value
if (session.Contact__r.Military__c == 'Active Duty') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'Member of National Guard') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'Member of the Reserve') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'Service Disabled Veteran') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'Spouse of Military Member') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'Veteran') {
    if (String.isBlank(session.Contact__r.Branch_of_Service__c)) {
        newRecord.BranchOfService_ClientIntake__c = 'Prefer not to say';
    } else {
        newRecord.BranchOfService_ClientIntake__c = session.Contact__r.Branch_of_Service__c;
    }
} else if (session.Contact__r.Military__c == 'No military service') {
    newRecord.BranchOfService_ClientIntake__c = null; // Clear field for "No military service"
} else if (session.Contact__r.Military__c == 'Prefer not to say') {
    newRecord.BranchOfService_ClientIntake__c = null; // Clear field for "Prefer not to say"
}

// No fallback logic for undefined or unexpected statuses




            // Sub-Section of ClientIntake: Media

// Get the values from Contact__r
String hearAboutUsValue = session.Contact__r.How_did_you_hear_about_us__c;
String hearAboutUsDetails = session.Contact__r.How_did_you_hear_about_us_details__c;

// Translation for Media_ClientIntake__c
String mediaSource = session.Contact__r.How_did_you_hear_about_us__c;
if ('EDC'.equalsIgnoreCase(mediaSource)) {
    newRecord.Media_ClientIntake__c = 'Other Client';
} else if ('I was referred by someone'.equalsIgnoreCase(mediaSource)) {
    newRecord.Media_ClientIntake__c = 'Word of Mouth';
} else {
    newRecord.Media_ClientIntake__c = mediaSource;
}

// Validate Media_ClientIntake__c against accepted values or default to 'Other'
if (acceptedMediaValues.contains(newRecord.Media_ClientIntake__c)) {
    // If valid, keep the value and clear Other_Media_ClientIntake__c
    newRecord.Other_Media_ClientIntake__c = null;
} else {
    // If not in the list, set Media_ClientIntake__c to "Other"
    newRecord.Media_ClientIntake__c = 'Other';

    // Populate Other_Media_ClientIntake__c with details
    newRecord.Other_Media_ClientIntake__c = hearAboutUsValue;
    if (!String.isBlank(hearAboutUsDetails)) {
        newRecord.Other_Media_ClientIntake__c += ' - ' + hearAboutUsDetails;
    }

    // Trim Other_Media_ClientIntake__c to 80 characters if necessary
    if (!String.isBlank(newRecord.Other_Media_ClientIntake__c) && newRecord.Other_Media_ClientIntake__c.length() > 80) {
        newRecord.Other_Media_ClientIntake__c = newRecord.Other_Media_ClientIntake__c.substring(0, 80);
    }
}

// Handle Internet_Media_ClientIntake__c when Media_ClientIntake__c = 'Internet'
if ('Internet'.equalsIgnoreCase(newRecord.Media_ClientIntake__c)) {
    if (!String.isBlank(newRecord.Other_Media_ClientIntake__c)) {
        // Set Internet_Media_ClientIntake__c to the value of Other_Media_ClientIntake__c
        newRecord.Internet_Media_ClientIntake__c = newRecord.Other_Media_ClientIntake__c.trim();
    } else {
        // Default to 'Undetermined' if Other_Media_ClientIntake__c is blank or null
        newRecord.Internet_Media_ClientIntake__c = 'Undetermined';
    }
}

            
            // Check Business_Status_for_Session__c and set CurrentlyInBusiness_ClientIntake__c
            if (notInBusinessStatuses.contains(session.Business_Status_for_Session__c)) {
                newRecord.CurrentlyInBusiness_ClientIntake__c = 'No';
            } else if (session.Business_Status_for_Session__c == 'In Business') {
                newRecord.CurrentlyInBusiness_ClientIntake__c = 'Yes';
            } else if (session.Account__r.In_Business__c != null) {
                // Use Account__r.In_Business__c if Business_Status_for_Session__c is blank or null
                newRecord.CurrentlyInBusiness_ClientIntake__c = session.Account__r.In_Business__c ? 'Yes' : 'No';
            } else {
                // Default to 'No' if neither field has a value
                newRecord.CurrentlyInBusiness_ClientIntake__c = 'No';
            }

            
            // Truncate Account Name to 80 characters for CompanyName_ClientIntake__c
            String accountName = session.Account__r.Name;
            if (accountName != null && accountName.length() > 80) {
                newRecord.CompanyName_ClientIntake__c = accountName.substring(0, 80);
                } else {
                newRecord.CompanyName_ClientIntake__c = accountName;
            }
            
            // Define the mapping for Account__r.Industry to BusinessType_ClientIntake__c
            Map<String, String> industryMapping = new Map<String, String>{
                '11 Agriculture, Forestry Fishing and Hunting' => 'Agriculture, Forestry, Fishing and Hunting',
                '11 Agriculture, Forestry, Fishing and Hunting' => 'Agriculture, Forestry, Fishing and Hunting',
                '72 Accommodation and Food Services' => 'Accommodation and Food Services',
                '56 Administrative and Support' => 'Administrative and Support',
                '71 Arts, Entertainment, and Recreation' => 'Arts, Entertainment, and Recreation',
                '71 Arts, Entertainment and Recreation' => 'Arts, Entertainment, and Recreation',    
                '23 Construction' => 'Construction',
                '61 Educational Services' => 'Educational Services',
                '52 Finance and Insurance' => 'Finance and Insurance',
                '62 Health Care and Social Assistance' => 'Health Care and Social Assistance',
                '51 Information' => 'Information',
                '55 Management of Companies and Enterprises' => 'Management of Companies and Enterprises',
                '31 Manufacturing' => 'Manufacturing',
                'Advanced Manufacturing' => 'Manufacturing',
                '21 Mining' => 'Mining',
                '54 Professional, Scientific, Technical Services' => 'Professional, Scientific, and Technical Services',
                '92 Public Administration' => 'Public Administration',
                '53 Real Estate Rental and Leasing' => 'Real Estate and Rental and Leasing',
                '53 Real Estate and Rental and Leasing' => 'Real Estate and Rental and Leasing',
                '44 Retail Trade' => 'Retail Trade',
                '48 Transportation and Warehousing' => 'Transportation and Warehousing',
                '22 Utilities' => 'Utilities',
                '42 Wholesale Trade' => 'Wholesale Trade',
                '81 Other Services (Except Public Administration)' => 'Other Services (except Public Administration)',
                'Waste Management &amp Remediation Services' => 'Waste Management and Remediation Services',
                'Waste Management & Remediation Services' => 'Waste Management and Remediation Services',
                'Not Set' => 'Other Services (except Public Administration)'
            };

// Check if the Account__r.Industry has a matching translation in the map
if (industryMapping.containsKey(session.Account__r.Industry)) {
    newRecord.BusinessType_ClientIntake__c = industryMapping.get(session.Account__r.Industry);
} else {
    // Normalize raw value before assigning to restricted picklist
    String rawIndustry = session.Account__r.Industry;
    if (String.isNotBlank(rawIndustry)) {
        rawIndustry = rawIndustry.replace('&amp;', '&').replace('&amp', '&');
        rawIndustry = rawIndustry.replace('Waste Management & Remediation Services', 
                                          'Waste Management and Remediation Services');
        rawIndustry = rawIndustry.replace('Waste Management &amp; Remediation Services',
                                          'Waste Management and Remediation Services');
    }
    newRecord.BusinessType_ClientIntake__c = rawIndustry;
}

// Check if BusinessType_ClientIntake__c is blank/null and CurrentlyInBusiness_ClientIntake__c = 'Yes'
if (String.isBlank(newRecord.BusinessType_ClientIntake__c) 
    && 'Yes'.equalsIgnoreCase(newRecord.CurrentlyInBusiness_ClientIntake__c)) {
    newRecord.BusinessType_ClientIntake__c = 'Other Services (except Public Administration)';
}


            // Assuming `record` is the object with `Female_Ownership__c` field and `newRecord` is the output object with `BusinessOwnership_Female__c` field
            newRecord.BusinessOwnership_Female__c = (session.Account__r.Female_Ownership__c == null) ? 0 : session.Account__r.Female_Ownership__c;
            
            // Translate boolean to "Yes"/"No" for ConductingBusinessOnline_ClientIntake__c
            if (session.Account__r.Online_Presence__c == true) {
                newRecord.ConductingBusinessOnline_ClientIntake__c = 'Yes';
            } else if (session.Account__r.Online_Presence__c == false) {
                newRecord.ConductingBusinessOnline_ClientIntake__c = 'No';
            }

            //newRecord.Certified8a_ClientIntake__c = String.valueOf(session.Account__r.X8_a_Certified__c); // Replaced with translation below
            // Translate boolean to "Yes"/"No" for Certified8a_ClientIntake__c
            if (session.Account__r.X8_a_Certified__c == true) {
                newRecord.Certified8a_ClientIntake__c = 'Yes';
            } else if (session.Account__r.X8_a_Certified__c == false) {
                newRecord.Certified8a_ClientIntake__c = 'No';
            }

            // Set TotalNumberofEmployees_ClientIntake__c and NumberOfEmployeesInExportingBusiness__c
            newRecord.TotalNumberofEmployees_ClientIntake__c = session.Account__r.Total_employees__c;
            newRecord.NumberOfEmployeesInExportingBusiness__c = session.Account__r.Export_Employees__c;

            // Check if NumberOfEmployeesInExportingBusiness__c is greater than TotalNumberofEmployees_ClientIntake__c
            if (newRecord.NumberOfEmployeesInExportingBusiness__c != null 
                && newRecord.TotalNumberofEmployees_ClientIntake__c != null
                && newRecord.NumberOfEmployeesInExportingBusiness__c > newRecord.TotalNumberofEmployees_ClientIntake__c) {
                newRecord.TotalNumberofEmployees_ClientIntake__c = newRecord.NumberOfEmployeesInExportingBusiness__c + 1;
            }
            
            // Sub-Section of ClientIntake: ClientAnnualIncomePart2
            newRecord.GrossRevenues_ClientAnnualIncomePart2__c = session.Account__r.AnnualRevenue;
            newRecord.ProfitLoss_ClientAnnualIncomePart2__c = session.Account__r.Annual_PL__c;
            newRecord.ExportGrossRevenuesOrSales__c = session.Account__r.Export_Sales__c;
            
            // Mapping LegalEntity_ClientIntake__c with allowed values check
            String ownershipValue = session.Account__r.Ownership;
            if (allowedLegalEntities.contains(ownershipValue)) {
                newRecord.LegalEntity_ClientIntake__c = ownershipValue;
            } else {
                newRecord.LegalEntity_ClientIntake__c = 'Other';  // Set to 'Other' if not in allowed values
            }
            
            // Check if LegalEntity_ClientIntake__c is 'Other'
            if (newRecord.LegalEntity_ClientIntake__c == 'Other') {
                // Check if LegalEntity_Other_ClientIntake__c is blank or null
                if (String.isBlank(session.Account__r.Other_Entity_Type__c)) {
                    // Set default value to 'Undetermined' if no value is provided
                    newRecord.LegalEntity_Other_ClientIntake__c = 'Undetermined';
                } else {
                // Set the value for LegalEntity_Other_ClientIntake__c with truncation to 80 characters if necessary
                    newRecord.LegalEntity_Other_ClientIntake__c = session.Account__r.Other_Entity_Type__c.length() > 80
                    ? session.Account__r.Other_Entity_Type__c.substring(0, 80)
                    : session.Account__r.Other_Entity_Type__c;
                }
            }
            
            // Assign value to Rural_vs_Urban
            newRecord.Rural_vs_Urban_ClientIntake__c = 'Undetermined';
            //FIPS_Code placeholder...

            // Apply mapping for Area_of_Counseling__r
            String areaOfCounseling = session.Area_of_Counseling__c;
            if (counselingMapping.containsKey(areaOfCounseling)) {
                newRecord.CounselingSeeking_ClientIntake__c = counselingMapping.get(areaOfCounseling);
            } else {
                // Set default or handle if Area_of_Counseling__r is not in the map
                newRecord.CounselingSeeking_ClientIntake__c = 'Other';
            }            

            // Check if CounselingSeeking_ClientIntake__c is 'Other'
            if (newRecord.CounselingSeeking_ClientIntake__c == 'Other') {
                newRecord.CounselingSeekingOther_ClientIntake__c = 'Undetermined';
            } else {
                newRecord.CounselingSeekingOther_ClientIntake__c = null; // Clear the field if not 'Other'
            }
            
// Translate and set ExportCountries_ClientIntake__c
String exportCountries = session.Account__r.Export_Countries__c;

// Check if ExportCountries is not blank and process the values
if (String.isNotBlank(exportCountries)) {
    List<String> countries = exportCountries.split(';');
    for (Integer i = 0; i < countries.size(); i++) {
        if ('Hong Kong'.equalsIgnoreCase(countries[i].trim())) {
            // Translate 'Hong Kong' to 'China'
            countries[i] = 'China';
        }
    }
    // Convert the list of countries to camel case
    newRecord.ExportCountries_ClientIntake__c = toCamelCaseCountries(String.join(countries, '; '));
} else {
    // Retain original value if blank/null
    newRecord.ExportCountries_ClientIntake__c = exportCountries;
}

            
            // End of Section: ClientIntake
          
            // Start of Section:  CounselorRecord
            //newRecord.PartnerSessionNumber_Counselor__c = String.valueOf(session.Id);
            newRecord.PartnerSessionNumber_Counselor__c = session.Id;
            
            //FundingSource (placeholder)
            newRecord.DateCounseled_CounselorRecord__c = session.Session_Date__c;
            newRecord.LastClientNamePart3__c = session.Contact__r.LastName;
            newRecord.FirstClientNamePart3__c = session.Contact__r.FirstName;
            newRecord.Email_CounselorRecord__c = session.Contact__R.Email;
            newRecord.Primary_PhonePart3__c = cleanPhoneNumber(session.Contact__r.Phone);
            newRecord.Secondary_PhonePart3__c = cleanPhoneNumber(session.Contact__r.OtherPhone);
            
            // Sub-Section of CounselorRecord: AddressPart3
            newRecord.Street1_AddressPart3__c = session.Account__r.BillingStreet;
            newRecord.City_AddressPart3__c = session.Account__r.BillingCity;
            newRecord.State_AddressPart3__c = getStateFullName(session.Account__r.BillingState);
            
            // Normalize and set Country_AddressPart3__c
            if (session.Account__r.BillingCountry != null) {
                String normalizedCountry = 'United states'.equalsIgnoreCase(session.Account__r.BillingCountry) 
                    ? 'United States' 
                    : session.Account__r.BillingCountry;
                newRecord.Country_AddressPart3__c = normalizedCountry;
            } else {
                newRecord.Country_AddressPart3__c = null; // Handle null BillingCountry
            }
            
            //Postal Code (placeholder - part 3)
            //State or Province (placeholder - part 3)                

            // Trim BillingPostalCode to the first 5 characters for ZipCodeAddressPart3__c
            if (session.Account__r.BillingPostalCode != null && session.Account__r.BillingPostalCode.length() >= 5) {
                newRecord.ZipCode_AddressPart3__c = session.Account__r.BillingPostalCode.substring(0, 5);
                    } else {
                newRecord.ZipCode_AddressPart3__c = session.Account__r.BillingPostalCode;  // Use as is if shorter than 5 characters
            }
            
// Check Business_Status_for_Session__c and set VerifiedToBeInBusiness_CounselorRecord__c
if (notInBusinessStatuses.contains(session.Business_Status_for_Session__c)) {
    newRecord.VerifiedToBeInBusiness_CounselorRecord__c = 'No';
} else if (session.Business_Status_for_Session__c == 'In Business') {
    newRecord.VerifiedToBeInBusiness_CounselorRecord__c = 'Yes';
} else if (session.Account__r.In_Business__c != null) {
    // Use Account__r.In_Business__c if Business_Status_for_Session__c is blank or null
    newRecord.VerifiedToBeInBusiness_CounselorRecord__c = session.Account__r.In_Business__c ? 'Yes' : 'No';
} else {
    // Default to 'No' if neither field has a value
    newRecord.VerifiedToBeInBusiness_CounselorRecord__c = 'No';
}

// Ensure VerifiedToBeInBusiness_CounselorRecord__c is set to "Yes" if ReportableImpact__c = "Yes"
if ('Yes'.equalsIgnoreCase(newRecord.ReportableImpact__c) &&
    (String.isBlank(newRecord.VerifiedToBeInBusiness_CounselorRecord__c) || 
     'No'.equalsIgnoreCase(newRecord.VerifiedToBeInBusiness_CounselorRecord__c))) {
    newRecord.VerifiedToBeInBusiness_CounselorRecord__c = 'Yes';
}


// Safely get the value of Impact__r.New_Business__c and conditionally set ReportableImpact__c
if (session.Impact__r != null && session.Impact__r.New_Business__c == true) {
    // Set Reportable Impact to 'Yes' if Impact__r.New_Business__c is true
    newRecord.ReportableImpact__c = 'Yes';
    // Set Date of Reportable Impact to Impact__r.CloseDate
    newRecord.DateofReportableImpact__c = session.Impact__r.CloseDate;
} else {
    // Otherwise, set Reportable Impact to 'No' and clear the Date of Reportable Impact
    newRecord.ReportableImpact__c = 'No';
    newRecord.DateofReportableImpact__c = null;
}

            newRecord.CurrentlyExporting_CounselorRecord_Part3__c = session.Account__r.Exporter__c;
            
            //newRecord.BusinessStartDatePart3__c = session.Account__r.Start_Date__c;
            // Check if CurrentlyInBusiness_ClientIntake__c is 'Yes'
            if (newRecord.CurrentlyInBusiness_ClientIntake__c == 'Yes') {
                // Set BusinessStartDatePart3__c to Account__r.Start_Date__c if it exists
                if (session.Account__r.Start_Date__c != null) {
                    newRecord.BusinessStartDatePart3__c = session.Account__r.Start_Date__c;
                } 
                // If Account__r.Start_Date__c is null, check Business_Status_for_Session__c for a value
                else if (!String.isBlank(session.Business_Status_for_Session__c) && session.Business_Status_for_Session__c.contains('In Business')) {
                    // Use a default fallback date, like today or another meaningful date
                    newRecord.BusinessStartDatePart3__c = Date.today(); // Replace Date.today() if a specific fallback is needed
                } 
                // If neither has a valid value, set the field to null
                else {
                    newRecord.BusinessStartDatePart3__c = null;
                }
            } else {
                // If CurrentlyInBusiness_ClientIntake__c is not 'Yes', ensure BusinessStartDatePart3__c is null
                newRecord.BusinessStartDatePart3__c = null;
            }

            // Assign initial values from the session
            newRecord.TotalNumberOfEmployees_CounselorRecord__c = session.Account__r.Total_employees__c;
            newRecord.NumberOfEmployeesExportingBusiness_Part3__c = session.Account__r.Export_Employees__c;
            // Check and update TotalNumberOfEmployees_CounselorRecord__c if necessary
            if (newRecord.NumberOfEmployeesExportingBusiness_Part3__c != null &&
                newRecord.TotalNumberOfEmployees_CounselorRecord__c != null &&
                newRecord.NumberOfEmployeesExportingBusiness_Part3__c > newRecord.TotalNumberOfEmployees_CounselorRecord__c) 
            {
                newRecord.TotalNumberOfEmployees_CounselorRecord__c = newRecord.NumberOfEmployeesExportingBusiness_Part3__c + 1;
            }
            
            // Sub-section of CounselorRecord: ClientAnnualIncomePart3
            newRecord.GrossRevenues_ClientAnnualIncomePart3__c = session.Account__r.AnnualRevenue;
            newRecord.ProfitLoss_ClientAnnualIncomePart3__c = session.Account__r.Annual_PL__c;
            newRecord.ExportGrossRevenuesOrSales_Part3__c = session.Account__r.Export_Sales__c;
            // Translate boolean to "Yes"/"No" for GrowthIndicator_ClientAnnualIncomePart3__c
            if (session.Account__r.Growth_Client__c == true) {
                newRecord.GrowthIndicator_ClientAnnualIncomePart3__c = 'Yes';
            } else if (session.Account__r.Growth_Client__c == false) {
                newRecord.GrowthIndicator_ClientAnnualIncomePart3__c = 'No';
            }
            
            // Sub-section of CounselorRecord: ResourcePartnerServiceContributed
            newRecord.SBALoanAmount_CounselorRecord__c = session.Impact__r.SBA_Loan_Amount__c;
            newRecord.NonSBALoanAmount_CounselorRecord__c = session.Impact__r.Loan_Obtained_Amount__c;
            newRecord.EquityCapitalReceived_CounselorRecord__c = session.Impact__r.Other_Amount__c;
            //SBA Loan Amount Txn Number - Check the value of SBALoanAmount_CounselorRecord__c
            if (newRecord.SBALoanAmount_CounselorRecord__c != null && newRecord.SBALoanAmount_CounselorRecord__c > 0) {
                // If SBALoanAmount_CounselorRecord__c > 0, set SBALoanAmountTxnNmbCounselorRecord__c to 1
                newRecord.SBALoanAmountTxnNmbCounselorRecord__c = 1;
            } else {
                // Otherwise, set SBALoanAmountTxnNmbCounselorRecord__c to 0
                newRecord.SBALoanAmountTxnNmbCounselorRecord__c = 0;
            }

            //Non-SBA Loan Amount Txn Number - Check the value of NonSBALoanAmount_CounselorRecord__c
            if (newRecord.NonSBALoanAmount_CounselorRecord__c != null && newRecord.NonSBALoanAmount_CounselorRecord__c > 0) {
                // If NonSBALoanAmount_CounselorRecord__c > 0, set NonSBALoanAmountTxnNmbCounselorRecord__c to 1
                newRecord.NonSBALoanAmountTxnNmbCounselorRecord__c = 1;
            } else {
                // Otherwise, set NonSBALoanAmountTxnNmbCounselorRecord__c to 0
                newRecord.NonSBALoanAmountTxnNmbCounselorRecord__c = 0;
            }

            //Equity Capital Received Txn Number // Check the value of EquityCapitalReceived_CounselorRecord__c
            if (newRecord.EquityCapitalReceived_CounselorRecord__c != null && newRecord.EquityCapitalReceived_CounselorRecord__c > 0) {
                // If EquityCapitalReceived_CounselorRecord__c > 0, set EquityCapitalReceivedTxnNmbCounselorRec__c to 1
                newRecord.EquityCapitalReceivedTxnNmbCounselorRec__c = 1;
            } else {
                // Otherwise, set EquityCapitalReceivedTxnNmbCounselorRec__c to 0
                newRecord.EquityCapitalReceivedTxnNmbCounselorRec__c = 0;
            }

            //Number of Contracts Received (placeholder)
            
            // Set Certifications_CounselorRecord__c based on Hub_Zone__c and X8_a_Certified__c
            if (session.Account__r.Hub_Zone__c == true) {
                newRecord.Certifications_CounselorRecord__c = 'Hubzones';
                } 
            if (session.Account__r.X8_a_Certified__c == true) {
            // If Hub_Zone__c was also true, combine values if multiple values are allowed
            if (newRecord.Certifications_CounselorRecord__c != null && newRecord.Certifications_CounselorRecord__c != 'Hubzones') {
                newRecord.Certifications_CounselorRecord__c += '; 8(a)';  // Adjust as needed for your format
                } else {
                newRecord.Certifications_CounselorRecord__c = '8(a)';
                }
            }
            
            //SBA Financial Assistance (placeholder)
            //newRecord.CounselingProvided_CounselorRecord__c = session.Area_of_Counseling__c;  // Replace with translation below
            //newRecord.CounselingSeeking_ClientIntake__c = session.Area_of_Counseling__c;  // Replacing with translation values below
            // Apply mapping for Area_of_Counseling__r
            String areaOfCounseling2 = session.Area_of_Counseling__c;
            if (counselingMapping.containsKey(areaOfCounseling2)) {
                newRecord.CounselingProvided_CounselorRecord__c = counselingMapping.get(areaOfCounseling2);
            } else {
                // Set default or handle if Area_of_Counseling__r is not in the map
                newRecord.CounselingProvided_CounselorRecord__c = 'Other';
            }
            
            // Determine the CounselingProvided_CounselorRecord__c value
            if (counselingMapping.containsKey(session.Area_of_Counseling__c)) {
                newRecord.CounselingProvided_CounselorRecord__c = counselingMapping.get(session.Area_of_Counseling__c);
            } else {
                newRecord.CounselingProvided_CounselorRecord__c = 'Other';
            }

            // Check if CounselingProvided_CounselorRecord__c is 'Other' and set CounselingProvidedOther_CounselorRecord__c accordingly
            if (newRecord.CounselingProvided_CounselorRecord__c == 'Other') {
                if (String.isBlank(newRecord.CounselingProvidedOtherCounselorRecord__c)) {
                    newRecord.CounselingProvidedOtherCounselorRecord__c = 'Undetermined';
                }
            }
            
//Check & translate Referred Client & Referred Client
newRecord.ReferredClient_CounselorRecord__c = session.Referral_To__c;
newRecord.ReferredClientOther_CounselorRecord__c = session.Referral_To_Other__c;

// Check if ReferredClientOther_CounselorRecord__c has a value and ReferredClient_CounselorRecord__c is blank/null
if (!String.isBlank(newRecord.ReferredClientOther_CounselorRecord__c) 
    && String.isBlank(newRecord.ReferredClient_CounselorRecord__c)) {
    newRecord.ReferredClient_CounselorRecord__c = 'Other';
}

            
            newRecord.SessionType_CounselorRecord__c = session.Delivery_Type__c;
            // Use the map to set the SessionType_CounselorRecord__c value based on Delivery_Type__c
            if (deliveryTypeMap.containsKey(session.Delivery_Type__c)) {
                newRecord.SessionType_CounselorRecord__c = deliveryTypeMap.get(session.Delivery_Type__c);
            } else {
                newRecord.SessionType_CounselorRecord__c = 'Other';  // Handle unexpected values
            }
            
            newRecord.Language_CounselorRecord__c = session.Language__c;
            newRecord.LanguageOther_CounselorRecord__c = session.Language_Other__c;
            newRecord.DateCounseled_CounselorRecord__c = session.Session_Date__c;
            newRecord.CounselorName_CounselorRecord__c = session.Primary_Consultant__r.Name;
            newRecord.CounselingHours_Contact__c = session.Contact_Hours__c;
            newRecord.CounselingHours_Prepare__c = session.Prep_Hours__c;
            newRecord.CounselingHours_Travel__c = session.Travel_Hours__c;

// Translate and set ExportCountries_CounselorRecord__c
String exportCountries2 = session.Account__r.Export_Countries__c;

// Check if ExportCountries is not blank and process the values
if (String.isNotBlank(exportCountries2)) {
    List<String> countries = exportCountries2.split(';');
    for (Integer i = 0; i < countries.size(); i++) {
        if ('Hong Kong'.equalsIgnoreCase(countries[i].trim())) {
            // Translate 'Hong Kong' to 'China'
            countries[i] = 'China';
        }
    }
    // Convert the list of countries to camel case
    newRecord.ExportCountries_CounselorRecord__c = toCamelCaseCountries(String.join(countries, '; '));
} else {
    // Retain original value if blank/null
    newRecord.ExportCountries_CounselorRecord__c = exportCountries2;
}


            // Truncate Notes__c to 1,000 characters if it exceeds that length
            newRecord.CounselorNotes_CounselorRecord__c = session.Notes__c != null && session.Notes__c.length() > 1000 
            ? session.Notes__c.substring(0, 1000) 
            : session.Notes__c;
            
            // Sub-section of CounselorRecord: TrainingSession
            newRecord.DateTrainingStarted_CounselorRecord__c = session.Session_Date__c;
            newRecord.PartnerTrainingNumber_CounselorRecord__c = session.Event__r.EDMIS_Key__c;
            newRecord.EmployeesTrained_CounselorRecord__c = session.Employees_Trained__c;
            newRecord.HoursTrained_CounselorRecord__c = session.Total_Training_Hours__c;

            // End of Section: ClientIntake

            // Additional mappings from other related fields...

            // Insert the new SBA_641_Output__c record
            outputRecords.add(newRecord);
        }

        if (!outputRecords.isEmpty()) {
            insert outputRecords;
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Fetch the email of the user who ran the batch job
        String jobOwnerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;

        // Create and send an email with the number of records processed
        if (!String.isBlank(jobOwnerEmail)) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { jobOwnerEmail });
            email.setSubject('SBA641 Batch Job Completion');
            email.setPlainTextBody('The SBA641 Batch job has completed successfully. ' +
                                   'Total number of records processed: ' + processedRecordsCount + '.');

            // Send the email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Email sent to job owner: ' + jobOwnerEmail + ' with processed record count: ' + processedRecordsCount);
        }
    }
}