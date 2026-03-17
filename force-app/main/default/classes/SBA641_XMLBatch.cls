/**
 * SBA641_XMLBatch — ORIGINAL (source-tracked from sandbox)
 *
 * KNOWN BUGS (see SBA641_XMLBatch_REFACTORED for fixes):
 *
 * BUG-1 [P0] XML root emitted in execute() with xmlOutput=='' guard
 *   Risk: On batch retry the guard fails → duplicate XML headers.
 *   Fix: emit root exclusively in start() / finish().
 *
 * BUG-2 [P1] Phone padding with '9'
 *   formatPhoneNumber() pads short numbers with trailing '9' digits.
 *   Produces fake 10-digit numbers that fail Nexus schema validation.
 *   Fix: flag short phones as ERRORs upstream; never pad.
 *
 * BUG-3 [P1] Race single-value drop
 *   RaceClientIntake__c is semicolon-delimited (Multi-Select Picklist).
 *   Batch emits only one <Code> tag → all values after first semicolon lost.
 *   Fix: split, translate, deduplicate, emit one <Code> per value.
 *
 * BUG-4 [P1] Country normalization incomplete
 *   AddressPart1 converts 'USA'/'US' but misses county names (Wayne, Kent…) and zip codes.
 *   AddressPart3 only converts 'USA', misses 'US'.
 *   Fix: any non-blank value → 'United States'.
 *
 * BUG-5 [P1] Ethnicity incorrect mapping
 *   'No' → 'Prefer not to say'. XSD requires 'Non Hispanic or Latino'.
 *   Fix: 'No' → 'Non Hispanic or Latino'.
 *
 * BUG-6 [P2] SexualOrientation/Gender fields queried that no longer exist in XSD
 *   XSD change #140 renamed Gender → Sex. XSD change #141 removed SexualOrientation entirely.
 */
public with sharing class SBA641_XMLBatch implements Database.Batchable<SObject>, Database.Stateful {

    private String varQuarterYear;
    private String varReportType;
    private String xmlOutput = '';

    public String getXmlOutput() {
        return this.xmlOutput;
    }

    public SBA641_XMLBatch(String varQuarterYear, String varReportType) {
        this.varQuarterYear = varQuarterYear;
        this.varReportType = varReportType;
    }

    public static String escapeXml(String input) {
        if (input == null) return '';
        input = input.replaceAll('&', '&amp;');
        input = input.replaceAll('<', '&lt;');
        input = input.replaceAll('>', '&gt;');
        input = input.replaceAll('"', '&quot;');
        input = input.replaceAll('\'', '&apos;');
        return input;
    }

    // BUG-2: pads short phones with '9'
    String formatPhoneNumber(String phone) {
        String cleanedPhone = phone != null ? phone.replaceAll('[^0-9]', '') : '';
        if (cleanedPhone.length() == 11 && cleanedPhone.startsWith('1')) {
            cleanedPhone = cleanedPhone.substring(1);
        } else if (cleanedPhone.length() > 10) {
            cleanedPhone = cleanedPhone.substring(0, 10);
        } else if (cleanedPhone.length() < 10) {
            // BUG: padding with '9' produces fake phone numbers
            while (cleanedPhone.length() < 10) {
                cleanedPhone += '9';
            }
        }
        return cleanedPhone;
    }

    public static String convertToCamelCase(String input) {
        if (String.isBlank(input)) return '';
        return input.toLowerCase().substring(0, 1).toUpperCase() + input.toLowerCase().substring(1);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT PartnerClientNumber__c, LocationCode__c, LastClientNamePart1__c, FirstClientNamePart1__c, MiddleClientNamePart1__c, ' +
                       'EmailClientRequest__c, PrimaryPhonePart1__c, SecondaryPhonePart1__c, Street1AddressPart1__c, ' +
                       'CityAddressPart1__c, StateAddressPart1__c, ZipCodeAddressPart1__c, CountryAddressPart1__c, ' +
                       'SurveyAgreement__c, DateClientSignature__c, OnFileClientSignature__c, RaceClientIntake__c, ' +
                       'SelfDescribedRaceClientIntake__c, EthnicityClientIntake__c, SexualOrientationClientIntake__c, ' +
                       'SelfDescribedSexualOrientation__c, SexClientIntake__c, DisabilityClientIntake__c, ' +
                       'MilitaryStatusClientIntake__c, BranchOfService_ClientIntake__c, Media_ClientIntake__c, ' +
                       'Other_Media_ClientIntake__c, CurrentlyInBusiness_ClientIntake__c, CurrentlyExporting_ClientIntake__c, ' +
                       'CompanyName_ClientIntake__c, BusinessType_ClientIntake__c, BusinessOwnership_Female__c, ' +
                       'ConductingBusinessOnline_ClientIntake__c, Certified8a_ClientIntake__c, TotalNumberofEmployees_ClientIntake__c, ' +
                       'NumberOfEmployeesInExportingBusiness__c, GrossRevenues_ClientAnnualIncomePart2__c, ' +
                       'ProfitLoss_ClientAnnualIncomePart2__c, ExportGrossRevenuesOrSales__c, LegalEntity_ClientIntake__c, LegalEntity_Other_ClientIntake__c, ' +
                       'CounselingSeeking_ClientIntake__c, ExportCountries_ClientIntake__c, PartnerSessionNumber_Counselor__c, ' +
                       'FundingSource_CounselorRecord__c, DateCounseled_CounselorRecord__c, CounselorName_CounselorRecord__c, ' +
                       'CounselingHours_Contact__c, CounselingHours_Prepare__c, CounselingHours_Travel__c, CounselingSeekingOther_ClientIntake__c, ' +
                       'FirstClientNamePart3__c, LastClientNamePart3__c, Email_CounselorRecord__c, Primary_PhonePart3__c, Language_CounselorRecord__c, ' +
                       'BusinessStartDatePart3__c, TotalNumberOfEmployees_CounselorRecord__c, NumberOfEmployeesExportingBusiness_Part3__c, ' +
                       'GrossRevenues_ClientAnnualIncomePart3__c, GrowthIndicator_ClientAnnualIncomePart3__c, ProfitLoss_ClientAnnualIncomePart3__c, ' +
                       'ExportGrossRevenuesOrSales_Part3__c, Certifications_CounselorRecord__c, CounselingProvided_CounselorRecord__c, ' +
                       'ReportableImpact__c, DateofReportableImpact__c, SBALoanAmount_CounselorRecord__c, NonSBALoanAmount_CounselorRecord__c, ' +
                       'EquityCapitalReceived_CounselorRecord__c, SBALoanAmountTxnNmbCounselorRecord__c, NonSBALoanAmountTxnNmbCounselorRecord__c, ' +
                       'EquityCapitalReceivedTxnNmbCounselorRec__c, Internet_Media_ClientIntake__c, CounselingProvidedOtherCounselorRecord__c, ' +
                       'ReferredClient_CounselorRecord__c, ReferredClientOther_CounselorRecord__c, SessionType_CounselorRecord__c, ' +
                       'LanguageOther_CounselorRecord__c, ExportCountries_CounselorRecord__c, DateTrainingStarted_CounselorRecord__c, ' +
                       'PartnerTrainingNumber_CounselorRecord__c, EmployeesTrained_CounselorRecord__c, HoursTrained_CounselorRecord__c, ' +
                       'Secondary_PhonePart3__c, Street1_AddressPart3__c, CounselorNotes_CounselorRecord__c, CurrentlyExporting_CounselorRecord_Part3__c, ' +
                       'City_AddressPart3__c, State_AddressPart3__c, ZipCode_AddressPart3__c, Country_AddressPart3__c, VerifiedToBeInBusiness_CounselorRecord__c ' +
                       'FROM SBA_641_Output__c ' +
                       'WHERE Quarter_Year__c = :varQuarterYear';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SBA_641_Output__c> scope) {
        // BUG-1: root tag inside execute() — retry risk
        if (xmlOutput == '') {
            xmlOutput = '<?xml version="1.0" encoding="UTF-8"?>\n';
            xmlOutput += '<CounselingInformation xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n';
        }

        for (SBA_641_Output__c record : scope) {
            xmlOutput += '<CounselingRecord>\n';
            xmlOutput += '<PartnerClientNumber>' + escapeXml(record.PartnerClientNumber__c) + '</PartnerClientNumber>\n';
            xmlOutput += '<Location><LocationCode>' + escapeXml(record.LocationCode__c) + '</LocationCode></Location>\n';

            xmlOutput += '<ClientRequest>\n';
            xmlOutput += '<ClientNamePart1><Last>' + escapeXml(record.LastClientNamePart1__c) + '</Last>' +
                         '<First>' + escapeXml(record.FirstClientNamePart1__c) + '</First>' +
                         '<Middle>' + escapeXml(record.MiddleClientNamePart1__c) + '</Middle></ClientNamePart1>\n';
            xmlOutput += '<Email>' + escapeXml(record.EmailClientRequest__c) + '</Email>\n';

            String primaryPhone = formatPhoneNumber(record.PrimaryPhonePart1__c);     // BUG-2
            String secondaryPhone = formatPhoneNumber(record.SecondaryPhonePart1__c); // BUG-2
            xmlOutput += '<PhonePart1>\n';
            xmlOutput += '<Primary>' + escapeXml(primaryPhone) + '</Primary>\n';
            xmlOutput += '<Secondary>' + escapeXml(secondaryPhone) + '</Secondary>\n';
            xmlOutput += '</PhonePart1>\n';

            // BUG-4: only converts 'USA'/'US', misses county names and zip codes
            String countryAddressPart1 = record.CountryAddressPart1__c != null &&
                (record.CountryAddressPart1__c == 'USA' || record.CountryAddressPart1__c == 'US')
                ? 'United States' : record.CountryAddressPart1__c;

            xmlOutput += '<AddressPart1><Street1>' + escapeXml(record.Street1AddressPart1__c) + '</Street1>' +
                         '<City>' + escapeXml(record.CityAddressPart1__c) + '</City>' +
                         '<State>' + escapeXml(record.StateAddressPart1__c) + '</State>' +
                         '<ZipCode>' + escapeXml(record.ZipCodeAddressPart1__c) + '</ZipCode>' +
                         '<Country><Code>' + escapeXml(countryAddressPart1) + '</Code></Country>\n' +
                         '<PostalCode></PostalCode><StateOrProvince></StateOrProvince></AddressPart1>\n';
            xmlOutput += '<SurveyAgreement>' + (record.SurveyAgreement__c == true ? 'Yes' : 'No') + '</SurveyAgreement>\n';
            String onFileSignature = (record.OnFileClientSignature__c == true) ? 'Yes' : 'No';
            xmlOutput += '<ClientSignature><Date>' + String.valueOf(record.DateClientSignature__c) + '</Date>' +
                         '<OnFile>' + onFileSignature + '</OnFile></ClientSignature>\n';
            xmlOutput += '</ClientRequest>\n';

            xmlOutput += '<ClientIntake>\n';

            // BUG-3: single-value translation — semicolon-delimited multi-select not split
            String raceClientIntake = '';
            if (record.RaceClientIntake__c != null) {
                if (record.RaceClientIntake__c == 'Black') {
                    raceClientIntake = 'Black or African American';
                } else if (record.RaceClientIntake__c == 'Prefer Not to Say') {
                    raceClientIntake = 'Prefer not to say';
                } else {
                    raceClientIntake = record.RaceClientIntake__c;
                }
            }
            xmlOutput += '<Race>\n';
            xmlOutput += '<Code>' + escapeXml(raceClientIntake != null ? raceClientIntake : '') + '</Code>\n';
            xmlOutput += '<SelfDescribedRace>' + escapeXml(record.SelfDescribedRaceClientIntake__c != null
                ? record.SelfDescribedRaceClientIntake__c : '') + '</SelfDescribedRace>\n';
            xmlOutput += '</Race>\n';

            // BUG-5: 'No' → 'Prefer not to say' — should be 'Non Hispanic or Latino'
            String ethnicityClientIntake = '';
            if (record.EthnicityClientIntake__c != null) {
                if (record.EthnicityClientIntake__c == 'No') {
                    ethnicityClientIntake = 'Prefer not to say'; // BUG: should be 'Non Hispanic or Latino'
                } else if (record.EthnicityClientIntake__c == 'Yes') {
                    ethnicityClientIntake = 'Hispanic or Latino';
                } else {
                    ethnicityClientIntake = record.EthnicityClientIntake__c;
                }
            }
            xmlOutput += '<Ethnicity>' + escapeXml(ethnicityClientIntake) + '</Ethnicity>\n';
            xmlOutput += '<Sex>' + escapeXml(record.SexClientIntake__c) + '</Sex>\n';
            xmlOutput += '<Disability>' + escapeXml(record.DisabilityClientIntake__c) + '</Disability>\n';
            xmlOutput += '<MilitaryStatus>' + escapeXml(record.MilitaryStatusClientIntake__c) + '</MilitaryStatus>\n';
            xmlOutput += '<BranchOfService>' + escapeXml(record.BranchOfService_ClientIntake__c) + '</BranchOfService>\n';

            if (String.isBlank(record.Media_ClientIntake__c) && String.isBlank(record.Other_Media_ClientIntake__c)) {
                xmlOutput += '<Media />\n';
            } else {
                xmlOutput += '<Media>\n';
                xmlOutput += '<Code>' + escapeXml(String.isNotBlank(record.Media_ClientIntake__c) ? record.Media_ClientIntake__c : '') + '</Code>\n';
                if (record.Media_ClientIntake__c == 'Other') {
                    String otherMedia = String.isNotBlank(record.Other_Media_ClientIntake__c) ? record.Other_Media_ClientIntake__c : 'Undetermined';
                    xmlOutput += '<Other>' + escapeXml(otherMedia) + '</Other>\n';
                } else {
                    xmlOutput += '<Other>' + escapeXml(record.Other_Media_ClientIntake__c) + '</Other>\n';
                }
                xmlOutput += '</Media>\n';
            }

            xmlOutput += '<Internet>' + escapeXml(record.Internet_Media_ClientIntake__c) + '</Internet>\n';
            xmlOutput += '<CurrentlyInBusiness>' + escapeXml(record.CurrentlyInBusiness_ClientIntake__c) + '</CurrentlyInBusiness>\n';
            xmlOutput += '<CurrentlyExporting>' + (record.CurrentlyExporting_ClientIntake__c == true ? 'Yes' : 'No') + '</CurrentlyExporting>\n';
            xmlOutput += '<CompanyName>' + escapeXml(record.CompanyName_ClientIntake__c) + '</CompanyName>\n';
            xmlOutput += '<BusinessType>' + escapeXml(record.BusinessType_ClientIntake__c) + '</BusinessType>\n';
            xmlOutput += '<BusinessOwnership>\n';
            xmlOutput += '<Female>' + escapeXml(String.valueOf(record.BusinessOwnership_Female__c != null ? record.BusinessOwnership_Female__c : 0)) + '</Female>\n';
            xmlOutput += '</BusinessOwnership>\n';
            xmlOutput += '<ConductingBusinessOnline>' + String.valueOf(record.ConductingBusinessOnline_ClientIntake__c) + '</ConductingBusinessOnline>\n';
            String certified8a = (record.CurrentlyInBusiness_ClientIntake__c == 'Yes') ? 'Yes' : (record.Certified8a_ClientIntake__c != null ? record.Certified8a_ClientIntake__c : 'No');
            xmlOutput += '<ClientIntake_Certified8a>' + escapeXml(certified8a) + '</ClientIntake_Certified8a>\n';
            xmlOutput += '<TotalNumberOfEmployees>' + escapeXml(String.valueOf(record.TotalNumberofEmployees_ClientIntake__c)) + '</TotalNumberOfEmployees>\n';
            xmlOutput += '<NumberOfEmployeesInExportingBusiness>' + escapeXml(String.valueOf(record.NumberOfEmployeesInExportingBusiness__c)) + '</NumberOfEmployeesInExportingBusiness>\n';
            xmlOutput += '<ClientAnnualIncomePart2>\n';
            xmlOutput += '<GrossRevenues>' + escapeXml(String.valueOf(record.GrossRevenues_ClientAnnualIncomePart2__c)) + '</GrossRevenues>\n';
            xmlOutput += '<ProfitLoss>' + escapeXml(String.valueOf(record.ProfitLoss_ClientAnnualIncomePart2__c)) + '</ProfitLoss>\n';
            xmlOutput += '<ExportGrossRevenuesOrSales>' + escapeXml(String.valueOf(record.ExportGrossRevenuesOrSales__c)) + '</ExportGrossRevenuesOrSales>\n';
            xmlOutput += '</ClientAnnualIncomePart2>\n';
            xmlOutput += '<LegalEntity>\n';
            xmlOutput += '<Code>' + escapeXml(record.LegalEntity_ClientIntake__c) + '</Code>\n';
            xmlOutput += '<Other>' + escapeXml(record.LegalEntity_Other_ClientIntake__c) + '</Other>\n';
            xmlOutput += '</LegalEntity>\n';
            xmlOutput += '<Rural_vs_Urban>Undetermined</Rural_vs_Urban>\n';
            xmlOutput += '<FIPS_Code></FIPS_Code>\n';
            xmlOutput += '<CounselingSeeking>\n';
            xmlOutput += '<Code>' + escapeXml(record.CounselingSeeking_ClientIntake__c != null ? record.CounselingSeeking_ClientIntake__c : '') + '</Code>\n';
            xmlOutput += '<Other>' + escapeXml(record.CounselingSeekingOther_ClientIntake__c != null ? record.CounselingSeekingOther_ClientIntake__c : '') + '</Other>\n';
            xmlOutput += '</CounselingSeeking>\n';

            String exportCountriesClientIntake = record.ExportCountries_ClientIntake__c;
            if (String.isNotBlank(exportCountriesClientIntake)) {
                xmlOutput += '<ExportCountries>\n';
                for (String country : exportCountriesClientIntake.split(';')) {
                    xmlOutput += '<Code>' + escapeXml(country.trim()) + '</Code>\n';
                }
                xmlOutput += '</ExportCountries>\n';
            } else {
                xmlOutput += '<ExportCountries />\n';
            }

            xmlOutput += '</ClientIntake>\n';

            xmlOutput += '<CounselorRecord>\n';
            xmlOutput += '<PartnerSessionNumber>' + escapeXml(record.PartnerSessionNumber_Counselor__c != null ? record.PartnerSessionNumber_Counselor__c : '') + '</PartnerSessionNumber>\n';
            xmlOutput += '<FundingSource></FundingSource>\n';
            xmlOutput += '<ClientNamePart3>\n';
            xmlOutput += '<Last>' + escapeXml(record.LastClientNamePart3__c != null ? record.LastClientNamePart3__c : '') + '</Last>\n';
            xmlOutput += '<First>' + escapeXml(record.FirstClientNamePart3__c != null ? record.FirstClientNamePart3__c : '') + '</First>\n';
            xmlOutput += '<Middle></Middle>\n';
            xmlOutput += '</ClientNamePart3>\n';
            xmlOutput += '<Email>' + escapeXml(record.Email_CounselorRecord__c != null ? record.Email_CounselorRecord__c : '') + '</Email>\n';

            String primaryPhone3 = formatPhoneNumber(record.Primary_PhonePart3__c);   // BUG-2
            String secondaryPhone3 = formatPhoneNumber(record.Secondary_PhonePart3__c); // BUG-2
            xmlOutput += '<PhonePart3>\n';
            xmlOutput += '<Primary>' + escapeXml(primaryPhone3) + '</Primary>\n';
            xmlOutput += '<Secondary>' + escapeXml(secondaryPhone3) + '</Secondary>\n';
            xmlOutput += '</PhonePart3>\n';

            // BUG-4: only converts 'USA', misses 'US' and all other variants
            String countryAddressPart3 = record.Country_AddressPart3__c != null && record.Country_AddressPart3__c == 'USA' ? 'United States' : record.Country_AddressPart3__c;
            xmlOutput += '<AddressPart3>\n';
            xmlOutput += '<Street1>' + escapeXml(record.Street1_AddressPart3__c != null ? record.Street1_AddressPart3__c : '') + '</Street1>\n';
            xmlOutput += '<Street2></Street2>\n';
            xmlOutput += '<City>' + escapeXml(record.City_AddressPart3__c != null ? record.City_AddressPart3__c : '') + '</City>\n';
            xmlOutput += '<State>' + escapeXml(record.State_AddressPart3__c != null ? record.State_AddressPart3__c : '') + '</State>\n';
            xmlOutput += '<Country><Code>' + escapeXml(countryAddressPart3) + '</Code></Country>\n';
            xmlOutput += '<ZipCode>' + escapeXml(record.ZipCode_AddressPart3__c != null ? record.ZipCode_AddressPart3__c : '') + '</ZipCode>\n';
            xmlOutput += '<Zip4Code></Zip4Code>\n';
            xmlOutput += '</AddressPart3>\n';

            xmlOutput += '<VerifiedToBeInBusiness>' + escapeXml(record.VerifiedToBeInBusiness_CounselorRecord__c != null ? record.VerifiedToBeInBusiness_CounselorRecord__c : '') + '</VerifiedToBeInBusiness>\n';
            xmlOutput += '<ReportableImpact>' + escapeXml(record.ReportableImpact__c) + '</ReportableImpact>\n';
            xmlOutput += '<DateOfReportableImpact>' + (record.DateofReportableImpact__c != null ? String.valueOf(record.DateofReportableImpact__c) : '') + '</DateOfReportableImpact>\n';
            xmlOutput += '<CurrentlyExporting>' + (record.CurrentlyExporting_CounselorRecord_Part3__c == true ? 'Yes' : 'No') + '</CurrentlyExporting>\n';
            xmlOutput += '<BusinessStartDatePart3>' + escapeXml(record.BusinessStartDatePart3__c != null ? String.valueOf(record.BusinessStartDatePart3__c) : '') + '</BusinessStartDatePart3>\n';
            xmlOutput += '<TotalNumberOfEmployees>' + escapeXml(record.TotalNumberOfEmployees_CounselorRecord__c != null ? String.valueOf(record.TotalNumberOfEmployees_CounselorRecord__c) : '') + '</TotalNumberOfEmployees>\n';
            xmlOutput += '<NumberOfEmployeesInExportingBusiness>' + escapeXml(record.NumberOfEmployeesExportingBusiness_Part3__c != null ? String.valueOf(record.NumberOfEmployeesExportingBusiness_Part3__c) : '') + '</NumberOfEmployeesInExportingBusiness>\n';
            xmlOutput += '<ClientAnnualIncomePart3>\n';
            xmlOutput += '<GrossRevenues>' + escapeXml(record.GrossRevenues_ClientAnnualIncomePart3__c != null ? String.valueOf(record.GrossRevenues_ClientAnnualIncomePart3__c) : '') + '</GrossRevenues>\n';
            xmlOutput += '<ProfitLoss>' + escapeXml(record.ProfitLoss_ClientAnnualIncomePart3__c != null ? String.valueOf(record.ProfitLoss_ClientAnnualIncomePart3__c) : '') + '</ProfitLoss>\n';
            xmlOutput += '<ExportGrossRevenuesOrSales>' + escapeXml(record.ExportGrossRevenuesOrSales_Part3__c != null ? String.valueOf(record.ExportGrossRevenuesOrSales_Part3__c) : '') + '</ExportGrossRevenuesOrSales>\n';
            xmlOutput += '<GrowthIndicator>' + escapeXml(record.GrowthIndicator_ClientAnnualIncomePart3__c != null ? record.GrowthIndicator_ClientAnnualIncomePart3__c : '') + '</GrowthIndicator>\n';
            xmlOutput += '</ClientAnnualIncomePart3>\n';
            xmlOutput += '<ResourcePartnerServiceContributed>\n';
            xmlOutput += '<SBALoanAmount>' + (record.SBALoanAmount_CounselorRecord__c != null ? String.valueOf(record.SBALoanAmount_CounselorRecord__c) : '') + '</SBALoanAmount>';
            xmlOutput += '<NonSBALoanAmount>' + (record.NonSBALoanAmount_CounselorRecord__c != null ? String.valueOf(record.NonSBALoanAmount_CounselorRecord__c) : '') + '</NonSBALoanAmount>';
            xmlOutput += '<EquityCapitalReceived>' + (record.EquityCapitalReceived_CounselorRecord__c != null ? String.valueOf(record.EquityCapitalReceived_CounselorRecord__c) : '') + '</EquityCapitalReceived>';
            xmlOutput += '<SBALoanAmountTxnNmb>' + record.SBALoanAmountTxnNmbCounselorRecord__c + '</SBALoanAmountTxnNmb>\n';
            xmlOutput += '<NonSBALoanAmountTxnNmb>' + record.NonSBALoanAmountTxnNmbCounselorRecord__c + '</NonSBALoanAmountTxnNmb>\n';
            xmlOutput += '<EquityCapitalReceivedTxnNmb>' + record.EquityCapitalReceivedTxnNmbCounselorRec__c + '</EquityCapitalReceivedTxnNmb>\n';
            xmlOutput += '<NumberOfContractsReceived></NumberOfContractsReceived>\n';
            xmlOutput += '</ResourcePartnerServiceContributed>\n';

            if (String.isBlank(record.Certifications_CounselorRecord__c) && record.CurrentlyInBusiness_ClientIntake__c != 'Yes') {
                xmlOutput += '<Certifications />\n';
            } else {
                xmlOutput += '<Certifications>\n';
                if (record.CurrentlyInBusiness_ClientIntake__c == 'Yes') {
                    record.Certified8a_ClientIntake__c = 'Yes';
                    if (String.isBlank(record.Certifications_CounselorRecord__c)) {
                        record.Certifications_CounselorRecord__c = '8(a)';
                    } else if (!record.Certifications_CounselorRecord__c.contains('8(a)')) {
                        record.Certifications_CounselorRecord__c += ', 8(a)';
                    }
                }
                if (!String.isBlank(record.Certifications_CounselorRecord__c)) {
                    for (String certification : record.Certifications_CounselorRecord__c.split(',')) {
                        xmlOutput += '<Code>' + escapeXml(certification.trim()) + '</Code>\n';
                    }
                }
                xmlOutput += '<Other></Other>\n';
                xmlOutput += '</Certifications>\n';
            }

            xmlOutput += '<SBAFinancialAssistance></SBAFinancialAssistance>\n';
            xmlOutput += '<CounselingProvided>\n';
            xmlOutput += '<Code>' + escapeXml(record.CounselingProvided_CounselorRecord__c != null ? record.CounselingProvided_CounselorRecord__c : '') + '</Code>\n';
            if ('Other'.equalsIgnoreCase(record.CounselingProvided_CounselorRecord__c)) {
                xmlOutput += '<Other>' + escapeXml(record.CounselingProvidedOtherCounselorRecord__c != null ? record.CounselingProvidedOtherCounselorRecord__c : 'Undetermined') + '</Other>\n';
            } else {
                xmlOutput += '<Other>' + escapeXml(record.CounselingProvidedOtherCounselorRecord__c != null ? record.CounselingProvidedOtherCounselorRecord__c : '') + '</Other>\n';
            }
            xmlOutput += '</CounselingProvided>\n';

            if (String.isBlank(record.ReferredClient_CounselorRecord__c) && String.isBlank(record.ReferredClientOther_CounselorRecord__c)) {
                xmlOutput += '<ReferredClient />\n';
            } else {
                xmlOutput += '<ReferredClient>\n';
                xmlOutput += '    <Code>' + escapeXml(record.ReferredClient_CounselorRecord__c != null ? record.ReferredClient_CounselorRecord__c : '') + '</Code>\n';
                xmlOutput += '    <Other>' + escapeXml(record.ReferredClientOther_CounselorRecord__c != null ? record.ReferredClientOther_CounselorRecord__c : '') + '</Other>\n';
                xmlOutput += '</ReferredClient>\n';
            }

            xmlOutput += '<SessionType>' + escapeXml(record.SessionType_CounselorRecord__c != null ? record.SessionType_CounselorRecord__c : '') + '</SessionType>\n';
            xmlOutput += '<Language>\n';
            xmlOutput += '<Code>' + escapeXml(record.Language_CounselorRecord__c != null ? record.Language_CounselorRecord__c : '') + '</Code>\n';
            xmlOutput += '<Other>' + escapeXml(record.LanguageOther_CounselorRecord__c != null ? record.LanguageOther_CounselorRecord__c : '') + '</Other>\n';
            xmlOutput += '</Language>\n';
            xmlOutput += '<DateCounseled>' + escapeXml(record.DateCounseled_CounselorRecord__c != null ? String.valueOf(record.DateCounseled_CounselorRecord__c) : '') + '</DateCounseled>\n';
            xmlOutput += '<CounselorName>' + escapeXml(record.CounselorName_CounselorRecord__c != null ? record.CounselorName_CounselorRecord__c : '') + '</CounselorName>\n';

            Decimal contactHours = (record.CounselingHours_Contact__c != null && record.CounselingHours_Contact__c != 0)
                       ? record.CounselingHours_Contact__c : 0.5;
            xmlOutput += '<CounselingHours>\n';
            xmlOutput += '<Contact>' + escapeXml(String.valueOf(contactHours)) + '</Contact>\n';
            xmlOutput += '<Prepare>' + escapeXml(record.CounselingHours_Prepare__c != null ? String.valueOf(record.CounselingHours_Prepare__c) : '') + '</Prepare>\n';
            xmlOutput += '<Travel>' + escapeXml(record.CounselingHours_Travel__c != null ? String.valueOf(record.CounselingHours_Travel__c) : '') + '</Travel>\n';
            xmlOutput += '</CounselingHours>\n';

            xmlOutput += '<CounselorNotes>' + escapeXml(record.CounselorNotes_CounselorRecord__c != null ? record.CounselorNotes_CounselorRecord__c : '') + '</CounselorNotes>\n';

            String exportCountriesCounselorRecord = record.ExportCountries_CounselorRecord__c;
            if (String.isNotBlank(exportCountriesCounselorRecord)) {
                xmlOutput += '<ExportCountries>\n';
                for (String country : exportCountriesCounselorRecord.split(';')) {
                    xmlOutput += '<Code>' + escapeXml(country.trim()) + '</Code>\n';
                }
                xmlOutput += '</ExportCountries>\n';
            } else {
                xmlOutput += '<ExportCountries />\n';
            }

            xmlOutput += '<TrainingSession>\n';
            xmlOutput += '<DateTrainingStarted>' + escapeXml(record.DateTrainingStarted_CounselorRecord__c != null ? String.valueOf(record.DateTrainingStarted_CounselorRecord__c) : '') + '</DateTrainingStarted>\n';
            xmlOutput += '<PartnerTrainingNumber>' + escapeXml(record.PartnerTrainingNumber_CounselorRecord__c != null ? record.PartnerTrainingNumber_CounselorRecord__c : '') + '</PartnerTrainingNumber>\n';
            xmlOutput += '<EmployeesTrained>' + escapeXml(record.EmployeesTrained_CounselorRecord__c != null ? String.valueOf(record.EmployeesTrained_CounselorRecord__c) : '') + '</EmployeesTrained>\n';
            xmlOutput += '<HoursTrained>' + escapeXml(record.HoursTrained_CounselorRecord__c != null ? String.valueOf(record.HoursTrained_CounselorRecord__c) : '') + '</HoursTrained>\n';
            xmlOutput += '</TrainingSession>\n';

            xmlOutput += '</CounselorRecord>\n';
            xmlOutput += '</CounselingRecord>\n';
        }
    }

    public void finish(Database.BatchableContext bc) {
        xmlOutput += '</CounselingInformation>\n';

        SBA641_XML_Upload__c xmlRecord = new SBA641_XML_Upload__c();
        xmlRecord.QuarterYear__c = varQuarterYear;
        insert xmlRecord;

        Blob xmlBlobData = Blob.valueOf(xmlOutput);

        try {
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = 'SBA641_XML_Report_' + varQuarterYear;
            contentVersion.PathOnClient = 'SBA641_Report_' + varQuarterYear + '.xml';
            contentVersion.VersionData = xmlBlobData;
            contentVersion.IsMajorVersion = true;
            insert contentVersion;

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId;
            contentDocumentLink.LinkedEntityId = xmlRecord.Id;
            contentDocumentLink.ShareType = 'V';
            insert contentDocumentLink;
        } catch (Exception e) {
            System.debug('Error while creating ContentVersion or ContentDocumentLink: ' + e.getMessage());
        }

        String jobOwnerEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
        if (!String.isBlank(jobOwnerEmail)) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { jobOwnerEmail });
            email.setSubject('SBA641 XML Report for ' + varQuarterYear);
            email.setPlainTextBody('Please find the attached SBA641 XML report.');
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('SBA641_Report.xml');
            attachment.setBody(xmlBlobData);
            attachment.setContentType('text/xml');
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}
