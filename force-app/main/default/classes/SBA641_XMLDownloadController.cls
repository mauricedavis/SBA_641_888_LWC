/**
 * SBA641_XMLDownloadController
 * Serves ONE ContentVersion at a time via cvId parameter.
 * URL: /apex/SBA641_XMLDownload?cvId={ContentVersion.Id}
 * Each part is ~4MB — well within 12MB heap for a single part.
 */
public class SBA641_XMLDownloadController {
    public String xmlContent { get; private set; }
    public SBA641_XMLDownloadController() { xmlContent = ''; }
    public PageReference streamXml() {
        String cvId = ApexPages.currentPage().getParameters().get('cvId');
        if (String.isBlank(cvId)) { xmlContent = '<!-- cvId required -->'; return null; }
        try {
            ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];
            xmlContent = cv.VersionData.toString();
        } catch(Exception e) { xmlContent = '<!-- Error: ' + e.getMessage() + ' -->'; }
        return null;
    }
}
