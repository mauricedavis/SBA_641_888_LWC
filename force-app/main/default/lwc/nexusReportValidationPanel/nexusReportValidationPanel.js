import { LightningElement, api } from 'lwc';
export default class NexusReportValidationPanel extends LightningElement {
    @api validationResults = [];
    @api errorCount   = 0;
    @api warningCount = 0;
    get hasResults() { return this.validationResults && this.validationResults.length > 0; }
    get errors()   { return this.validationResults.filter(r => r.severity === 'ERROR'); }
    get warnings() { return this.validationResults.filter(r => r.severity === 'WARNING'); }
}
