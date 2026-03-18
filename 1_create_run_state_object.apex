// Create SBA641_Run_State__c object and all fields via Tooling API
String base = URL.getOrgDomainUrl().toExternalForm();
String token = UserInfo.getSessionId();

// Helper to POST to Tooling API
String doPost(String endpoint, String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(base + '/services/data/v63.0/tooling/' + endpoint);
    req.setMethod('POST');
    req.setHeader('Authorization', 'Bearer ' + token);
    req.setHeader('Content-Type', 'application/json');
    req.setBody(body);
    HttpResponse res = new Http().send(req);
    System.debug(endpoint + ' -> ' + res.getStatusCode() + ': ' + res.getBody().left(200));
    return res.getBody();
}

// Step 1: Create the custom object
String objBody = JSON.serialize(new Map<String,Object>{
    'FullName' => 'SBA641_Run_State__c',
    'Metadata' => new Map<String,Object>{
        'label' => 'SBA 641 Run State',
        'pluralLabel' => 'SBA 641 Run States',
        'nameField' => new Map<String,Object>{
            'type' => 'AutoNumber',
            'label' => 'Run State Name',
            'displayFormat' => 'RS-{000000}'
        },
        'deploymentStatus' => 'Deployed',
        'sharingModel' => 'Private',
        'description' => 'Persists 641 reporting wizard state across page navigation and browser refreshes.'
    }
});
String objResult = doPost('sobjects/CustomObject', objBody);
System.debug('Object created: ' + objResult);
