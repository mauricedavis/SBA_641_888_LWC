public with sharing class SBA888Batch implements Database.Batchable<SObject> {

    private Date startDate;
    private Date endDate;
    private String varRecordTypeId;  // Store the varRecordTypeId
    private String varQuarterYear;   // Store the Quarter_Year value

    // 1. Create a static map of state abbreviations to full names
    private static final Map<String, String> STATE_ABBREVIATION_MAP = new Map<String, String>{
        'AL' => 'Alabama', 
        'AK' => 'Alaska', 
        'AZ' => 'Arizona', 
        'AR' => 'Arkansas', 
        'CA' => 'California', 
        'CO' => 'Colorado', 
        'CT' => 'Connecticut', 
        'DE' => 'Delaware', 
        'DC' => 'District of Columbia', 
        'FL' => 'Florida', 
        'GA' => 'Georgia', 
        'HI' => 'Hawaii', 
        'ID' => 'Idaho', 
        'IL' => 'Illinois', 
        'IN' => 'Indiana', 
        'IA' => 'Iowa', 
        'KS' => 'Kansas', 
        'KY' => 'Kentucky', 
        'LA' => 'Louisiana', 
        'ME' => 'Maine', 
        'MD' => 'Maryland', 
        'MA' => 'Massachusetts', 
        'MI' => 'Michigan', 
        'MN' => 'Minnesota', 
        'MS' => 'Mississippi', 
        'MO' => 'Missouri', 
        'MT' => 'Montana', 
        'NE' => 'Nebraska', 
        'NV' => 'Nevada', 
        'NH' => 'New Hampshire', 
        'NJ' => 'New Jersey', 
        'NM' => 'New Mexico', 
        'NY' => 'New York', 
        'NC' => 'North Carolina', 
        'ND' => 'North Dakota', 
        'OH' => 'Ohio', 
        'OK' => 'Oklahoma', 
        'OR' => 'Oregon', 
        'PA' => 'Pennsylvania', 
        'RI' => 'Rhode Island', 
        'SC' => 'South Carolina', 
        'SD' => 'South Dakota', 
        'TN' => 'Tennessee', 
        'TX' => 'Texas', 
        'UT' => 'Utah', 
        'VT' => 'Vermont', 
        'VA' => 'Virginia', 
        'WA' => 'Washington', 
        'WV' => 'West Virginia', 
        'WI' => 'Wisconsin', 
        'WY' => 'Wyoming'
    };

    // Constructor to accept date range parameters
    public SBA888Batch(Date startDate, Date endDate, String varRecordTypeId, String varQuarterYear) {
        this.startDate = startDate;
        this.endDate = endDate;
        this.varRecordTypeId = varRecordTypeId;  // Assign the passed varRecordTypeId value
        this.varQuarterYear = varQuarterYear;    // Assign the passed varQuarterYear value
    }

    // Start method to query the records
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, ' +
                       'conference360__Status__c, ' +
                       'EDMIS_Key__c, ' +
                       'EDMIS_Location_Id__c, ' +
                       'conference360__Venue__r.BillingCity, ' +
                       'conference360__Venue__r.BillingState, ' +
                       'conference360__Venue__r.BillingPostalCode, ' +
                       'conference360__Venue__r.BillingCountry, ' +
                       'conference360__Event_Start_Date__c, ' +
                       'conference360__Total_Ticket_Revenue__c, ' +
                       'Sessions__c, ' +
                       'Total_Hours__c, ' +
                       'Total_Trained__c, ' +
                       'Name, ' +
                       'Total_Attended_Business_Owner__c, ' +
                       'Total_Attended_Not_Yet_In_Business__c, ' +
                       'Total_Attended_Disabled__c, ' +
                       'Total_Attended_Woman__c, ' +
                       'Total_Attended_Active_Duty__c, ' +
                       'Total_Attended_Veterans__c, ' +
                       'Total_Attended_Disabled_Veterans__c, ' +
                       'Total_Attended_Reserve_Natl_Guard__c, ' +
                       'Total_Attended_Spouse_Of_Military_Membr__c, ' +
                       'Total_Attended_Minority__c, ' +
                       'Total_Attended_Asian__c, ' +
                       'Total_Attended_Black__c, ' +
                       'Total_Attended_Native_American__c, ' +
                       'Total_Attended_Pacific__c, ' +
                       'Total_Attended_White__c, ' +
                       'Total_Attended_Middle_Eastern__c, ' +
                       'Total_Attended_North_African__c, ' +
                       'Total_Attended_Hispanic__c, ' +
                       'Total_Attended_Not_Hispanic__c, ' +
                       'Total_Attended_LGBTQ__c, ' +
                       'Topic__c, ' +
                       'Program_Format__c, ' +
                       'Language__c, ' +
                       'Chamber_of_Commerce__c, ' +
                       'Education_Institution_checkbox__c, ' +
                       'For_Profit_Organization__c, ' +
                       'Native_American_Center__c, ' +
                       'Online_Training_Resource__c, ' +
                       'SBA_District_Office__c, ' +
                       'SBDC_checkbox__c, ' +
                       'Score_checkbox__c, ' +
                       'Trade_or_Professional_Association__c, ' +
                       'VBOC_checkbox__c, ' +
                       'WBC_checkbox__c, ' +
                       'conference360__Event__c.SBA_Office__c, ' +
                       'Other_Government_Agency__c, ' +
                       'Other_Resources__c ' +
                       'FROM conference360__Event__c ' +
                       'WHERE Total_Trained__c > 1 ' +
                       'AND Verified__c = TRUE ' +
                       'AND conference360__Event_Start_Date__c >= :startDate ' +
                       'AND conference360__Event_Start_Date__c <= :endDate ' +
                       'ORDER BY conference360__Event_Start_Date__c ASC, EDMIS_Key__c ASC';

        System.debug('SOQL Query: ' + query);
        return Database.getQueryLocator(query);
    }

    // Execute method to process each batch of records
    public void execute(Database.BatchableContext bc, List<conference360__Event__c> scope) {
        List<SBA_888_Output__c> outputRecords = new List<SBA_888_Output__c>();

        for (conference360__Event__c eventRecord : scope) {
            System.debug('Processing Event Record: ' + eventRecord.Id);

            // Create new output record for SBA_888_Output__c
            SBA_888_Output__c newRecord = new SBA_888_Output__c();

            // Assign the varRecordTypeId to the output record
            newRecord.RecordTypeId = varRecordTypeId;
            newRecord.Quarter_Year__c = varQuarterYear;

            // Example of field mapping
            newRecord.PartnerTrainingNumber__c = eventRecord.EDMIS_Key__c;
            newRecord.LocationCode__c = eventRecord.EDMIS_Location_Id__c;
            newRecord.DateTrainingStarted__c = eventRecord.conference360__Event_Start_Date__c;
            newRecord.NumberOfSessions__c = eventRecord.Sessions__c;
            newRecord.TotalTrainingHours__c = eventRecord.Total_Hours__c;
            newRecord.TrainingTitle__c = eventRecord.Name;
            newRecord.EventId__c = eventRecord.Id;
            newRecord.City_TrainingLocation__c = eventRecord.conference360__Venue__r.BillingCity;
            
            // 2. Convert the two-letter state abbreviation to a full state name
            if (eventRecord.conference360__Venue__r.BillingState != null) {
                String stateAbbr = eventRecord.conference360__Venue__r.BillingState.trim();
                String fullStateName = STATE_ABBREVIATION_MAP.get(stateAbbr);

                // If no match in the map, fallback to original abbreviation
                if (fullStateName == null) {
                    fullStateName = stateAbbr;
                }
                newRecord.State_TrainingLocation__c = fullStateName;
            } else {
                newRecord.State_TrainingLocation__c = null;
            }

            newRecord.Country_TrainingLocation__c = eventRecord.conference360__Venue__r.BillingCountry;
            newRecord.Total_NumberTrained__c = eventRecord.Total_Trained__c;
            newRecord.CurrentlyInBusiness_NumberTrained__c = eventRecord.Total_Attended_Business_Owner__c;
            newRecord.NotYetInBusiness_NumberTrained__c = eventRecord.Total_Attended_Not_Yet_In_Business__c;
            newRecord.PersonWithDisabilities_NumberTrained__c = eventRecord.Total_Attended_Disabled__c;
            newRecord.Female_NumberTrained__c = eventRecord.Total_Attended_Woman__c;
            newRecord.ActiveDuty_NumberTrained__c = eventRecord.Total_Attended_Active_Duty__c;
            newRecord.Veterans_NumberTrained__c = eventRecord.Total_Attended_Veterans__c;
            newRecord.ServiceDisabledVeterans_NumberTrained__c = eventRecord.Total_Attended_Disabled_Veterans__c;
            newRecord.MemberOfReserveOrNationalGuard_NumberTra__c = eventRecord.Total_Attended_Reserve_Natl_Guard__c;
            newRecord.SpouseOfMilitaryMember_NumberTrained__c = eventRecord.Total_Attended_Spouse_Of_Military_Membr__c;
            newRecord.Asian_NumberTrained__c = eventRecord.Total_Attended_Asian__c;
            newRecord.BlackOrAfricanAmerican_NumberTrained__c = eventRecord.Total_Attended_Black__c;
            newRecord.NativeAmericanOrAlaskaNative_NumberTrain__c = eventRecord.Total_Attended_Native_American__c;
            newRecord.NativeHawaiinOrPacificIslander_NumberTra__c = eventRecord.Total_Attended_Pacific__c;
            newRecord.White_NumberTrained__c = eventRecord.Total_Attended_White__c;
            newRecord.MiddleEastern_NumberTrained__c = eventRecord.Total_Attended_Middle_Eastern__c;
            newRecord.NorthAfrican_NumberTrained__c = eventRecord.Total_Attended_North_African__c;
            newRecord.HispanicOrLatinoOrigin_NumberTrained__c = eventRecord.Total_Attended_Hispanic__c;
            newRecord.NonHispanicOrLatinoOrigin_NumberTrained__c = eventRecord.Total_Attended_Not_Hispanic__c;
            newRecord.LGBTQ_NumberTrained__c = eventRecord.Total_Attended_LGBTQ__c;
            newRecord.Total_NumberMinoritiesTrained__c = eventRecord.Total_Attended_Minority__c;
            newRecord.TrainingPartners_OtherAgency_OtherGovtAg__c = eventRecord.Other_Government_Agency__c;
            newRecord.TrainingPartners_Other_OtherResources__c = eventRecord.Other_Resources__c;
            newRecord.DollarAmountOfFees__c = eventRecord.conference360__Total_Ticket_Revenue__c;
            newRecord.Language_Code__c = eventRecord.Language__c;

            // Translate Program_Format__c when inserting into ProgramFormatType__c
            if (eventRecord.Program_Format__c == 'Course' || 
                eventRecord.Program_Format__c == 'Webinar' ||
                eventRecord.Program_Format__c == 'Teleconference' ||
                eventRecord.Program_Format__c == 'On-line Course' ||
                eventRecord.Program_Format__c == 'Seminar') {
                newRecord.ProgramFormatType__c = 'Online';
            } else {
                newRecord.ProgramFormatType__c = eventRecord.Program_Format__c; // Default to the original Program Format
            }

            // Define a map for Topic__c to TrainingTopic__c translations
            Map<String, String> topicMap = new Map<String, String>{
                'Buy/Sell a Business' => 'Buy/Sell Business',
                'Cash Flow Management' => 'Business Financial/Cash Flow',
                'COVID-19 Finance/Capital' => 'Business Financing/Capital Sources',
                'COVID-19 General Support' => 'Marketing/Sales',
                'Financing/Capital' => 'Business Financial/Cash Flow',
                'Managing Business' => 'Business Operations/Management',
                'Rural Business Development' => 'Marketing/Sales',
                'Start-up Assistance' => 'Business Start-up/Preplanning',
                'Women-Owned Business' => 'Marketing/Sales',
                'Not Set' => '//Unknown/Not Stated',
                'Technology/Computers' => 'Technology'
            };

            // Use the map to translate Topic__c
            if (topicMap.containsKey(eventRecord.Topic__c)) {
                newRecord.TrainingTopic__c = topicMap.get(eventRecord.Topic__c);
            } else {
                newRecord.TrainingTopic__c = eventRecord.Topic__c;  // Default to original value if no match
            }

            // Conditional insertion for partner fields
            if (eventRecord.Chamber_of_Commerce__c == TRUE) {
                newRecord.TrainingPartners_Code_ChamberOfCommerce__c = 'Chamber of Commerce';
            } else {
                newRecord.TrainingPartners_Code_ChamberOfCommerce__c = '';
            }
            if (eventRecord.Education_Institution_checkbox__c == TRUE) {
                newRecord.TrainingPartners_Code_Educational_Inst__c = 'Educational Institution';
            } else {
                newRecord.TrainingPartners_Code_Educational_Inst__c = '';
            }
            if (eventRecord.For_Profit_Organization__c == TRUE) {
                newRecord.TrainingPartners_Code_For_Profit_Org__c = 'For-Profit Organization';
            } else {
                newRecord.TrainingPartners_Code_For_Profit_Org__c = '';
            }
            if (eventRecord.Native_American_Center__c == TRUE) {
                newRecord.TrainingPartners_Code_Native_American_Ct__c = 'Native American Center';
            } else {
                newRecord.TrainingPartners_Code_Native_American_Ct__c = '';
            }
            if (eventRecord.Online_Training_Resource__c == TRUE) {
                newRecord.TrainingPartners_Code_Online_Training__c = 'Native American Center';
            } else {
                newRecord.TrainingPartners_Code_Online_Training__c = '';
            }
            if (eventRecord.SBA_District_Office__c == TRUE) {
                newRecord.TrainingPartners_OtherSBA_District_Offic__c = eventRecord.SBA_Office__c;
            } else {
                newRecord.TrainingPartners_OtherSBA_District_Offic__c = '';
            }
            if (eventRecord.SBDC_checkbox__c == TRUE) {
                newRecord.TrainingPartners_Code_SBDC__c = 'SBDC';
            } else {
                newRecord.TrainingPartners_Code_SBDC__c = '';
            }
            if (eventRecord.Score_checkbox__c == TRUE) {
                newRecord.TrainingPartners_Code_SCORE__c = 'SCORE';
            } else {
                newRecord.TrainingPartners_Code_SCORE__c = '';
            }
            if (eventRecord.Trade_or_Professional_Association__c == TRUE) {
                newRecord.TrainingPartners_Code_TradeOrProfessiona__c = 'Trade or Professional Association';
            } else {
                newRecord.TrainingPartners_Code_TradeOrProfessiona__c = '';
            }
            if (eventRecord.VBOC_checkbox__c == TRUE) {
                newRecord.TrainingPartners_Code_VBOC__c = 'VBOC';
            } else {
                newRecord.TrainingPartners_Code_VBOC__c = '';
            }
            if (eventRecord.WBC_checkbox__c == TRUE) {
                newRecord.TrainingPartners_Code_Women_sBusinessCtr__c = 'Women\'s Business Center';
            } else {
                newRecord.TrainingPartners_Code_Women_sBusinessCtr__c = '';
            }

            // Trim BillingPostalCode to the first 5 characters if it exists
            if (eventRecord.conference360__Venue__r.BillingPostalCode != null && 
                eventRecord.conference360__Venue__r.BillingPostalCode.length() >= 5) {
                newRecord.ZipCode_TrainingLocation__c = eventRecord.conference360__Venue__r.BillingPostalCode.substring(0, 5);
            } else {
                // Handle cases where the BillingPostalCode is less than 5 characters or null
                System.debug('BillingPostalCode is invalid or too short for Event Record: ' + eventRecord.Id);
                newRecord.ZipCode_TrainingLocation__c = eventRecord.conference360__Venue__r.BillingPostalCode;  // Insert as is if shorter
            }

            outputRecords.add(newRecord);
        }

        // Insert the batch of records
        if (!outputRecords.isEmpty()) {
            try {
                insert outputRecords;
                System.debug('Successfully inserted records into SBA_888_Output__c.');
            } catch (Exception e) {
                System.debug('Error during insert: ' + e.getMessage());
            }
        } else {
            System.debug('No records to insert.');
        }
    }

    // Finish method (optional)
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch processing completed for 641 Batch.');

        // Total number of records processed
        Integer processedRecordsCount = Limits.getLimitDmlRows() - Limits.getDmlRows();

        // Fetch the email of the user who ran the batch job
        String jobOwnerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;

        // Create the email message
        if (!String.isBlank(jobOwnerEmail)) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { jobOwnerEmail });
            email.setSubject('SBA888 Batch Job Completion');
            email.setPlainTextBody(
                'The SBA888 Batch job has completed successfully. ' +
                'Total number of records processed: ' + processedRecordsCount + '.'
            );

            // Send the email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Email sent to job owner: ' + jobOwnerEmail +
                         ' with processed record count: ' + processedRecordsCount);
        }
    }
}