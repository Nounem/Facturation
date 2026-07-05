public with sharing class BillingRuleEngine {
    public class BillingRuleException extends Exception {}

    public class BillingPeriod {
        public Date startDate;
        public Date endDate;
        public BillingPeriod(Date startValue, Date endValue) {
            startDate = startValue;
            endDate = endValue;
        }
    }

    public static BillingPeriod periodFor(BillingRule__c rule, Date billingDate) {
        if (billingDate == null) billingDate = Date.today();
        Integer months = frequencyMonths(rule == null ? null : rule.BillingFrequency__c);
        if (months == 0) return new BillingPeriod(billingDate, billingDate);

        Boolean calendarBoundary = rule.PeriodBoundary__c == 'Calendar';
        Boolean arrears = rule.BillingType__c == 'Arrears';
        if (calendarBoundary) {
            Date currentMonthStart = Date.newInstance(billingDate.year(), billingDate.month(), 1);
            if (arrears) {
                Date endDate = currentMonthStart.addDays(-1);
                return new BillingPeriod(currentMonthStart.addMonths(-months), endDate);
            }
            return new BillingPeriod(currentMonthStart, currentMonthStart.addMonths(months).addDays(-1));
        }

        if (arrears) {
            return new BillingPeriod(billingDate.addMonths(-months), billingDate.addDays(-1));
        }
        return new BillingPeriod(billingDate, billingDate.addMonths(months).addDays(-1));
    }

    public static Date nextBillingDate(BillingRule__c rule, Date currentDate) {
        Integer months = frequencyMonths(rule.BillingFrequency__c);
        if (months == 0) return null;
        Date candidate = currentDate.addMonths(months);
        Integer requestedDay = rule.BillingDay__c == null
            ? candidate.day()
            : Integer.valueOf(rule.BillingDay__c);
        Integer safeDay = Math.min(requestedDay, Date.daysInMonth(candidate.year(), candidate.month()));
        return Date.newInstance(candidate.year(), candidate.month(), safeDay);
    }

    public static String generationKey(Id opportunityId, Date billingDate) {
        return String.valueOf(opportunityId) + ':' + String.valueOf(billingDate);
    }

    @TestVisible
    private static Integer frequencyMonths(String frequency) {
        if (frequency == 'Monthly') return 1;
        if (frequency == 'Quarterly') return 3;
        if (frequency == 'Semiannual') return 6;
        if (frequency == 'Annual') return 12;
        return 0;
    }
}
