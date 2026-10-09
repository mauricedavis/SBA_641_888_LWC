import { LightningElement, api, track } from 'lwc';
import pollJobStatus from '@salesforce/apex/SBA641ReportController.pollJobStatus';

const POLL_MS = 3000;

// Statuses that mean the job will never update again — fire jobcomplete
// so the parent can recover rather than polling forever.
const TERMINAL_STATUSES = new Set(['Completed', 'Failed', 'Aborted', 'NotFound']);

export default class NexusReportProgressTracker extends LightningElement {
    @api jobId;
    @track status           = 'Queued';
    @track percentComplete  = 0;
    @track totalBatches     = 0;
    @track batchesProcessed = 0;
    @track extendedStatus   = '';
    @track isComplete       = false;
    _timer;

    connectedCallback()    { this._timer = setInterval(() => this._poll(), POLL_MS); }
    disconnectedCallback() { clearInterval(this._timer); }

    async _poll() {
        if (!this.jobId) return;
        try {
            const r = await pollJobStatus({ jobId: this.jobId });
            this.status           = r.status;
            this.percentComplete  = r.percentComplete  || 0;
            this.totalBatches     = r.totalBatches     || 0;
            this.batchesProcessed = r.batchesProcessed || 0;
            this.extendedStatus   = r.extendedStatus   || '';
            this.isComplete       = r.isComplete       || false;

            // Treat NotFound as terminal — the job no longer exists (e.g. a stale
            // job ID restored from run state after a sandbox page reload). Without
            // this guard the tracker would poll indefinitely and block the wizard.
            if (TERMINAL_STATUSES.has(r.status)) {
                clearInterval(this._timer);
                this.dispatchEvent(new CustomEvent('jobcomplete', { detail: { status: this.status } }));
            }
        } catch (e) { console.error('Poll error:', e); }
    }
}
