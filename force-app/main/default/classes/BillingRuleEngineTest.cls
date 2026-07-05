@IsTest
private class BillingRuleEngineTest {
    @IsTest
    static void calculatesAdvanceAndArrearsPeriods() {
        BillingRule__c advance = new BillingRule__c(
            BillingFrequency__c = 'Monthly',
            BillingType__c = 'Advance',
            PeriodBoundary__c = 'Anniversary',
            BillingDay__c = 15
        );
        BillingRuleEngine.BillingPeriod advancePeriod =
            BillingRuleEngine.periodFor(advance, Date.newInstance(2026, 7, 15));
        System.assertEquals(Date.newInstance(2026, 7, 15), advancePeriod.startDate);
        System.assertEquals(Date.newInstance(2026, 8, 14), advancePeriod.endDate);
        System.assertEquals(
            Date.newInstance(2026, 8, 15),
            BillingRuleEngine.nextBillingDate(advance, Date.newInstance(2026, 7, 15))
        );

        BillingRule__c arrears = new BillingRule__c(
            BillingFrequency__c = 'Quarterly',
            BillingType__c = 'Arrears',
            PeriodBoundary__c = 'Calendar',
            BillingDay__c = 1
        );
        BillingRuleEngine.BillingPeriod arrearsPeriod =
            BillingRuleEngine.periodFor(arrears, Date.newInstance(2026, 7, 1));
        System.assertEquals(Date.newInstance(2026, 4, 1), arrearsPeriod.startDate);
        System.assertEquals(Date.newInstance(2026, 6, 30), arrearsPeriod.endDate);
    }

    @IsTest
    static void oneTimeRuleHasNoNextDate() {
        BillingRule__c rule = new BillingRule__c(
            BillingFrequency__c = 'OneTime',
            BillingType__c = 'Advance',
            PeriodBoundary__c = 'Anniversary'
        );
        System.assertEquals(null, BillingRuleEngine.nextBillingDate(rule, Date.today()));
        System.assert(BillingRuleEngine.generationKey(UserInfo.getUserId(), Date.today()).contains(':'));
    }
}
