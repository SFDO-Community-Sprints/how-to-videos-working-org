// Creates made-up requests and content across the statuses, so the team has something to look at.
// Safe to run again: content is matched by title, requests by title, and the vote is upserted on its key.
// Sends no email: seeded requests are never from the public form (no receipt), are saved already triaged
// (the triage email fires only on an update), and content is saved already published.
// The running user needs the How-To Team Leadership and Queue Manager groups
// (scripts/apex/assign-how-to-groups.apex), because it creates accepted and declined content.
// Run: sf apex run --file scripts/apex/seed-sample-data.apex --target-org <org>
if (!FeatureManagement.checkPermission('HowTo_Decide_Ideas')) {
  throw new IllegalArgumentException('Run scripts/apex/assign-how-to-groups.apex first: this needs Team Leadership.');
}
Id requestType = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('HowTo_Video_Request').getRecordTypeId();
Id holderQueue = [SELECT Id FROM Group WHERE DeveloperName = 'HowTo_Content_Awaiting_Holder' AND Type = 'Queue'].Id;
String folder = 'https://example.com/drive/sample';

// Content: title => status, product, queue position.
List<HowToContent__c> wanted = new List<HowToContent__c>{
  new HowToContent__c(Name = 'Set up recurring donations', Status__c = 'Submitted', Product__c = 'Agentforce Nonprofit', OwnerId = holderQueue,
    Summary__c = 'How to record a monthly gift so that each installment is created for you.', Champion_Name__c = 'Sample Requester One', Champion_Email__c = 'sample.one@example.com'),
  new HowToContent__c(Name = 'Track volunteer hours', Status__c = 'Submitted', Product__c = 'Volunteers for Salesforce', OwnerId = holderQueue,
    Summary__c = 'Log the hours volunteers work on each shift.', Champion_Name__c = 'Sample Requester Two', Champion_Email__c = 'sample.two@example.com'),
  new HowToContent__c(Name = 'Build a grant report', Status__c = 'Accepted', Product__c = 'Outbound Funds Module', Queue_Position__c = 2,
    Champion_Name__c = 'Sample Requester Three', Champion_Email__c = 'sample.three@example.com'),
  new HowToContent__c(Name = 'Import contacts with the Data Import Wizard', Status__c = 'Drafting', Product__c = 'Nonprofit Success Pack', Queue_Position__c = 1,
    Champion_Name__c = 'Sample Requester Four', Champion_Email__c = 'sample.four@example.com'),
  new HowToContent__c(Name = 'Enroll participants in a program', Status__c = 'Production', Product__c = 'Program Management Module', Queue_Position__c = 3,
    Drive_Folder__c = folder, Scratch_Track_Collected__c = true, Champion_Name__c = 'Sample Requester Five', Champion_Email__c = 'sample.five@example.com'),
  new HowToContent__c(Name = 'Send a donation receipt', Status__c = 'Published', Product__c = 'Agentforce Nonprofit', Published_Date__c = Date.today().addDays(-30),
    Drive_Folder__c = folder, Scratch_Track_Collected__c = true, Screen_Recording_Collected__c = true, Production_Track_Collected__c = true,
    Champion_Name__c = 'Sample Requester Six', Champion_Email__c = 'sample.six@example.com'),
  new HowToContent__c(Name = 'Customize Salesforce for a retail store', Status__c = 'Declined', Product__c = 'Other',
    Team_Response__c = 'The series covers nonprofit use of Salesforce, so this is out of scope.')
};
Map<String, HowToContent__c> content = new Map<String, HowToContent__c>();
for (HowToContent__c c : [SELECT Id, Name FROM HowToContent__c]) {
  content.put(c.Name, c);
}
List<HowToContent__c> newContent = new List<HowToContent__c>();
for (HowToContent__c c : wanted) {
  if (!content.containsKey(c.Name)) {
    c.Type__c = 'Video';
    newContent.add(c);
  }
}
insert newContent;
for (HowToContent__c c : newContent) {
  content.put(c.Name, c);
}

// Requests: title => origin, email, content title (null means still waiting in the triage queue).
List<List<String>> requests = new List<List<String>>{
  new List<String>{ 'Recurring donations walkthrough', 'Import', 'sample.one@example.com', 'Set up recurring donations' },
  new List<String>{ 'How do monthly gifts work?', 'Comms', 'sample.seven@example.com', 'Set up recurring donations' },
  new List<String>{ 'Volunteer hours', 'Internal', 'sample.two@example.com', 'Track volunteer hours' },
  new List<String>{ 'Reporting to a funder', 'Import', 'sample.three@example.com', 'Build a grant report' },
  new List<String>{ 'Importing contacts', 'Import', 'sample.four@example.com', 'Import contacts with the Data Import Wizard' },
  new List<String>{ 'Program enrollment', 'Comms', 'sample.five@example.com', 'Enroll participants in a program' },
  new List<String>{ 'Donation receipts', 'Import', 'sample.six@example.com', 'Send a donation receipt' },
  new List<String>{ 'Retail point of sale', 'Import', 'sample.eight@example.com', 'Customize Salesforce for a retail store' },
  new List<String>{ 'Household accounts explained', 'Import', 'sample.nine@example.com', null },
  new List<String>{ 'Tracking in-kind gifts', 'Comms', 'sample.ten@example.com', null },
  new List<String>{ 'Buy our consulting services', 'Import', 'sample.eleven@example.com', 'NOT QUALIFIED' }
};
Set<String> existing = new Set<String>();
for (Case r : [SELECT Subject FROM Case WHERE RecordTypeId = :requestType]) {
  existing.add(r.Subject);
}
List<Case> newRequests = new List<Case>();
for (List<String> r : requests) {
  if (existing.contains(r[0])) {
    continue;
  }
  Case c = new Case(RecordTypeId = requestType, Subject = r[0], Origin = r[1], SuppliedEmail = r[2],
    SuppliedName = 'Sample requester', Type = 'New content', Description = 'Made-up sample request.', Status = 'New');
  if (r[3] == 'NOT QUALIFIED') {
    c.Status = 'Not Qualified';
    c.HowTo_Not_Qualified_Reason__c = 'This is an advertisement, not a request for how-to content.';
  } else if (r[3] != null) {
    c.Status = 'Qualified';
    c.HowTo_Content__c = content.get(r[3]).Id;
    c.HowTo_Product__c = [SELECT Product__c FROM HowToContent__c WHERE Id = :c.HowTo_Content__c].Product__c;
  }
  newRequests.add(c);
}
Database.DMLOptions toTriageQueue = new Database.DMLOptions();
toTriageQueue.assignmentRuleHeader.useDefaultRule = true;
Database.insert(newRequests, toTriageQueue);

// One vote by the running user, on the first idea.
Id ideaId = content.get('Set up recurring donations').Id;
upsert new Vote__c(Content__c = ideaId, Voter__c = UserInfo.getUserId(), Voter_Key__c = String.valueOf(ideaId) + String.valueOf(UserInfo.getUserId())) Voter_Key__c;

System.debug(LoggingLevel.ERROR, 'Created ' + newContent.size() + ' content and ' + newRequests.size() + ' requests.');
