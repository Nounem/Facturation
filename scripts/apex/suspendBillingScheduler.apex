List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, State
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Facturation quotidienne'
      AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
];
for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
}
System.debug('Tâches de facturation suspendues : ' + jobs.size());
