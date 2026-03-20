ApexClass cls = [SELECT Id, Body FROM ApexClass WHERE Name = 'SBA641Batch' LIMIT 1];

String oldText = '\'Not Set\' => \'Other Services (except Public Administration)\'';
String newText = '\'Not Set\' => \'Other Services (except Public Administration)\','
    + '\n                \'Waste Management & Remediation Services\' => \'Waste Management and Remediation Services\','
    + '\n                \'Waste Management and Remediation Services\' => \'Waste Management and Remediation Services\','
    + '\n                \'56 Waste Management and Remediation/Administrative and Support\' => \'Administrative and Support\'';

if (!cls.Body.contains(oldText)) {
    System.debug('ERROR: search string not found in SBA641Batch body');
} else {
    String updated = cls.Body.replace(oldText, newText);
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm()
        + '/services/data/v63.0/tooling/sobjects/ApexClass/' + cls.Id);
    req.setMethod('PATCH');
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(new Map<String,String>{'Body' => updated}));
    HttpResponse res = new Http().send(req);
    System.debug('Status: ' + res.getStatusCode());
    System.debug('Response: ' + res.getBody());
}
