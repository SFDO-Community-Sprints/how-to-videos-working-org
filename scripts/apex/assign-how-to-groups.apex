// Assigns the three How-To permission set groups to the user who runs this script.
// Safe to run again: it adds only the assignments that are missing.
// Run: sf apex run --file scripts/apex/assign-how-to-groups.apex --target-org <org>
Set<String> groups = new Set<String>{ 'HowTo_Team_Member', 'HowTo_Team_Leadership', 'HowTo_Queue_Manager' };
Set<Id> held = new Set<Id>();
for (PermissionSetAssignment a : [
  SELECT PermissionSetGroupId
  FROM PermissionSetAssignment
  WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetGroup.DeveloperName IN :groups
]) {
  held.add(a.PermissionSetGroupId);
}
List<PermissionSetAssignment> missing = new List<PermissionSetAssignment>();
for (PermissionSetGroup g : [SELECT Id, DeveloperName FROM PermissionSetGroup WHERE DeveloperName IN :groups]) {
  if (!held.contains(g.Id)) {
    missing.add(new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetGroupId = g.Id));
  }
}
insert missing;
System.debug(LoggingLevel.ERROR, 'Assigned ' + missing.size() + ' of ' + groups.size() + ' groups.');
