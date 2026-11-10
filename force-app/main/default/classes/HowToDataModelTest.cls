/**
 * Proves the round 1 data model rules: the Video Request rules on Case, the status rules on content,
 * the vote key, the vote and request counts, and the delete restriction.
 * Runs as the deploying user, with system-mode DML: these tests prove the rules, not who can see what.
 * Tests that need Team Leadership's custom permission grant or remove it, then act inside System.runAs
 * so the change takes effect. The result does not depend on the user's real assignments.
 */
@IsTest
private class HowToDataModelTest {
  private static final Id REQUEST_TYPE = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
    .get('HowTo_Video_Request')
    .getRecordTypeId();

  private static Case request(String title, String email) {
    return new Case(
      RecordTypeId = REQUEST_TYPE,
      Subject = title,
      Description = 'Please show how this works.',
      SuppliedName = 'Test Requester',
      SuppliedEmail = email,
      Origin = 'Community',
      Type = 'New content',
      Status = 'New'
    );
  }

  private static HowToContent__c content(String title) {
    return new HowToContent__c(
      Name = title,
      Champion_Name__c = 'Test Champion',
      Champion_Email__c = 'champion@example.com'
    );
  }

  private static String insertError(SObject record) {
    try {
      insert as system record;
    } catch (DmlException e) {
      return e.getDmlMessage(0);
    }
    return null;
  }

  private static String updateError(SObject record) {
    try {
      update as system record;
    } catch (DmlException e) {
      return e.getDmlMessage(0);
    }
    return null;
  }

  private static User me() {
    return new User(Id = UserInfo.getUserId());
  }

  /** Gives the running user Team Leadership's permission to accept and decline, if it lacks it. */
  private static void grantDecideIdeas() {
    if (FeatureManagement.checkPermission('HowTo_Decide_Ideas')) {
      return;
    }
    Id leadership = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'HowTo_Leadership_Access'
    ]
    .Id;
    System.runAs(me()) {
      insert new PermissionSetAssignment(
        AssigneeId = UserInfo.getUserId(),
        PermissionSetId = leadership
      );
    }
  }

  /** Removes every assignment that gives the running user permission to accept and decline. */
  private static void revokeDecideIdeas() {
    System.runAs(me()) {
      delete [
        SELECT Id
        FROM PermissionSetAssignment
        WHERE
          AssigneeId = :UserInfo.getUserId()
          AND (PermissionSet.Name = 'HowTo_Leadership_Access'
          OR PermissionSetGroup.DeveloperName = 'HowTo_Team_Leadership')
      ];
    }
  }

  @IsTest
  static void requestNeedsTitle() {
    Assert.areEqual(
      'A request needs a title. Enter it in Subject.',
      insertError(request(null, 'a@example.com'))
    );
  }

  @IsTest
  static void requestHoldsToItsThreeStatuses() {
    Case r = request('Recurring donations', 'a@example.com');
    r.Status = 'Escalated';
    Assert.areEqual(
      'A request\'s status must be New, Qualified, or Not Qualified.',
      insertError(r)
    );
  }

  @IsTest
  static void requestIsQualifiedExactlyWhenItPointsToContent() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    String expected = 'A request is Qualified exactly when it points to content. Set both Status and Content, or neither.';

    Case qualifiedWithoutContent = request(
      'Recurring donations',
      'a@example.com'
    );
    qualifiedWithoutContent.Status = 'Qualified';
    Assert.areEqual(expected, insertError(qualifiedWithoutContent));

    Case newWithContent = request('Recurring donations', 'a@example.com');
    newWithContent.HowTo_Content__c = c.Id;
    Assert.areEqual(expected, insertError(newWithContent));

    Case qualified = request('Recurring donations', 'a@example.com');
    qualified.HowTo_Content__c = c.Id;
    qualified.Status = 'Qualified';
    Assert.isNull(insertError(qualified));
    Assert.isTrue(
      [SELECT IsClosed FROM Case WHERE Id = :qualified.Id WITH SYSTEM_MODE]
      .IsClosed,
      'Qualified is a closed status'
    );
  }

  @IsTest
  static void notQualifiedNeedsAReason() {
    Case r = request('Buy my product', 'a@example.com');
    insert as system r;
    r.Status = 'Not Qualified';
    Assert.areEqual(
      'Enter the reason this request is not qualified. The requester receives it by email.',
      updateError(r)
    );
    r.HowTo_Not_Qualified_Reason__c = 'This is an advertisement.';
    Assert.isNull(updateError(r));
    Assert.isTrue(
      [SELECT IsClosed FROM Case WHERE Id = :r.Id WITH SYSTEM_MODE].IsClosed,
      'Not Qualified is a closed status'
    );
  }

  @IsTest
  static void requestCountCountsDifferentEmailAddresses() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    List<Case> requests = new List<Case>{
      request('Recurring donations', 'first@example.com'),
      request('Set up recurring gifts', 'first@example.com'),
      request('Monthly giving', 'second@example.com')
    };
    for (Case r : requests) {
      r.HowTo_Content__c = c.Id;
      r.Status = 'Qualified';
    }
    Test.startTest();
    insert as system requests;
    Test.stopTest();
    Assert.areEqual(
      2,
      [
        SELECT Request_Count__c
        FROM HowToContent__c
        WHERE Id = :c.Id
        WITH SYSTEM_MODE
      ]
      .Request_Count__c
    );
  }

  @IsTest
  static void contentThatRequestsPointToCannotBeDeleted() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case r = request('Recurring donations', 'a@example.com');
    r.HowTo_Content__c = c.Id;
    r.Status = 'Qualified';
    insert as system r;
    try {
      delete as system c;
      Assert.fail('Content with a request pointing to it was deleted');
    } catch (DmlException e) {
      Assert.areEqual(StatusCode.DELETE_FAILED, e.getDmlType(0));
    }
  }

  @IsTest
  static void onlyLeadershipAcceptsAndDeclines() {
    revokeDecideIdeas();
    HowToContent__c c = content('Recurring donations');
    System.runAs(me()) {
      insert as system c;
      c.Status__c = 'Accepted';
      Assert.areEqual(
        'Only Team Leadership can accept or decline an idea.',
        updateError(c)
      );
    }
    grantDecideIdeas();
    System.runAs(me()) {
      Assert.isNull(updateError(c));
    }
  }

  @IsTest
  static void championIsRequiredBeforeAccepted() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = new HowToContent__c(
        Name = 'Recurring donations',
        Status__c = 'Accepted'
      );
      Assert.areEqual(
        'Enter the champion\'s name and email before the idea is accepted.',
        insertError(c)
      );
    }
  }

  @IsTest
  static void decliningNeedsATeamResponse() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      insert as system c;
      c.Status__c = 'Declined';
      Assert.areEqual(
        'Enter the team response before declining the idea.',
        updateError(c)
      );
      c.Team_Response__c = 'Out of scope for the series.';
      Assert.isNull(updateError(c));
    }
  }

  @IsTest
  static void contentMovesForwardOneStatusAtATimeFromDrafting() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      insert as system c;
      String oneAtATime = 'From Drafting onward, content moves forward one status at a time. Choose the next status after the current one, or any earlier status.';

      c.Status__c = 'Drafting';
      Assert.areEqual(
        oneAtATime,
        updateError(c),
        'an idea cannot skip acceptance'
      );

      c.Status__c = 'Accepted';
      Assert.isNull(updateError(c));
      c.Status__c = 'Drafting';
      Assert.isNull(updateError(c));

      c.Status__c = 'Production';
      c.Drive_Folder__c = 'https://example.com/folder';
      Assert.areEqual(
        oneAtATime,
        updateError(c),
        'Drafting cannot skip Proofing'
      );

      c.Status__c = 'Proofing';
      Assert.isNull(updateError(c));
      c.Status__c = 'Production';
      Assert.isNull(updateError(c));

      c.Status__c = 'Submitted';
      Assert.isNull(updateError(c), 'content can move back any distance');
    }
  }

  @IsTest
  static void productionStatusesNeedTheFolderAndArtifacts() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      c.Status__c = 'Production';
      Assert.areEqual(
        'Enter the Drive folder before moving content to Production.',
        insertError(c)
      );

      c.Drive_Folder__c = 'https://example.com/folder';
      c.Status__c = 'Editing';
      c.Scratch_Track_Collected__c = true;
      c.Screen_Recording_Collected__c = true;
      Assert.areEqual(
        'Collect the scratch track, the screen recording, and the production track before moving content to Editing.',
        insertError(c)
      );
      c.Production_Track_Collected__c = true;
      Assert.isNull(insertError(c));
    }
  }

  @IsTest
  static void publishedNeedsAPublishedDate() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      c.Status__c = 'Published';
      Assert.areEqual('Enter the published date.', insertError(c));
      c.Published_Date__c = Date.today();
      Assert.isNull(insertError(c));
    }
  }

  @IsTest
  static void oneVotePerPersonWithTheRightKey() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Id me = UserInfo.getUserId();
    String key = String.valueOf(c.Id) + String.valueOf(me);
    String wrongKey = 'The voter key must be the content ID followed by the voter\'s user ID.';

    Assert.areEqual(
      wrongKey,
      insertError(
        new Vote__c(
          Content__c = c.Id,
          Voter__c = me,
          Voter_Key__c = String.valueOf(me) + String.valueOf(c.Id)
        )
      )
    );
    Assert.areEqual(
      wrongKey,
      insertError(
        new Vote__c(Content__c = c.Id, Voter_Key__c = String.valueOf(c.Id))
      ),
      'a vote needs a voter'
    );

    Assert.isNull(
      insertError(
        new Vote__c(Content__c = c.Id, Voter__c = me, Voter_Key__c = key)
      )
    );
    try {
      insert as system new Vote__c(
        Content__c = c.Id,
        Voter__c = me,
        Voter_Key__c = key
      );
      Assert.fail('A second vote by the same person was saved');
    } catch (DmlException e) {
      Assert.areEqual(StatusCode.DUPLICATE_VALUE, e.getDmlType(0));
    }
    Assert.areEqual(
      1,
      [
        SELECT Vote_Count__c
        FROM HowToContent__c
        WHERE Id = :c.Id
        WITH SYSTEM_MODE
      ]
      .Vote_Count__c
    );
  }

  @IsTest
  static void closedContentTakesNoVotes() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      c.Status__c = 'Declined';
      c.Team_Response__c = 'Out of scope for the series.';
      insert as system c;
      Id me = UserInfo.getUserId();
      Assert.areEqual(
        'Voting is closed for this content.',
        insertError(
          new Vote__c(
            Content__c = c.Id,
            Voter__c = me,
            Voter_Key__c = String.valueOf(c.Id) + String.valueOf(me)
          )
        )
      );
    }
  }
}
