import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import validateQuarter from '@salesforce/apex/SBA888ReportController.validateQuarter';
import generateXml     from '@salesforce/apex/SBA888ReportController.generateXml';

const CY = new Date().getFullYear();

// SBA fiscal quarters (Oct-Sept year)
// Q1 = Oct 1 – Dec 31 | Q2 = Jan 1 – Mar 31 | Q3 = Apr 1 – Jun 30 | Q4 = Jul 1 – Sep 30
const QUARTER_OPTIONS = [
    { label: 'Q1 (Oct 1 – Dec 31)', value: 'Q1' },
    { label: 'Q2 (Jan 1 – Mar 31)', value: 'Q2' },
    { label: 'Q3 (Apr 1 – Jun 30)', value: 'Q3' },
    { label: 'Q4 (Jul 1 – Sep 30)', value: 'Q4' }
];

const YEAR_OPTIONS = [2024, 2025, 2026, 2027, 2028, 2029, 2030]
    .map(y => ({ label: String(y), value: String(y) }));

export default class Sba888ReportingWizard extends LightningElement {
    @track currentStep       = 1;
    @track selectedQuarter   = '';
    @track selectedYear      = String(CY);
    @track isValidating      = false;
    @track totalRecords      = 0;
    @track errorCount        = 0;
    @track warningCount      = 0;
    @track validationResults = [];
    @track jobId             = null;

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get currentStepStr()      { return String(this.currentStep); }
    get showValidationPanel() { return this.currentStep >= 2 && this.validationResults.length > 0; }
    get quarterYear()         { return this.selectedQuarter && this.selectedYear ? `${this.selectedYear}-${this.selectedQuarter}` : ''; }
    get hasErrors()           { return this.errorCount > 0; }
    get isValidateDisabled()  { return !this.selectedQuarter || !this.selectedYear; }

    get quarterOptions() { return QUARTER_OPTIONS; }
    get yearOptions()    { return YEAR_OPTIONS; }

    handleQuarterChange(e) { this.selectedQuarter = e.detail.value; }
    handleYearChange(e)    { this.selectedYear    = e.detail.value; }
    handleBack()           { if (this.currentStep > 1) this.currentStep--; }
    handleProceedToReview(){ this.currentStep = 3; }

    async handleValidate() {
        this.currentStep  = 2;
        this.isValidating = true;
        try {
            const res = await validateQuarter({ quarterYear: this.quarterYear });
            this.totalRecords      = res.totalRecords;
            this.errorCount        = res.errorCount;
            this.warningCount      = res.warningCount;
            this.validationResults = res.results;
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Validation Error', message: e.body?.message, variant: 'error' }));
            this.currentStep = 1;
        } finally {
            this.isValidating = false;
        }
    }

    async handleGenerate() {
        try {
            this.jobId = await generateXml({ quarterYear: this.quarterYear, reportType: 'Training' });
            this.currentStep = 4;
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Generation Error', message: e.body?.message, variant: 'error' }));
        }
    }

    handleJobComplete(e) {
        const { status } = e.detail;
        this.dispatchEvent(new ShowToastEvent({
            title:   status === 'Completed' ? 'XML Generated' : 'Generation Failed',
            message: status === 'Completed' ? `888 XML for ${this.quarterYear} complete.` : `Batch status: ${status}`,
            variant: status === 'Completed' ? 'success' : 'error'
        }));
    }
}
