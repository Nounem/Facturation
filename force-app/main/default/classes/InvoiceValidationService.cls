public with sharing class InvoiceValidationService {
    public class InvoiceValidationException extends Exception {}

    public static void validateForIssue(Id invoiceId) {
        Invoice__c invoice = [
            SELECT Id, DocumentType__c, OriginalInvoice__c, CreditReason__c,
                   CustomerName__c, CustomerRegistrationNumber__c,
                   BillingStreet__c, BillingPostalCode__c, BillingCity__c,
                   BillingCountry__c, ServiceDate__c, OperationCategory__c,
                   RecipientType__c, RecipientSiret__c, TotalAmount__c,
                   BillingEntity__r.Name, BillingEntity__r.RegistrationNumber__c,
                   BillingEntity__r.Siret__c, BillingEntity__r.Address__c,
                   BillingEntity__r.EarlyPaymentTerms__c,
                   BillingEntity__r.LatePaymentPenaltyText__c,
                   BillingEntity__r.RecoveryFeeAmount__c,
                   OriginalInvoice__r.DocumentType__c,
                   OriginalInvoice__r.IsLocked__c,
                   OriginalInvoice__r.TotalAmount__c,
                   OriginalInvoice__r.CreditedAmount__c,
                   (SELECT Description__c, Quantity__c, UnitPrice__c,
                           DiscountPercent__c, TaxRate__c, GrossAmount__c
                    FROM Lines__r)
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];

        List<String> errors = new List<String>();
        requireText(invoice.BillingEntity__r.Name, 'raison sociale de l’émetteur', errors);
        requireConfigured(
            invoice.BillingEntity__r.RegistrationNumber__c,
            'SIREN de l’émetteur',
            errors
        );
        requireConfigured(invoice.BillingEntity__r.Address__c, 'adresse de l’émetteur', errors);
        if (!isDigits(invoice.BillingEntity__r.Siret__c, 14)) {
            errors.add('le SIRET de l’émetteur doit contenir 14 chiffres');
        }
        requireText(invoice.BillingEntity__r.EarlyPaymentTerms__c, 'conditions d’escompte', errors);
        requireText(invoice.BillingEntity__r.LatePaymentPenaltyText__c, 'pénalités de retard', errors);
        if (invoice.BillingEntity__r.RecoveryFeeAmount__c == null) {
            errors.add('l’indemnité forfaitaire de recouvrement est requise');
        }

        requireText(invoice.CustomerName__c, 'nom du client', errors);
        requireText(invoice.BillingStreet__c, 'adresse du client', errors);
        requireText(invoice.BillingPostalCode__c, 'code postal du client', errors);
        requireText(invoice.BillingCity__c, 'ville du client', errors);
        requireText(invoice.BillingCountry__c, 'pays du client', errors);
        if (invoice.RecipientType__c == 'PrivateBusiness' &&
            String.isBlank(invoice.CustomerRegistrationNumber__c)) {
            errors.add('le SIREN du client professionnel est requis');
        }
        if (invoice.RecipientType__c == 'PublicSector' &&
            !isDigits(invoice.RecipientSiret__c, 14)) {
            errors.add('le SIRET du destinataire public doit contenir 14 chiffres');
        }
        if (invoice.ServiceDate__c == null) errors.add('la date de prestation est requise');
        if (String.isBlank(invoice.OperationCategory__c)) {
            errors.add('la catégorie de l’opération est requise');
        }
        if (invoice.Lines__r.isEmpty()) {
            errors.add('au moins une ligne est requise');
        }
        Integer lineNumber = 0;
        for (InvoiceLine__c line : invoice.Lines__r) {
            lineNumber++;
            if (String.isBlank(line.Description__c)) {
                errors.add('ligne ' + lineNumber + ' : la description est requise');
            }
            if (line.Quantity__c == null || line.Quantity__c <= 0) {
                errors.add('ligne ' + lineNumber + ' : la quantité doit être positive');
            }
            if (line.UnitPrice__c == null || line.UnitPrice__c < 0) {
                errors.add('ligne ' + lineNumber + ' : le prix unitaire est invalide');
            }
            if (line.DiscountPercent__c != null &&
                (line.DiscountPercent__c < 0 || line.DiscountPercent__c > 100)) {
                errors.add('ligne ' + lineNumber + ' : la remise doit être comprise entre 0 et 100 %');
            }
            if (line.TaxRate__c == null || line.TaxRate__c < 0 || line.TaxRate__c > 100) {
                errors.add('ligne ' + lineNumber + ' : le taux de TVA est invalide');
            }
        }

        if (invoice.DocumentType__c == 'CreditNote') validateCreditNote(invoice, errors);
        if (!errors.isEmpty()) {
            throw new InvoiceValidationException(
                'Émission impossible : ' + String.join(errors, ' ; ') + '.'
            );
        }
    }

    private static void validateCreditNote(Invoice__c creditNote, List<String> errors) {
        if (creditNote.OriginalInvoice__c == null) {
            errors.add('la facture d’origine est requise pour un avoir');
            return;
        }
        if (String.isBlank(creditNote.CreditReason__c)) {
            errors.add('le motif de l’avoir est requis');
        }
        if (creditNote.OriginalInvoice__r.DocumentType__c != 'Invoice' ||
            !creditNote.OriginalInvoice__r.IsLocked__c) {
            errors.add('la facture d’origine doit être une facture émise');
            return;
        }
        Decimal alreadyCredited = creditNote.OriginalInvoice__r.CreditedAmount__c == null
            ? 0
            : creditNote.OriginalInvoice__r.CreditedAmount__c;
        Decimal remaining = creditNote.OriginalInvoice__r.TotalAmount__c - alreadyCredited;
        if (creditNote.TotalAmount__c == null || creditNote.TotalAmount__c <= 0) {
            errors.add('le montant de l’avoir doit être positif');
        } else if (creditNote.TotalAmount__c > remaining) {
            errors.add('le montant de l’avoir dépasse le montant restant à créditer');
        }
    }

    private static void requireText(String value, String label, List<String> errors) {
        if (String.isBlank(value)) errors.add(label + ' est requis');
    }

    private static void requireConfigured(String value, String label, List<String> errors) {
        if (String.isBlank(value) || value.toUpperCase().contains('CONFIGURER')) {
            errors.add(label + ' doit être configuré');
        }
    }

    private static Boolean isDigits(String value, Integer expectedLength) {
        return String.isNotBlank(value) &&
            value.length() == expectedLength &&
            Pattern.matches('^[0-9]+$', value);
    }
}
