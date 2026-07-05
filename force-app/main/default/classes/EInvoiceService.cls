public with sharing class EInvoiceService {
    public class EInvoiceException extends Exception {}

    @AuraEnabled
    public static EInvoiceTransmission__c prepare(Id invoiceId) {
        List<EInvoiceTransmission__c> existing = [
            SELECT Id, Name, Provider__c, Status__c, ExternalReference__c,
                   PayloadDocumentId__c
            FROM EInvoiceTransmission__c
            WHERE Invoice__c = :invoiceId AND Status__c IN ('Prepared', 'Pending', 'Submitted', 'Accepted')
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];

        Invoice__c invoice = [
            SELECT Id, InvoiceNumber__c, IsLocked__c, RecipientType__c,
                   RecipientSiret__c, CommitmentNumber__c, ServiceCode__c,
                   BillingFramework__c
            FROM Invoice__c WHERE Id = :invoiceId
        ];
        if (!invoice.IsLocked__c || String.isBlank(invoice.InvoiceNumber__c)) {
            throw new EInvoiceException('Émettez la facture avant de préparer sa transmission électronique.');
        }

        String provider = invoice.RecipientType__c == 'PublicSector'
            ? 'ChorusPro'
            : 'AccreditedPlatform';
        validateRoutingData(invoice, provider);

        Id documentId = findOrCreatePdf(invoice);
        EInvoiceTransmission__c transmission = new EInvoiceTransmission__c(
            Invoice__c = invoice.Id,
            Provider__c = provider,
            Status__c = 'Prepared',
            PayloadDocumentId__c = String.valueOf(documentId)
        );
        insert transmission;
        return transmission;
    }

    private static void validateRoutingData(Invoice__c invoice, String provider) {
        if (provider == 'ChorusPro') {
            if (String.isBlank(invoice.RecipientSiret__c) ||
                !Pattern.matches('^[0-9]{14}$', invoice.RecipientSiret__c)) {
                throw new EInvoiceException('Un SIRET destinataire à 14 chiffres est requis pour Chorus Pro.');
            }
            if (String.isBlank(invoice.BillingFramework__c)) {
                throw new EInvoiceException('Le cadre de facturation Chorus Pro est requis.');
            }
        }
    }

    private static Id findOrCreatePdf(Invoice__c invoice) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :invoice.Id
            ORDER BY SystemModstamp DESC
        ];
        for (ContentDocumentLink link : links) {
            if (link.ContentDocument.Title == invoice.InvoiceNumber__c) {
                return link.ContentDocumentId;
            }
        }
        return InvoicePdfController.generateAndAttach(invoice.Id);
    }
}
