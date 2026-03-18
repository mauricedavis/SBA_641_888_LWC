import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuarterDates   from '@salesforce/apex/SBA641ReportController.getQuarterDates';
import recordTypeExists  from '@salesforce/apex/SBA641ReportController.recordTypeExists';
import extractSessions   from '@salesforce/apex/SBA641ReportController.extractSessions';
import getOutputCount    from '@salesforce/apex/SBA641ReportController.getOutputCount';
import validateQuarter   from '@salesforce/apex/SBA641ReportController.validateQuarter';
import generateXml       from '@salesforce/apex/SBA641ReportController.generateXml';
import saveRunState      from '@salesforce/apex/SBA641ReportController.saveRunState';
import loadRunState      from '@salesforce/apex/SBA641ReportController.loadRunState';
import clearRunState     from '@salesforce/apex/SBA641ReportController.clearRunState';

const QUARTER_OPTIONS = [
    { label: 'Q1 (Oct 1 \u2013 Dec 31)', value: 'Q1' },
    { label: 'Q2 (Jan 1 \u2013 Mar 31)', value: 'Q2' },
    { label: 'Q3 (Apr 1 \u2013 Jun 30)', value: 'Q3' },
    { label: 'Q4 (Jul 1 \u2013 Sep 30)', value: 'Q4' }
];

const YEAR_OPTIONS = [2024, 2025, 2026, 2027, 2028, 2029, 2030]
    .map(y => ({ label: String(y), value: String(y) }));

export default class Sba641ReportingWizard extends LightningElement {

    // ── State ──────────────────────────────────────────────────────────────────
    @track currentStep        = 1;
    @track selectedQuarter    = '';
    @track selectedYear       = String(new Date().getFullYear());
    @track dateLabel          = '';

    // Resume banner
    @track showResumeBanner   = false;
    @track resumeLabel        = '';
    @track resumeLastModified = '';

    // Step 2 — Extract
    @track isExtracting       = false;
    @track extractJobId       = null;
    @track extractedCount     = 0;

    // Step 3 — Validate
    @track isValidating       = false;
    @track totalRecords       = 0;
    @track errorCount         = 0;
    @track warningCount       = 0;
    @track validationResults  = [];

    // Step 5 — Generate
    @track xmlJobId           = null;

    // ── Lifecycle ──────────────────────────────────────────────────────────────
    connectedCallback() {
        this._checkForActiveRun();
    }

    async _checkForActiveRun() {
        try {
            const state = await loadRunState();
            if (state && state.currentStep > 1) {
                this.showResumeBanner   = true;
                this.resumeLabel        = `${state.quarterYear} — Step ${state.currentStep}`;
                this.resumeLastModified = state.lastModified
                    ? new Date(state.lastModified).toLocaleString() : '';
                // Store state for resume
                this._pendingState = state;
            }
        } catch(e) {
            // No active run — start fresh
        }
    }

    handleResume() {
        const s = this._pendingState;
        if (!s) return;
        this.selectedQuarter   = s.selectedQuarter || '';
        this.selectedYear      = s.selectedYear    || String(new Date().getFullYear());
        this.dateLabel         = s.dateLabel        || '';
        this.extractJobId      = s.extractJobId     || null;
        this.extractedCount    = s.extractedCount   || 0;
        this.xmlJobId          = s.xmlJobId         || null;
        this.currentStep       = s.currentStep      || 1;
        this.showResumeBanner  = false;
        this._pendingState     = null;
        // If we're resuming mid-extraction or mid-generation, restart polling
        if (this.currentStep === 2 && this.extractJobId) this.isExtracting = true;
        if (this.currentStep === 5 && this.xmlJobId) { /* tracker auto-polls */ }
    }

    handleDismissResume() {
        this.showResumeBanner = false;
        this._pendingState    = null;
    }

    // ── Auto-save helper ───────────────────────────────────────────────────────
    async _save(runStatus) {
        try {
            await saveRunState({
                state: {
                    quarterYear:     this.quarterYear,
                    currentStep:     this.currentStep,
                    dateLabel:       this.dateLabel,
                    extractJobId:    this.extractJobId,
                    extractedCount:  this.extractedCount,
                    xmlJobId:        this.xmlJobId,
                    runStatus:       runStatus || 'In Progress',
                    selectedQuarter: this.selectedQuarter,
                    selectedYear:    this.selectedYear
                }
            });
        } catch(e) {
            console.error('Failed to save run state:', e);
        }
    }

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
        } catch(e) { this.dateLabel = ''; }
    }

    async handleExtract() {
        const rtOk = await recordTypeExists({ quarterYear: this.quarterYear });
        if (!rtOk) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Record Type Missing',
                message: `No Record Type "${this.quarterYear}" exists on SBA 641 Output. Please create it in Setup.`,
                variant: 'error', mode: 'sticky'
            }));
            return;
        }
        this.currentStep  = 2;
        this.isExtracting = true;
        await this._save('In Progress');
        try {
            this.extractJobId = await extractSessions({ quarterYear: this.quarterYear });
            await this._save('In Progress');
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Extraction Error',
                message: e.body?.message || e.message, variant: 'error'
            }));
            this.currentStep  = 1;
            this.isExtracting = false;
        }
    }

    // ── Step 2: Extract complete ───────────────────────────────────────────────
    async handleExtractComplete(e) {
        const { status } = e.detail;
        this.isExtracting = false;
        if (status === 'Completed') {
            try { this.extractedCount = await getOutputCount({ quarterYear: this.quarterYear }); }
            catch(err) { this.extractedCount = 0; }
            if (this.extractedCount === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'No Records Found',
                    message: `No sessions found for ${this.quarterYear}. Check the date range or session data.`,
                    variant: 'warning', mode: 'sticky'
                }));
            }
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Extraction Failed',
                message: `Batch job ended with status: ${status}`,
                variant: 'error'
            }));
        }
        await this._save('In Progress');
    }

    // ── Step 3: Validate ───────────────────────────────────────────────────────
    async handleValidate() {
        this.currentStep  = 3;
        this.isValidating = true;
        try {
            const res = await validateQuarter({ quarterYear: this.quarterYear });
            this.totalRecords      = res.totalRecords;
            this.errorCount        = res.errorCount;
            this.warningCount      = res.warningCount;
            this.validationResults = res.results;
            await this._save('In Progress');
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: e.body?.message || e.message, variant: 'error'
            }));
            this.currentStep = 2;
        } finally {
            this.isValidating = false;
        }
    }

    async handleProceedToReview() {
        this.currentStep = 4;
        await this._save('In Progress');
    }

    // ── Step 5: Generate XML ───────────────────────────────────────────────────
    async handleGenerate() {
        try {
            this.xmlJobId = await generateXml({
                quarterYear: this.quarterYear, reportType: 'Counseling'
            });
            this.currentStep = 5;
            await this._save('In Progress');
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Generation Error',
                message: e.body?.message || e.message, variant: 'error'
            }));
        }
    }

    async handleJobComplete(e) {
        const { status } = e.detail;
        await this._save(status === 'Completed' ? 'Complete' : 'Failed');
        this.dispatchEvent(new ShowToastEvent({
            title:   status === 'Completed' ? '\u2705 XML Generated' : 'Generation Failed',
            message: status === 'Completed'
                ? `641 XML for ${this.quarterYear} generated and emailed to you.`
                : `Batch ended with status: ${status}`,
            variant: status === 'Completed' ? 'success' : 'error',
            mode: 'sticky'
        }));
    }

    async handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
            await this._save('In Progress');
        }
    }

    async handleStartOver() {
        await clearRunState();
        this.currentStep       = 1;
        this.selectedQuarter   = '';
        this.dateLabel         = '';
        this.extractJobId      = null;
        this.extractedCount    = 0;
        this.xmlJobId          = null;
        this.validationResults = [];
        this.errorCount        = 0;
        this.warningCount      = 0;
        this.showResumeBanner  = false;
    }
}
