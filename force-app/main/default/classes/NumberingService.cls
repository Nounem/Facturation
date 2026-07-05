public with sharing class NumberingService {
    public class ConfigurationException extends Exception {}

    public static String nextInvoiceNumber(Id billingEntityId, Date issueDate) {
        return nextDocumentNumber(billingEntityId, issueDate, 'Invoice');
    }

    public static String nextDocumentNumber(
        Id billingEntityId,
        Date issueDate,
        String documentType
    ) {
        Integer year = issueDate.year();
        List<NumberingSequence__c> sequences = [
            SELECT Id, Prefix__c, NextNumber__c, Padding__c
            FROM NumberingSequence__c
            WHERE BillingEntity__c = :billingEntityId
              AND DocumentType__c = :documentType
              AND Year__c = :year
            LIMIT 1
            FOR UPDATE
        ];
        if (sequences.isEmpty()) {
            throw new ConfigurationException(
                'Aucune séquence de ' + documentLabel(documentType) +
                ' n’est configurée pour l’année ' + year + '.'
            );
        }

        NumberingSequence__c sequence = sequences[0];
        Integer currentNumber = Integer.valueOf(sequence.NextNumber__c);
        Integer padding = Integer.valueOf(sequence.Padding__c);
        String serial = String.valueOf(currentNumber);
        while (serial.length() < padding) {
            serial = '0' + serial;
        }
        sequence.NextNumber__c = currentNumber + 1;
        update sequence;
        return sequence.Prefix__c + '-' + year + '-' + serial;
    }

    private static String documentLabel(String documentType) {
        return documentType == 'CreditNote' ? 'numérotation d’avoir' : 'facture';
    }
}
