public with sharing class BillingCalculationService {
    public static Decimal money(Decimal value) {
        return (value == null ? 0 : value).setScale(2, RoundingMode.HALF_UP);
    }

    public static void calculateQuoteLines(List<QuoteLineItem> lines) {
        for (QuoteLineItem line : lines) {
            Decimal quantity = line.Quantity == null ? 0 : line.Quantity;
            Decimal unitPrice = line.UnitPrice == null ? 0 : line.UnitPrice;
            Decimal discount = line.Discount == null ? 0 : line.Discount;
            Decimal taxRate = line.TaxRate__c == null ? 0 : line.TaxRate__c;
            Decimal net = money(quantity * unitPrice * (1 - discount / 100));
            line.TaxAmount__c = money(net * taxRate / 100);
            line.TotalIncludingTax__c = money(net + line.TaxAmount__c);
        }
    }

    public static void calculateInvoiceLines(List<InvoiceLine__c> lines) {
        for (InvoiceLine__c line : lines) {
            Decimal quantity = line.Quantity__c == null ? 0 : line.Quantity__c;
            Decimal unitPrice = line.UnitPrice__c == null ? 0 : line.UnitPrice__c;
            Decimal discount = line.DiscountPercent__c == null ? 0 : line.DiscountPercent__c;
            Decimal taxRate = line.TaxRate__c == null ? 0 : line.TaxRate__c;
            line.NetAmount__c = money(quantity * unitPrice * (1 - discount / 100));
            line.TaxAmount__c = money(line.NetAmount__c * taxRate / 100);
            line.GrossAmount__c = money(line.NetAmount__c + line.TaxAmount__c);
        }
    }
}
