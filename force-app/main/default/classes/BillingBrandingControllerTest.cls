@IsTest
private class BillingBrandingControllerTest {
    @IsTest
    static void configuresLogoAndColor() {
        BillingEntity__c entity = new BillingEntity__c(
            Name = 'Société Marque',
            RegistrationNumber__c = '123456789',
            Address__c = '1 rue du Test',
            DefaultPaymentTermsDays__c = 30
        );
        insert entity;
        ContentVersion version = new ContentVersion(
            Title = 'logo-test',
            PathOnClient = 'logo-test.png',
            VersionData = Blob.valueOf('image-test'),
            FirstPublishLocationId = entity.Id
        );
        insert version;
        version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id];

        Test.startTest();
        BillingBrandingController.BrandingConfig withLogo =
            BillingBrandingController.selectLogo(entity.Id, version.ContentDocumentId);
        BillingBrandingController.BrandingConfig withColor =
            BillingBrandingController.savePrimaryColor(entity.Id, '#C23934');
        BillingBrandingController.BrandingConfig withoutLogo =
            BillingBrandingController.clearLogo(entity.Id);
        Test.stopTest();

        System.assertEquals(version.ContentDocumentId, withLogo.logoDocumentId);
        System.assertEquals('#C23934', withColor.primaryColor);
        System.assertEquals(null, withoutLogo.logoDocumentId);
    }

    @IsTest
    static void normalizesUnsafeColors() {
        System.assertEquals('#0B5CAB', BillingBrandingController.normalizeColor('red'));
        System.assertEquals('#0B5CAB', BillingBrandingController.normalizeColor(null));
        System.assertEquals('#AABBCC', BillingBrandingController.normalizeColor('#aabbcc'));
    }
}
