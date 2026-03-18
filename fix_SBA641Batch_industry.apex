ApexClass cls = [SELECT Id, Body FROM ApexClass WHERE Name = 'SBA641Batch' LIMIT 1];

String oldText = '\'56 Administrative and Support\' => \'Administrative and Support\'';
String newText = '\'56 Administrative and Support\' => \'Administrative and Support\'' + ',\n' +
                 '                \'56 Waste Management and Remediation/Administrative and Support\' => \'Administrative and Support\'' + ',\n' +
                 '                \'Waste Management & Remediation Services\' => \'Waste Management and Remediation Services\'' + ',\n' +
                 '                \'Waste Management and Remediation Services\' => \'Waste Management and Remediation Services\'';

if (!cls.Body.contains(oldText)) {
    System.debug('ERROR: search text not found in class body');
} else {
    String updatedBody = cls.Body.replace(oldText, newText);
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v63.0/tooling/sobjects/ApexClass/' + cls.Id);
    req.setMethod('PATCH');
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(new Map<String,String>{'Body' => updatedBody}));
    HttpResponse res = new Http().send(req);
    System.debug('Status: ' + res.getStatusCode());
    System.debug('Body: ' + res.getBody());
}
