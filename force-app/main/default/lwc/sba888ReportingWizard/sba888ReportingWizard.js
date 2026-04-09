import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuarterDates   from '@salesforce/apex/SBA888ReportController.getQuarterDates';
import recordTypeExists  from '@salesforce/apex/SBA888ReportController.recordTypeExists';
import extractEvents     from '@salesforce/apex/SBA888ReportController.extractEvents';
import getOutputCount    from '@salesforce/apex/SBA888ReportController.getOutputCount';
import validateQuarter   from '@salesforce/apex/SBA888ReportController.validateQuarter';
import generateXml       from '@salesforce/apex/SBA888ReportController.generateXml';
import getXmlPartFiles   from '@salesforce/apex/SBA888ReportController.getXmlPartFiles';
import getUploadRecordId from '@salesforce/apex/SBA888ReportController.getUploadRecordId';

const QUARTER_OPTIONS = [
    { label: 'Q1 (Oct 1 \u2013 Dec 31)', value: 'Q1' },
    { label: 'Q2 (Jan 1 \u2013 Mar 31)', value: 'Q2' },
    { label: 'Q3 (Apr 1 \u2013 Jun 30)', value: 'Q3' },
    { label: 'Q4 (Jul 1 \u2013 Sep 30)', value: 'Q4' }
];

const YEAR_OPTIONS = [2024, 2025, 2026, 2027, 2028, 2029, 2030]
    .map(y => ({ label: String(y), value: String(y) }));

export default class Sba888ReportingWizard extends LightningElement {

    @track currentStep         = 1;
    @track selectedQuarter     = '';
    @track selectedYear        = String(new Date().getFullYear());
    @track dateLabel           = '';
    @track existingRecordCount = 0;
    @track existingPartCount   = 0;

    // Step 2 — Extract
    @track isExtracting        = false;
    @track extractJobId        = null;
    @track extractedCount      = 0;

    // Step 3 — Validate
    @track isValidating        = false;
    @track validationResults   = [];
    @track errorCount          = 0;
    @track warningCount        = 0;

    // Step 5 — Generate
    @track xmlJobId            = null;
    @track xmlComplete         = false;
    @track showDownloadButton  = false;
    @track isMerging           = false;
    @track mergeComplete       = false;
    @track mergeStatus         = '';

    get isStep1()             { return this.currentStep === 1; }
    get isStep2()             { return this.currentStep === 2; }
    get isStep3()             { return this.currentStep === 3; }
    get isStep4()             { return this.currentStep === 4; }
    get isStep5()             { return this.currentStep === 5; }
    get currentStepStr()      { return String(this.currentStep); }
    get showValidationPanel() { return this.currentStep >= 3 && this.validationResults.length > 0; }
    get quarterYear() {
        return this.selectedQuarter && this.selectedYear
            ? (this.selectedQuarter + '_' + this.selectedYear) : '';
    }
    get quarterOptions()        { return QUARTER_OPTIONS; }
    get yearOptions()           { return YEAR_OPTIONS; }
    get isNextDisabled()        { return !this.selectedQuarter || !this.selectedYear; }
    get noRecordsExtracted()    { return this.extractedCount === 0; }
    get hasErrors()             { return this.errorCount > 0; }
    get hasWarnings()           { return this.warningCount > 0; }
    get generateButtonVariant() { return this.existingPartCount > 0 ? 'neutral' : 'brand'; }

    handleQuarterChange(e) { this.selectedQuarter = e.detail.value; this._updateDateLabel(); }
    handleYearChange(e)    { this.selectedYear    = e.detail.value; this._updateDateLabel(); }

    async _updateDateLabel() {
        if (!this.selectedQuarter || !this.selectedYear) return;
        try {
            const dates = await getQuarterDates({ quarterYear: this.quarterYear });
            this.dateLabel = dates.label;
            const cnt = await getOutputCount({ quarterYear: this.quarterYear });
            this.existingRecordCount = cnt || 0;
            const parts = await getXmlPartFiles({ quarterYear: this.quarterYear });
            this.existingPartCount = parts ? parts.length : 0;
        } catch(e) {
            this.dateLabel = ''; this.existingRecordCount = 0; this.existingPartCount = 0;
        }
    }

    async handleSkipToValidate() {
        this.extractedCount = this.existingRecordCount;
        this.currentStep    = 3;
        await this.handleValidate();
    }

    async handleReGenerate() {
        this.extractedCount    = this.existingRecordCount;
        this.existingPartCount = 0;
        this.currentStep       = 4;
    }

    async handleExtract() {
        const rtOk = await recordTypeExists({ quarterYear: this.quarterYear });
        if (!rtOk) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Record Type Missing',
                message: 'No Record Type "' + this.quarterYear + '" on SBA 888 Output.',
                variant: 'error', mode: 'sticky' }));
            return;
        }
        this.currentStep = 2; this.isExtracting = true; this.existingRecordCount = 0;
        try {
            this.extractJobId = await extractEvents({ quarterYear: this.quarterYear });
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Extraction Error',
                message: e.body ? e.body.message : e.message, variant: 'error' }));
            this.currentStep = 1; this.isExtracting = false;
        }
    }

    async handleExtractComplete(e) {
        const { status } = e.detail;
        this.isExtracting = false;
        if (status === 'Completed') {
            try { this.extractedCount = await getOutputCount({ quarterYear: this.quarterYear }); }
            catch(err) { this.extractedCount = 0; }
            // Auto-advance to validate
            this.currentStep = 3;
            await this.handleValidate();
        } else {
            this.dispatchEvent(new ShowToastEvent({ title: 'Extraction Failed',
                message: 'Batch ended with status: ' + status, variant: 'error' }));
        }
    }

    async handleValidate() {
        this.currentStep  = 3;
        this.isValidating = true;
        this.validationResults = [];
        this.errorCount   = 0;
        this.warningCount = 0;
        try {
            const res = await validateQuarter({ quarterYear: this.quarterYear });
            this.extractedCount    = res.totalRecords;
            this.errorCount        = res.errorCount;
            this.warningCount      = res.warningCount;
            this.validationResults = res.results || [];
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Validation Error',
                message: e.body ? e.body.message : e.message, variant: 'error' }));
        } finally {
            this.isValidating = false;
        }
    }

    async handleProceedToReview() {
        this.currentStep = 4;
        try {
            const parts = await getXmlPartFiles({ quarterYear: this.quarterYear });
            this.existingPartCount = parts ? parts.length : 0;
        } catch(e) { this.existingPartCount = 0; }
    }

    async handleGenerate() {
        try {
            this.xmlJobId    = await generateXml({ quarterYear: this.quarterYear });
            this.currentStep = 5;
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Generation Error',
                message: e.body ? e.body.message : e.message, variant: 'error' }));
        }
    }

    async handleJobComplete(e) {
        const { status } = e.detail;
        if (status === 'Completed') {
            this.xmlComplete = true; this.showDownloadButton = true;
            try {
                const parts = await getXmlPartFiles({ quarterYear: this.quarterYear });
                this.existingPartCount = parts ? parts.length : 0;
            } catch(err) { this.existingPartCount = 0; }
        } else {
            this.dispatchEvent(new ShowToastEvent({ title: 'Generation Failed',
                message: 'Batch ended with status: ' + status, variant: 'error', mode: 'sticky' }));
        }
    }

    async handleDownloadAndMerge() {
        this.isMerging = true; this.mergeComplete = false;
        this.mergeStatus = 'Opening download page\u2026';
        try {
            const uploadId = await getUploadRecordId({ quarterYear: this.quarterYear });
            if (!uploadId) {
                this.mergeStatus = 'No upload record found. Please re-generate XML.';
                this.isMerging   = false;
                return;
            }
            window.open('/apex/SBA888_XMLMerge?uploadId=' + uploadId, '_blank');
            this.isMerging     = false;
            this.mergeComplete = true;
            this.mergeStatus   = '\u2705 Download page opened in new tab. Follow the instructions there.';
        } catch(err) {
            this.isMerging   = false;
            this.mergeStatus = 'Error: ' + (err.body ? err.body.message : err.message || String(err));
        }
    }

    handleBack() {
        if (this.currentStep > 1) this.currentStep--;
    }

    handleStartOver() {
        this.currentStep = 1; this.selectedQuarter = ''; this.dateLabel = '';
        this.existingRecordCount = 0; this.existingPartCount = 0;
        this.extractJobId = null; this.extractedCount = 0;
        this.xmlJobId = null; this.validationResults = [];
        this.errorCount = 0; this.warningCount = 0;
        this.mergeComplete = false; this.mergeStatus = '';
        this.xmlComplete = false; this.showDownloadButton = false;
    }
}