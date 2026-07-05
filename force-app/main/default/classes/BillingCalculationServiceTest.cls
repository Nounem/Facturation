@IsTest
private class BillingCalculationServiceTest {
    @IsTest
    static void calculatesInvoiceAmountsWithDiscountAndTax() {
        InvoiceLine__c line = new InvoiceLine__c(
            Quantity__c = 2,
            UnitPrice__c = 100,
            DiscountPercent__c = 10,
            TaxRate__c = 20
        );

        BillingCalculationService.calculateInvoiceLines(new List<InvoiceLine__c>{ line });

        System.assertEquals(180, line.NetAmount__c);
        System.assertEquals(36, line.TaxAmount__c);
        System.assertEquals(216, line.GrossAmount__c);
    }

    @IsTest
    static void roundsCurrencyAtLineLevel() {
        InvoiceLine__c line = new InvoiceLine__c(
            Quantity__c = 3,
            UnitPrice__c = 0.333,
            DiscountPercent__c = 0,
            TaxRate__c = 20
        );

        BillingCalculationService.calculateInvoiceLines(new List<InvoiceLine__c>{ line });

        System.assertEquals(1.00, line.NetAmount__c);
        System.assertEquals(0.20, line.TaxAmount__c);
        System.assertEquals(1.20, line.GrossAmount__c);
    }
}
