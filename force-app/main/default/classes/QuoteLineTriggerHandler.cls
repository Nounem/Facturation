public with sharing class QuoteLineTriggerHandler {
    public static void beforeSave(List<QuoteLineItem> lines) {
        BillingCalculationService.calculateQuoteLines(lines);
    }

    public static void refreshQuotes(Set<Id> quoteIds) {
        quoteIds.remove(null);
        if (quoteIds.isEmpty()) return;

        Map<Id, AggregateResult> totalsByQuote = new Map<Id, AggregateResult>();
        for (AggregateResult result : [
            SELECT QuoteId quoteId, SUM(TaxAmount__c) tax, SUM(TotalIncludingTax__c) gross
            FROM QuoteLineItem WHERE QuoteId IN :quoteIds GROUP BY QuoteId
        ]) {
            totalsByQuote.put((Id) result.get('quoteId'), result);
        }

        List<Quote> quotes = new List<Quote>();
        for (Id quoteId : quoteIds) {
            AggregateResult total = totalsByQuote.get(quoteId);
            quotes.add(new Quote(
                Id = quoteId,
                TaxAmount__c = total == null ? 0 : (Decimal) total.get('tax'),
                TotalIncludingTax__c = total == null ? 0 : (Decimal) total.get('gross')
            ));
        }
        update quotes;
    }

    public static Set<Id> parentIds(List<QuoteLineItem> lines) {
        Set<Id> ids = new Set<Id>();
        for (QuoteLineItem line : lines) ids.add(line.QuoteId);
        return ids;
    }
}
