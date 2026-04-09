import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class NexusReportValidationPanel extends NavigationMixin(LightningElement) {
    @api validationResults = [];
    @api errorCount   = 0;
    @api warningCount = 0;
    @api objectApiName = 'SBA_641_Output__c';

    get hasResults() { return this.validationResults && this.validationResults.length > 0; }

    get errors() {
        return this.validationResults
            .filter(r => r.severity === 'ERROR')
            .map(r => ({
                recordId:              r.recordId,
                eventId:               r.eventId,
                partnerTrainingNumber: r.partnerTrainingNumber,
                severity:              r.severity,
                field:                 r.field,
                message:               r.message,
                recordUrl: `/lightning/r/${this.objectApiName}/${r.recordId}/view`,
                eventUrl:  r.eventId ? `/lightning/r/conference360__Event__c/${r.eventId}/view` : ''
            }));
    }

    get warnings() {
        return this.validationResults
            .filter(r => r.severity === 'WARNING')
            .map(r => ({
                recordId:              r.recordId,
                eventId:               r.eventId,
                partnerTrainingNumber: r.partnerTrainingNumber,
                severity:              r.severity,
                field:                 r.field,
                message:               r.message,
                recordUrl: `/lightning/r/${this.objectApiName}/${r.recordId}/view`,
                eventUrl:  r.eventId ? `/lightning/r/conference360__Event__c/${r.eventId}/view` : ''
            }));
    }
}