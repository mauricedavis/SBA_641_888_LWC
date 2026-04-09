import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class NexusReportValidationPanel extends NavigationMixin(LightningElement) {
    @api validationResults = [];
    @api errorCount   = 0;
    @api warningCount = 0;
    @api objectApiName = 'SBA_641_Output__c';

    get hasResults() { return this.validationResults && this.validationResults.length > 0; }

    // For 641: eventId is a Session__c Id (stored in PartnerSessionNumber_Counselor__c)
    // For 888: eventId is a conference360__Event__c Id
    get _relatedObjectApiName() {
        return this.objectApiName === 'SBA_641_Output__c'
            ? 'Session__c'
            : 'conference360__Event__c';
    }

    get _relatedObjectLabel() {
        return this.objectApiName === 'SBA_641_Output__c' ? 'Session' : 'Event';
    }

    _buildRow(r) {
        return {
            recordId:              r.recordId,
            eventId:               r.eventId,
            partnerTrainingNumber: r.partnerTrainingNumber,
            severity:              r.severity,
            field:                 r.field,
            message:               r.message,
            recordUrl: `/lightning/r/${this.objectApiName}/${r.recordId}/view`,
            eventUrl:  r.eventId ? `/lightning/r/${this._relatedObjectApiName}/${r.eventId}/view` : '',
            eventLabel: this._relatedObjectLabel
        };
    }

    get errors() {
        return this.validationResults
            .filter(r => r.severity === 'ERROR')
            .map(r => this._buildRow(r));
    }

    get warnings() {
        return this.validationResults
            .filter(r => r.severity === 'WARNING')
            .map(r => this._buildRow(r));
    }
}