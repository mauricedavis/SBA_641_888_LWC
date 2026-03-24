import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuarterDates   from '@salesforce/apex/SBA641ReportController.getQuarterDates';
import recordTypeExists  from '@salesforce/apex/SBA641ReportController.recordTypeExists';
import extractSessions   from '@salesforce/apex/SBA641ReportController.extractSessions';
import getOutputCount    from '@salesforce/apex/SBA641ReportController.getOutputCount';
import validateQuarter   from '@salesforce/apex/SBA641ReportController.validateQuarter';
import generateXml       from '@salesforce/apex/SBA641ReportController.generateXml';
import getXmlPartFiles   from '@salesforce/apex/SBA641ReportController.getXmlPartFiles';
import getUploadRecordId from '@salesforce/apex/SBA641ReportController.getUploadRecordId';
import getVfBaseUrl      from '@salesforce/apex/SBA641ReportController.getVfBaseUrl';
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

    @track currentStep         = 1;
    @track selectedQuarter     = '';
    @track selectedYear        = String(new Date().getFullYear());
    @track dateLabel           = '';
    @track existingRecordCount = 0;
    @track existingPartCount   = 0;

    @track isExtracting        = false;
    @track extractJobId        = null;
    @track extractedCount      = 0;

    @track isValidating        = false;
    @track totalRecords        = 0;
    @track errorCount          = 0;
    @track warningCount        = 0;
    @track validationResults   = [];

    @track xmlJobId            = null;
    @track xmlComplete         = false;
    @track showDownloadButton  = false;
    @track isMerging           = false;
    @track mergeComplete       = false;
    @track mergeStatus         = '';

    connectedCallback() { this._tryLoadRunState(); }

    async _tryLoadRunState() {
        try {
            const state = await loadRunState();
            if (state && state.currentStep > 1) {
                this.selectedQuarter = state.selectedQuarter || '';
                this.selectedYear    = state.selectedYear    || String(new Date().getFullYear());
                this.dateLabel       = state.dateLabel       || '';
                this.extractJobId    = state.extractJobId    || null;
                this.extractedCount  = state.extractedCount  || 0;
                this.xmlJobId        = state.xmlJobId        || null;
                this.currentStep     = state.currentStep     || 1;
                if (this.currentStep === 2 && this.extractJobId) this.isExtracting = true;
                if (this.currentStep >= 4 && this.quarterYear) {
                    try {
                        const parts = await getXmlPartFiles({ quarterYear: this.quarterYear });
                        this.existingPartCount = parts ? parts.length : 0;
                    } catch(e) { this.existingPartCount = 0; }
                }
            }
        } catch(e) { /* no run state */ }
    }

    async _save(status) {
        try {
            await saveRunState({ state: {
                quarterYear: this.quarterYear, currentStep: this.currentStep,
                dateLabel: this.dateLabel, extractJobId: this.extractJobId,
                extractedCount: this.extractedCount, xmlJobId: this.xmlJobId,
                runStatus: status || 'In Progress',
                selectedQuarter: this.selectedQuarter, selectedYear: this.selectedYear
            }});
        } catch(e) {}
    }

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
        } catch(e) { this.dateLabel = ''; this.existingRecordCount = 0; this.existingPartCount = 0; }
    }

    async handleSkipToValidate() {
        this.extractedCount = this.existingRecordCount;
        this.currentStep    = 3;
        await this._save('In Progress');
        await this.handleValidate();
    }

    async handleReGenerate() {
        this.extractedCount    = this.existingRecordCount;
        this.existingPartCount = 0;
        this.currentStep       = 4;
        await this._save('In Progress');
    }

    async handleExtract() {
        const rtOk = await recordTypeExists({ quarterYear: this.quarterYear });
        if (!rtOk) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Record Type Missing',
                message: 'No Record Type "' + this.quarterYear + '" on SBA 641 Output.',
                variant: 'error', mode: 'sticky' }));
            return;
        }
        this.currentStep = 2; this.isExtracting = true; this.existingRecordCount = 0;
        await this._save('In Progress');
        try {
            this.extractJobId = await extractSessions({ quarterYear: this.quarterYear });
            await this._save('In Progress');
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
        } else {
            this.dispatchEvent(new ShowToastEvent({ title: 'Extraction Failed',
                message: 'Batch ended with status: ' + status, variant: 'error' }));
        }
        await this._save('In Progress');
    }

    async handleValidate() {
        this.currentStep = 3; this.isValidating = true;
        try {
            const res = await validateQuarter({ quarterYear: this.quarterYear });
            this.totalRecords = res.totalRecords; this.errorCount = res.errorCount;
            this.warningCount = res.warningCount; this.validationResults = res.results;
            await this._save('In Progress');
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Validation Error',
                message: e.body ? e.body.message : e.message, variant: 'error' }));
            this.currentStep = 2;
        } finally { this.isValidating = false; }
    }

    async handleProceedToReview() {
        this.currentStep = 4;
        await this._save('In Progress');
        try {
            const parts = await getXmlPartFiles({ quarterYear: this.quarterYear });
            this.existingPartCount = parts ? parts.length : 0;
        } catch(e) { this.existingPartCount = 0; }
    }

    async handleGenerate() {
        try {
            this.xmlJobId    = await generateXml({ quarterYear: this.quarterYear, reportType: 'Counseling' });
            this.currentStep = 5;
            await this._save('In Progress');
        } catch(e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Generation Error',
                message: e.body ? e.body.message : e.message, variant: 'error' }));
        }
    }

    async handleJobComplete(e) {
        const { status } = e.detail;
        await this._save(status === 'Completed' ? 'Complete' : 'Failed');
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

    // ── Download & Merge ───────────────────────────────────────────────────────
    // Uses VF base URL (vf.force.com) to avoid lightning.force.com redirect/CORS
    async handleDownloadAndMerge() {
        this.isMerging = true; this.mergeComplete = false;
        this.mergeStatus = 'Preparing download\u2026';
        try {
            const [parts, vfBase] = await Promise.all([
                getXmlPartFiles({ quarterYear: this.quarterYear }),
                getVfBaseUrl()
            ]);

            if (!parts || parts.length === 0) {
                this.mergeStatus = 'No part files found. Please re-generate XML.';
                this.isMerging   = false;
                return;
            }

            const textParts = [];
            for (let i = 0; i < parts.length; i++) {
                this.mergeStatus = 'Downloading part ' + (i + 1) + ' of ' + parts.length + '\u2026';
                // Use vf.force.com base URL directly — avoids cross-origin redirect
                const url  = vfBase + '/apex/SBA641_XMLDownload?cvId=' + parts[i].cvId;
                const resp = await fetch(url, { credentials: 'include' });
                if (!resp.ok) throw new Error('Part ' + (i + 1) + ' failed: HTTP ' + resp.status);
                textParts.push(await resp.text());
            }

            this.mergeStatus = 'Creating merged file\u2026';
            const blob    = new Blob(textParts, { type: 'application/xml' });
            const blobUrl = URL.createObjectURL(blob);
            const link    = document.createElement('a');
            link.href     = blobUrl;
            link.download = 'SBA641_Report_' + this.quarterYear + '.xml';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(blobUrl);

            this.isMerging          = false;
            this.mergeComplete      = true;
            this.mergeStatus        = '\u2705 Done! SBA641_Report_' + this.quarterYear + '.xml downloaded.';
            this.showDownloadButton = false;
            this.existingPartCount  = 0;

        } catch(err) {
            console.error('Download error:', err);
            this.isMerging   = false;
            this.mergeStatus = 'Error: ' + (err.message || String(err));
        }
    }

    async handleBack() {
        if (this.currentStep > 1) { this.currentStep--; await this._save('In Progress'); }
    }

    async handleStartOver() {
        try { await clearRunState(); } catch(e) {}
        this.currentStep = 1; this.selectedQuarter = ''; this.dateLabel = '';
        this.existingRecordCount = 0; this.existingPartCount = 0;
        this.extractJobId = null; this.extractedCount = 0;
        this.xmlJobId = null; this.validationResults = [];
        this.errorCount = 0; this.warningCount = 0;
        this.mergeComplete = false; this.mergeStatus = '';
        this.xmlComplete = false; this.showDownloadButton = false;
    }
}
