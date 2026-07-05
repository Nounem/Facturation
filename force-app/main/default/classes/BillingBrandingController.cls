public with sharing class BillingBrandingController {
    public class BrandingConfig {
        @AuraEnabled public String entityName;
        @AuraEnabled public String primaryColor;
        @AuraEnabled public Id logoDocumentId;
        @AuraEnabled public String logoFileName;
        @AuraEnabled public String logoPreviewUrl;
    }

    @AuraEnabled(cacheable=true)
    public static BrandingConfig getConfig(Id billingEntityId) {
        if (billingEntityId == null) {
            throw new AuraHandledException('L’entité de facturation est requise.');
        }
        BillingEntity__c entity = [
            SELECT Id, Name, PdfPrimaryColor__c, LogoContentDocumentId__c
            FROM BillingEntity__c WHERE Id = :billingEntityId
        ];
        BrandingConfig config = new BrandingConfig();
        config.entityName = entity.Name;
        config.primaryColor = normalizeColor(entity.PdfPrimaryColor__c);

        if (String.isNotBlank(entity.LogoContentDocumentId__c)) {
            try {
                ContentDocument document = [
                    SELECT Id, Title, LatestPublishedVersionId
                    FROM ContentDocument
                    WHERE Id = :entity.LogoContentDocumentId__c
                    LIMIT 1
                ];
                config.logoDocumentId = document.Id;
                config.logoFileName = document.Title;
                config.logoPreviewUrl = renditionUrl(document.LatestPublishedVersionId);
            } catch (Exception ignored) {
                // A deleted or inaccessible file must not prevent configuration.
            }
        }
        return config;
    }

    @AuraEnabled
    public static BrandingConfig selectLogo(Id billingEntityId, Id contentDocumentId) {
        if (billingEntityId == null || contentDocumentId == null) {
            throw new AuraHandledException('Sélectionnez un fichier logo valide.');
        }
        ContentDocument document = [
            SELECT Id, FileType FROM ContentDocument WHERE Id = :contentDocumentId
        ];
        if (!new Set<String>{ 'PNG', 'JPG', 'JPEG' }.contains(document.FileType)) {
            throw new AuraHandledException('Le logo doit être une image PNG ou JPG.');
        }
        update new BillingEntity__c(
            Id = billingEntityId,
            LogoContentDocumentId__c = String.valueOf(document.Id)
        );
        return getConfig(billingEntityId);
    }

    @AuraEnabled
    public static BrandingConfig savePrimaryColor(Id billingEntityId, String primaryColor) {
        if (billingEntityId == null) {
            throw new AuraHandledException('L’entité de facturation est requise.');
        }
        String normalized = normalizeColor(primaryColor);
        if (String.isBlank(primaryColor) || normalized != primaryColor.toUpperCase()) {
            throw new AuraHandledException('Utilisez une couleur hexadécimale au format #RRGGBB.');
        }
        update new BillingEntity__c(Id = billingEntityId, PdfPrimaryColor__c = normalized);
        return getConfig(billingEntityId);
    }

    @AuraEnabled
    public static BrandingConfig clearLogo(Id billingEntityId) {
        if (billingEntityId == null) {
            throw new AuraHandledException('L’entité de facturation est requise.');
        }
        update new BillingEntity__c(Id = billingEntityId, LogoContentDocumentId__c = null);
        return getConfig(billingEntityId);
    }

    @TestVisible
    private static String normalizeColor(String value) {
        String color = String.isBlank(value) ? '#0B5CAB' : value.trim().toUpperCase();
        return Pattern.matches('^#[0-9A-F]{6}$', color) ? color : '#0B5CAB';
    }

    private static String renditionUrl(Id versionId) {
        return '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId='
            + EncodingUtil.urlEncode(String.valueOf(versionId), 'UTF-8');
    }
}
