public with sharing class BillingSecurity {
    public class BillingSecurityException extends Exception {}

    public static void requireRead(Schema.SObjectType objectType, String label) {
        if (!objectType.getDescribe().isAccessible()) {
            throw new BillingSecurityException('Accès en lecture refusé sur ' + label + '.');
        }
    }

    public static void requireCreate(Schema.SObjectType objectType, String label) {
        if (!objectType.getDescribe().isCreateable()) {
            throw new BillingSecurityException('Création refusée sur ' + label + '.');
        }
    }

    public static void requireUpdate(Schema.SObjectType objectType, String label) {
        if (!objectType.getDescribe().isUpdateable()) {
            throw new BillingSecurityException('Modification refusée sur ' + label + '.');
        }
    }

    public static void requireReadableFields(
        List<Schema.SObjectField> fields,
        String label
    ) {
        for (Schema.SObjectField field : fields) {
            if (!field.getDescribe().isAccessible()) {
                throw new BillingSecurityException(
                    'Accès refusé au champ ' + label + '.' + field.getDescribe().getName() + '.'
                );
            }
        }
    }

    public static void requireCreateableFields(
        List<Schema.SObjectField> fields,
        String label
    ) {
        for (Schema.SObjectField field : fields) {
            if (!field.getDescribe().isCreateable()) {
                throw new BillingSecurityException(
                    'Création refusée sur le champ ' + label + '.' +
                    field.getDescribe().getName() + '.'
                );
            }
        }
    }

    public static void requireUpdateableFields(
        List<Schema.SObjectField> fields,
        String label
    ) {
        for (Schema.SObjectField field : fields) {
            if (!field.getDescribe().isUpdateable()) {
                throw new BillingSecurityException(
                    'Modification refusée sur le champ ' + label + '.' +
                    field.getDescribe().getName() + '.'
                );
            }
        }
    }
}
