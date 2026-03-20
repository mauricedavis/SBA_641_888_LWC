ApexClass cls = [SELECT Id, Body FROM ApexClass WHERE Name = 'SBA641Batch' LIMIT 1];

// Find what's around line 1090 to identify the right anchor
List<String> lines = cls.Body.split('\n');
System.debug('Total lines: ' + lines.size());
for (Integer i = 1085; i < Math.min(1095, lines.size()); i++) {
    System.debug('Line ' + i + ': ' + lines[i]);
}

// Check if our previous patch is present
System.debug('Waste Management patch exists: ' + cls.Body.contains('Waste Management & Remediation Services'));
System.debug('Not Set mapping exists: ' + cls.Body.contains('Not Set'));
