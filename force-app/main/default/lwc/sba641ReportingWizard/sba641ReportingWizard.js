import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuarterDates   from '@salesforce/apex/SBA641ReportController.getQuarterDates';
import recordTypeExists  from '@salesforce/apex/SBA641ReportController.recordTypeExists';
import extractSessions   from '@salesforce/apex/SBA641ReportController.extractSessions';
import getOutputCount    from '@salesforce/apex/SBA641ReportController.getOutputCount';
import validateQuarter   from '@salesforce/apex/SBA641ReportController.validateQuarter';
import generateXml       from '@salesforce/apex/SBA641ReportController.generateXml';

// SBA Fiscal Quarters
const QUARTER_OPTIONS = [
    { label: 'Q1 (Oct 1 – Dec 31)', value: 'Q1' },
    { label: 'Q2 (Jan 1 – Mar 31)', value: 'Q2' },
    { label: 'Q3 (Apr 1 – Jun 30)', value: 'Q3' },
    { label: 'Q4 (Jul 1 – Sep 30)', value: 'Q4' }
];

const YEAR_OPTIONS = [2024, 2025, 2026, 2027, 2028, 2029, 2030]
    .map(y => ({ label: String(y), value: String(y) }));

export default class Sba641ReportingWizard extends LightningElement {

    // ── State ─────────────────────────────────────────────────────────────────
    @track currentStep       = 1;
    @track selectedQuarter   = '';
    @track selectedYear      = String(new Date().getFullYear());
    @track dateLabel         = '';
    @track rtMissing         = false;

    // Step 2 — Extract
    @track isExtracting      = false;
    @track extractJobId      = null;
    @track extractedCount    = 0;

    // Step 3 — Validate
    @track isValidating      = false;
    @track totalRecords      = 0;
    @track errorCount        = 0;
    @track warningCount      = 0;
    @track validationResults = [];

    // Step 5 — Generate
    @track xmlJobId          = null;

    // ── Step visibility ────────────────────────────────────────────────────────
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }
    get currentStepStr()      { return String(this.currentStep); }
    get showValidationPanel() { return this.currentStep >= 3 && this.validationResults.length > 0; }

    // ── Computed ───────────────────────────────────────────────────────────────
    get quarterYear() {
        return this.selectedQuarter && this.selectedYear
            ? `${this.selectedQuarter}_${this.selectedYear}` : '';
    }
    get quarterOptions()     { return QUARTER_OPTIONS; }
    get yearOptions()        { return YEAR_OPTIONS; }
    get isNextDisabled()     { return !this.selectedQuarter || !this.selectedYear; }
    get noRecordsExtracted() { return this.extractedCount === 0; }
    get hasErrors()          { return this.errorCount > 0; }
    get hasWarnings()        { return this.warningCount > 0; }

    // ── Step 1: Select Quarter ─────────────────────────────────────────────────
    handleQuarterChange(e) {
        this.selectedQuarter = e.detail.value;
        this._updateDateLabel();
    }
    handleYearChange(e) {
        this.selectedYear = e.detail.value;
        this._updateDateLabel();
    }

    async _updateDateLabel() {
        if (!this.selectedQuarter || !this.selectedYear) return;
        try {
            const dates = await getQuarterDates({ quarterYear: this.quarterYear });
            this.dateLabel = dates.label;
        } catch(e) {
            this.dateLabel = '';
        }
    }

    async handleExtract() {
        // Check Record Type exists first
        const rtOk = await recordTypeExists({ quarterYear: this.quarterYear });
        if (!rtOk) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Record Type Missing',
                message: `No Record Type "${this.quarterYear}" exists on SBA 641 Output. Please create it in Setup first.`,
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }
        this.currentStep  = 2;
        this.isExtracting = true;
        try {
            this.extractJobId = await extractSessions({ quarterYear: this.quarterYear });
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Extraction Error',
                message: e.body?.message || e.message,
                variant: 'error'
            }));
            this.currentStep  = 1;
            this.isExtracting = false;
        }
    }

    // ── Step 2: Extract complete ────────────────────────────────────────────────
    async handleExtractComplete(e) {
        const { status } = e.detail;
        this.isExtracting = false;
        if (status === 'Completed') {
            try {
                this.extractedCount = await getOutputCount({ quarterYear: this.quarterYear });
            } catch(err) {
                this.extractedCount = 0;
            }
            if (this.extractedCount === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'No Records Found',
                    message: `No sessions found for ${this.quarterYear}. Check the date range or session data.`,
                    variant: 'warning',
                    mode: 'sticky'
                }));
            }
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Extraction Failed',
                message: `Batch job ended with status: ${status}`,
                variant: 'error'
            }));
        }
    }

    // ── Step 3: Validate ────────────────────────────────────────────────────────
    async handleValidate() {
        this.currentStep  = 3;
        this.isValidating = true;
        try {
            const res = await validateQuarter({ quarterYear: this.quarterYear });
            this.totalRecords      = res.totalRecords;
            this.errorCount        = res.errorCount;
            this.warningCount      = res.warningCount;
            this.validationResults = res.results;
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: e.body?.message || e.message,
                variant: 'error'
            }));
            this.currentStep = 2;
        } finally {
            this.isValidating = false;
        }
    }

    handleProceedToReview() { this.currentStep = 4; }

    // ── Step 5: Generate XML ─────────────────────────────────────────────────────
    async handleGenerate() {
        try {
            this.xmlJobId = await generateXml({
                quarterYear: this.quarterYear,
                reportType: 'Counseling'
            });
            this.currentStep = 5;
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Generation Error',
                message: e.body?.message || e.message,
                variant: 'error'
            }));
        }
    }

    handleJobComplete(e) {
        const { status } = e.detail;
        this.dispatchEvent(new ShowToastEvent({
            title:   status === 'Completed' ? '✅ XML Generated' : 'Generation Failed',
            message: status === 'Completed'
                ? `641 XML for ${this.quarterYear} generated and emailed to you.`
                : `Batch ended with status: ${status}`,
            variant: status === 'Completed' ? 'success' : 'error',
            mode: 'sticky'
        }));
    }

    handleBack() { if (this.currentStep > 1) this.currentStep--; }
}
