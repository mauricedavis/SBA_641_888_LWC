import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class NexusReportValidationPanel extends NavigationMixin(LightningElement) {
    @api validationResults = [];
    @api errorCount   = 0;
    @api warningCount = 0;

    get hasResults() { return this.validationResults && this.validationResults.length > 0; }

    get errors() {
        return this.validationResults
            .filter(r => r.severity === 'ERROR')
            .map(r => ({ ...r, recordUrl: `/lightning/r/SBA_641_Output__c/${r.recordId}/view` }));
    }

    get warnings() {
        return this.validationResults
            .filter(r => r.severity === 'WARNING')
            .map(r => ({ ...r, recordUrl: `/lightning/r/SBA_641_Output__c/${r.recordId}/view` }));
    }
}
