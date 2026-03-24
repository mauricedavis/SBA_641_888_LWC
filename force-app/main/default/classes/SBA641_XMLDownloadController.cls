/**
 * SBA641_XMLDownloadController
 * Serves ONE XML part file at a time to avoid heap limits.
 * URL: /apex/SBA641_XMLDownload?cvId={ContentVersion.Id}
 * The LWC fetches each part sequentially and merges them client-side.
 *
 * Note: This VF page is same-origin with the LWC, so fetch() from
 * a VF page URL IS allowed (unlike direct ContentVersion URLs).
 */
public class SBA641_XMLDownloadController {

    public String xmlContent { get; private set; }

    public SBA641_XMLDownloadController() {
        xmlContent = '';
    }

    public PageReference streamXml() {
        String cvId = ApexPages.currentPage().getParameters().get('cvId');
        if (String.isBlank(cvId)) {
            xmlContent = '<!-- Error: cvId parameter required -->';
            return null;
        }
        try {
            ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];
            xmlContent = cv.VersionData.toString();
        } catch(Exception e) {
            xmlContent = '<!-- Error: ' + e.getMessage() + ' -->';
        }
        return null;
    }
}
