/**
 * Proves the round 1 data model: the Video Request rules on Case, the status rules on content,
 * the vote key, votes cast by qualified requests (ADR 0003), the delete restriction, and which permission set grants what.
 * Rule tests run as the deploying user with system-mode DML, so they prove the rules, not record access.
 * Tests that need Team Leadership's custom permission grant or remove it, then act inside System.runAs
 * so the change takes effect. Nothing depends on the user's real assignments.
 */
@IsTest
private class HowToDataModelTest {
  private static final Id REQUEST_TYPE = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
    .get('HowTo_Video_Request')
    .getRecordTypeId();
  private static final String ONE_AT_A_TIME = 'From Drafting onward, content moves forward one status at a time. Choose the next status after the current one, or any earlier status.';
  private static final String LEADERSHIP_ONLY = 'Only Team Leadership can accept or decline an idea, or undo that decision.';
  private static final String VOTING_CLOSED = 'Voting is closed for this content.';
  private static final Set<String> OUR_SETS = new Set<String>{
    'HowTo_Member_Access',
    'HowTo_Leadership_Access',
    'HowTo_Queue_Manager_Access'
  };

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

  private static Case linkedRequest(HowToContent__c c, String email) {
    Case r = request('Recurring donations', email);
    r.HowTo_Content__c = c.Id;
    r.Status = 'Qualified';
    return r;
  }

  private static Id clientEngagement() {
    return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Client_Engagement')
      .getRecordTypeId();
  }

  private static HowToContent__c content(String title) {
    return new HowToContent__c(
      Name = title,
      Champion_Name__c = 'Test Champion',
      Champion_Email__c = 'champion@example.com'
    );
  }

  private static String myEmail() {
    return UserInfo.getUserEmail().toLowerCase();
  }

  /** A vote on the voting board by the running user. */
  private static Vote__c voteBy(Id voter, HowToContent__c c) {
    return new Vote__c(
      Content__c = c.Id,
      Voter__c = voter,
      Voter_Email__c = myEmail(),
      Voter_Key__c = String.valueOf(c.Id) + myEmail(),
      Source__c = 'Voting Board'
    );
  }

  private static List<Vote__c> votesOn(HowToContent__c c) {
    return [
      SELECT Source__c, Voter_Email__c
      FROM Vote__c
      WHERE Content__c = :c.Id
      WITH SYSTEM_MODE
    ];
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

  private static Decimal voteCount(HowToContent__c c) {
    return [
      SELECT Vote_Count__c
      FROM HowToContent__c
      WHERE Id = :c.Id
      WITH SYSTEM_MODE
    ]
    .Vote_Count__c;
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

  private static Set<String> setsIn(List<SObject> rows) {
    Set<String> names = new Set<String>();
    for (SObject row : rows) {
      names.add((String) row.getSObject('Parent').get('Name'));
    }
    return names;
  }

  // Requests

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

    Case qualified = linkedRequest(c, 'a@example.com');
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
    String expected = 'Enter the reason this request is not qualified. The requester receives it by email.';
    r.Status = 'Not Qualified';
    Assert.areEqual(expected, updateError(r));
    r.HowTo_Not_Qualified_Reason__c = '   ';
    Assert.areEqual(expected, updateError(r), 'spaces are not a reason');
    r.HowTo_Not_Qualified_Reason__c = 'This is an advertisement.';
    Assert.isNull(updateError(r));
    Assert.isTrue(
      [SELECT IsClosed FROM Case WHERE Id = :r.Id WITH SYSTEM_MODE].IsClosed,
      'Not Qualified is a closed status'
    );
  }

  @IsTest
  static void otherCaseRecordTypesAreLeftAlone() {
    Case npcCase = new Case(
      RecordTypeId = clientEngagement(),
      Status = 'Escalated'
    );
    Assert.isNull(
      insertError(npcCase),
      'a Nonprofit Cloud case needs no title and keeps its own statuses'
    );
  }

  @IsTest
  static void onlyAVideoRequestCanPointToContent() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case npcCase = new Case(
      RecordTypeId = clientEngagement(),
      Status = 'New',
      HowTo_Content__c = c.Id
    );
    Assert.areEqual(
      'Only a Video Request can point to content.',
      insertError(npcCase)
    );
  }

  // A qualified request counts as a vote (ADR 0003)

  @IsTest
  static void aQualifiedRequestCastsOneVotePerPerson() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    insert as system new List<Case>{
      linkedRequest(c, 'first@example.com'),
      linkedRequest(c, 'FIRST@example.com'),
      linkedRequest(c, 'second@example.com')
    };
    Assert.areEqual(
      2,
      voteCount(c),
      'the same address in another case counts once'
    );
    for (Vote__c v : votesOn(c)) {
      Assert.areEqual('Request', v.Source__c);
    }
  }

  @IsTest
  static void relinkingARequestMovesItsVote() {
    HowToContent__c first = content('Recurring donations');
    HowToContent__c second = content('Monthly giving');
    insert as system new List<HowToContent__c>{ first, second };
    Case r = linkedRequest(first, 'first@example.com');
    insert as system r;
    r.HowTo_Content__c = second.Id;
    update as system r;
    Assert.areEqual(0, voteCount(first));
    Assert.areEqual(1, voteCount(second));
  }

  @IsTest
  static void unlinkingKeepsTheVoteWhileAnotherRequestFromTheSameAddressAsks() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case one = linkedRequest(c, 'first@example.com');
    Case two = linkedRequest(c, 'first@example.com');
    insert as system new List<Case>{ one, two };
    one.HowTo_Content__c = null;
    one.Status = 'New';
    update as system one;
    Assert.areEqual(1, voteCount(c), 'the other request still asks');
    two.HowTo_Content__c = null;
    two.Status = 'New';
    update as system two;
    Assert.areEqual(0, voteCount(c));
  }

  @IsTest
  static void aRequestWithoutAnEmailCastsNoVote() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    insert as system linkedRequest(c, null);
    Assert.areEqual(0, voteCount(c));
  }

  @IsTest
  static void aRequestLinkedToClosedContentCastsNoVote() {
    grantDecideIdeas();
    List<HowToContent__c> closed = new List<HowToContent__c>();
    for (
      String status : new List<String>{ 'Declined', 'Published', 'Retired' }
    ) {
      HowToContent__c c = content(status + ' content');
      c.Status__c = status;
      c.Published_Date__c = Date.today();
      c.Team_Response__c = 'Out of scope for the series.';
      closed.add(c);
    }
    System.runAs(me()) {
      insert as system closed;
    }
    for (HowToContent__c c : closed) {
      Assert.isNull(
        insertError(linkedRequest(c, 'first@example.com')),
        'triage to ' + c.Name + ' still works'
      );
      Assert.areEqual(0, voteCount(c), c.Name);
    }
  }

  @IsTest
  static void changingTheRequesterEmailMovesTheVote() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case r = linkedRequest(c, 'old@example.com');
    insert as system r;
    r.SuppliedEmail = 'new@example.com';
    update as system r;
    List<Vote__c> votes = votesOn(c);
    Assert.areEqual(1, votes.size());
    Assert.areEqual('new@example.com', votes[0].Voter_Email__c);

    r.SuppliedEmail = null;
    update as system r;
    Assert.areEqual(
      0,
      voteCount(c),
      'a request without an address holds no vote'
    );
  }

  @IsTest
  static void unlinkingTwoRequestsFromOneAddressInOneSaveReleasesTheVoteOnce() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case one = linkedRequest(c, 'first@example.com');
    Case two = linkedRequest(c, 'first@example.com');
    insert as system new List<Case>{ one, two };
    for (Case r : new List<Case>{ one, two }) {
      r.HowTo_Content__c = null;
      r.Status = 'New';
    }
    update as system new List<Case>{ one, two };
    Assert.areEqual(0, voteCount(c));
  }

  @IsTest
  static void deletingARequestReleasesItsVote() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Case one = linkedRequest(c, 'first@example.com');
    Case two = linkedRequest(c, 'FIRST@example.com');
    insert as system new List<Case>{ one, two };
    delete as system one;
    Assert.areEqual(
      1,
      voteCount(c),
      'the other request from that address still asks'
    );
    delete as system two;
    Assert.areEqual(0, voteCount(c));
  }

  @IsTest
  static void contentThatRequestsPointToCannotBeDeleted() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    insert as system linkedRequest(c, 'a@example.com');
    try {
      delete as system c;
      Assert.fail('Content with a request pointing to it was deleted');
    } catch (DmlException e) {
      Assert.areEqual(StatusCode.DELETE_FAILED, e.getDmlType(0));
    }
  }

  // Content status

  @IsTest
  static void membersCannotMakeADecision() {
    revokeDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      insert as system c;
      c.Status__c = 'Accepted';
      Assert.areEqual(LEADERSHIP_ONLY, updateError(c), 'accept');
      c.Status__c = 'Declined';
      c.Team_Response__c = 'Out of scope for the series.';
      Assert.areEqual(LEADERSHIP_ONLY, updateError(c), 'decline');

      HowToContent__c pastSubmitted = content('Grant reports');
      pastSubmitted.Status__c = 'Drafting';
      Assert.areEqual(
        LEADERSHIP_ONLY,
        insertError(pastSubmitted),
        'create past Submitted'
      );
    }
  }

  @IsTest
  static void membersCannotUndoADecisionButCanMoveBackWithinIt() {
    grantDecideIdeas();
    HowToContent__c accepted = content('Recurring donations');
    HowToContent__c declined = content('Grant reports');
    System.runAs(me()) {
      insert as system new List<HowToContent__c>{ accepted, declined };
      accepted.Status__c = 'Accepted';
      declined.Status__c = 'Declined';
      declined.Team_Response__c = 'Out of scope for the series.';
      update as system new List<HowToContent__c>{ accepted, declined };
      accepted.Status__c = 'Drafting';
      update as system accepted;
    }
    revokeDecideIdeas();
    System.runAs(me()) {
      accepted.Status__c = 'Accepted';
      Assert.isNull(
        updateError(accepted),
        'Drafting back to Accepted stays within the decision'
      );
      accepted.Status__c = 'Submitted';
      Assert.areEqual(LEADERSHIP_ONLY, updateError(accepted), 'un-accept');
      declined.Status__c = 'Submitted';
      Assert.areEqual(LEADERSHIP_ONLY, updateError(declined), 'un-decline');
    }
  }

  @IsTest
  static void leadershipAcceptsDeclinesAndUndoes() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      insert as system c;
      c.Status__c = 'Accepted';
      Assert.isNull(updateError(c));
      c.Status__c = 'Submitted';
      Assert.isNull(updateError(c));
      c.Status__c = 'Declined';
      c.Team_Response__c = 'Out of scope for the series.';
      Assert.isNull(updateError(c));
    }
  }

  @IsTest
  static void championIsRequiredToAccept() {
    grantDecideIdeas();
    System.runAs(me()) {
      String expected = 'Enter the champion\'s name and email before the idea is accepted.';
      HowToContent__c noEmail = content('Recurring donations');
      noEmail.Champion_Email__c = null;
      noEmail.Status__c = 'Accepted';
      Assert.areEqual(expected, insertError(noEmail));
      HowToContent__c noName = content('Recurring donations');
      noName.Champion_Name__c = null;
      noName.Status__c = 'Accepted';
      Assert.areEqual(expected, insertError(noName));

      HowToContent__c migrated = new HowToContent__c(
        Name = 'Published before round 1',
        Status__c = 'Published',
        Published_Date__c = Date.today()
      );
      Assert.isNull(
        insertError(migrated),
        'published content can be loaded without a champion'
      );
    }
  }

  @IsTest
  static void decliningNeedsATeamResponse() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      insert as system c;
      String expected = 'Enter the team response before declining the idea.';
      c.Status__c = 'Declined';
      Assert.areEqual(expected, updateError(c));
      c.Team_Response__c = '  ';
      Assert.areEqual(expected, updateError(c), 'spaces are not a response');
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

      c.Status__c = 'Drafting';
      Assert.areEqual(
        ONE_AT_A_TIME,
        updateError(c),
        'an idea cannot skip acceptance'
      );
      c.Status__c = 'Accepted';
      Assert.isNull(updateError(c));
      c.Status__c = 'Drafting';
      Assert.isNull(updateError(c));

      c.Drive_Folder__c = 'https://example.com/folder';
      c.Status__c = 'Production';
      Assert.areEqual(
        ONE_AT_A_TIME,
        updateError(c),
        'Drafting cannot skip Proofing'
      );
      c.Status__c = 'Proofing';
      Assert.isNull(updateError(c));
      c.Status__c = 'Production';
      Assert.isNull(updateError(c));

      c.Status__c = 'Accepted';
      Assert.isNull(updateError(c), 'content can move back any distance');
    }
  }

  @IsTest
  static void productionStatusesNeedTheFolderAndAllThreeArtifacts() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c c = content('Recurring donations');
      c.Scratch_Track_Collected__c = true;
      c.Screen_Recording_Collected__c = true;
      c.Production_Track_Collected__c = true;
      for (
        String status : new List<String>{
          'Production',
          'Editing',
          'Final Review'
        }
      ) {
        c.Status__c = status;
        Assert.areEqual(
          'Enter the Drive folder before moving content to Production.',
          insertError(c),
          status
        );
      }

      String artifacts = 'Collect the scratch track, the screen recording, and the production track before moving content to Editing.';
      c.Drive_Folder__c = 'https://example.com/folder';
      for (
        String missing : new List<String>{
          'Scratch_Track_Collected__c',
          'Screen_Recording_Collected__c',
          'Production_Track_Collected__c'
        }
      ) {
        c.Scratch_Track_Collected__c = true;
        c.Screen_Recording_Collected__c = true;
        c.Production_Track_Collected__c = true;
        c.put(missing, false);
        c.Status__c = 'Editing';
        Assert.areEqual(artifacts, insertError(c), missing + ' at Editing');
        c.Status__c = 'Final Review';
        Assert.areEqual(
          artifacts,
          insertError(c),
          missing + ' at Final Review'
        );
      }
      c.Scratch_Track_Collected__c = true;
      c.Screen_Recording_Collected__c = true;
      c.Production_Track_Collected__c = true;
      Assert.isNull(insertError(c));
    }
  }

  @IsTest
  static void publishedAndRetiredNeedAPublishedDate() {
    grantDecideIdeas();
    System.runAs(me()) {
      for (String status : new List<String>{ 'Published', 'Retired' }) {
        HowToContent__c c = content('Recurring donations');
        c.Status__c = status;
        Assert.areEqual('Enter the published date.', insertError(c), status);
        c.Published_Date__c = Date.today();
        Assert.isNull(insertError(c), status);
      }
    }
  }

  @IsTest
  static void queuePositionStartsAtOne() {
    HowToContent__c c = content('Recurring donations');
    c.Queue_Position__c = 0;
    Assert.areEqual(
      'Queue Position starts at 1. Position 1 is produced first.',
      insertError(c)
    );
    c.Queue_Position__c = 1;
    Assert.isNull(insertError(c));
  }

  // Votes

  @IsTest
  static void oneVotePerPersonWithTheRightKey() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Id me = UserInfo.getUserId();
    String wrongKey = 'The voter key must be the content ID followed by the voter\'s email address in lower case.';

    Vote__c reversedKey = voteBy(me, c);
    reversedKey.Voter_Key__c = myEmail() + String.valueOf(c.Id);
    Assert.areEqual(wrongKey, insertError(reversedKey));
    Vote__c upperCaseKey = voteBy(me, c);
    upperCaseKey.Voter_Key__c = String.valueOf(c.Id) + myEmail().toUpperCase();
    Assert.areEqual(
      wrongKey,
      insertError(upperCaseKey),
      'the key holds the address in lower case'
    );
    Vote__c noVoter = voteBy(null, c);
    Assert.areEqual(
      'A vote from the voting board must name its voter.',
      insertError(noVoter)
    );

    Assert.isNull(insertError(voteBy(me, c)));
    try {
      insert as system voteBy(me, c);
      Assert.fail('A second vote by the same person was saved');
    } catch (DmlException e) {
      Assert.areEqual(StatusCode.DUPLICATE_VALUE, e.getDmlType(0));
    }
    Assert.areEqual(1, voteCount(c));
  }

  @IsTest
  static void theLongestEmailFitsTheVote() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    String email = 'a'.repeat(64) + '@' + 'b'.repeat(3) + '.example.com';
    Assert.areEqual(80, email.length(), 'the longest email the field holds');
    Vote__c v = new Vote__c(
      Content__c = c.Id,
      Voter_Email__c = email,
      Voter_Key__c = String.valueOf(c.Id) + email,
      Source__c = 'Request'
    );
    Assert.isNull(insertError(v));
    Assert.areEqual(1, voteCount(c));
  }

  @IsTest
  static void withdrawingAVoteLowersTheCount() {
    HowToContent__c c = content('Recurring donations');
    insert as system c;
    Vote__c v = voteBy(UserInfo.getUserId(), c);
    insert as system v;
    Assert.areEqual(1, voteCount(c));
    delete as system v;
    Assert.areEqual(0, voteCount(c));
  }

  @IsTest
  static void declinedPublishedAndRetiredContentTakeNoVotes() {
    grantDecideIdeas();
    System.runAs(me()) {
      HowToContent__c declined = content('Declined idea');
      declined.Status__c = 'Declined';
      declined.Team_Response__c = 'Out of scope for the series.';
      HowToContent__c published = content('Published video');
      published.Status__c = 'Published';
      published.Published_Date__c = Date.today();
      HowToContent__c retired = content('Retired video');
      retired.Status__c = 'Retired';
      retired.Published_Date__c = Date.today();
      HowToContent__c accepted = content('Accepted idea');
      accepted.Status__c = 'Accepted';
      insert as system new List<HowToContent__c>{
        declined,
        published,
        retired,
        accepted
      };

      Id me = UserInfo.getUserId();
      Assert.areEqual(
        VOTING_CLOSED,
        insertError(voteBy(me, declined)),
        'Declined'
      );
      Assert.areEqual(
        VOTING_CLOSED,
        insertError(voteBy(me, published)),
        'Published'
      );
      Assert.areEqual(
        VOTING_CLOSED,
        insertError(voteBy(me, retired)),
        'Retired'
      );
      Assert.isNull(
        insertError(voteBy(me, accepted)),
        'voting stays open after acceptance'
      );
    }
  }

  // Who holds which permission: the org has one user, who holds every group, so these are checked as configuration.

  @IsTest
  static void onlyLeadershipCanReadVotesAndNobodyWritesThem() {
    List<ObjectPermissions> votes = [
      SELECT
        Parent.Name,
        PermissionsRead,
        PermissionsCreate,
        PermissionsEdit,
        PermissionsDelete
      FROM ObjectPermissions
      WHERE SobjectType = 'Vote__c' AND Parent.Name IN :OUR_SETS
    ];
    Assert.areEqual(
      new Set<String>{ 'HowTo_Leadership_Access' },
      setsIn(votes)
    );
    Assert.isTrue(votes[0].PermissionsRead);
    Assert.isFalse(
      votes[0].PermissionsCreate ||
        votes[0].PermissionsEdit ||
        votes[0].PermissionsDelete
    );
    Assert.areEqual(
      new Set<String>{ 'HowTo_Leadership_Access' },
      setsIn(
        [
          SELECT Parent.Name
          FROM FieldPermissions
          WHERE
            Field = 'Vote__c.Voter__c'
            AND PermissionsRead = TRUE
            AND Parent.Name IN :OUR_SETS
        ]
      )
    );
  }

  @IsTest
  static void outsideViewAllDataOnlyTeamLeadershipReadsVotes() {
    Set<String> readers = new Set<String>();
    for (ObjectPermissions p : [
      SELECT Parent.Name
      FROM ObjectPermissions
      WHERE
        SobjectType = 'Vote__c'
        AND PermissionsRead = TRUE
        AND Parent.PermissionsViewAllData = FALSE
    ]) {
      readers.add(p.Parent.Name);
    }
    Assert.areEqual(
      new Set<String>{ 'HowTo_Leadership_Access', 'HowTo_Team_Leadership' },
      readers
    );
  }

  @IsTest
  static void onlyTheQueueManagerCreatesContentAndSetsQueuePosition() {
    Assert.areEqual(
      new Set<String>{ 'HowTo_Queue_Manager_Access' },
      setsIn(
        [
          SELECT Parent.Name
          FROM ObjectPermissions
          WHERE
            SobjectType = 'HowToContent__c'
            AND PermissionsCreate = TRUE
            AND Parent.Name IN :OUR_SETS
        ]
      )
    );
    Assert.areEqual(
      new Set<String>{ 'HowTo_Queue_Manager_Access' },
      setsIn(
        [
          SELECT Parent.Name
          FROM FieldPermissions
          WHERE
            Field = 'HowToContent__c.Queue_Position__c'
            AND PermissionsEdit = TRUE
            AND Parent.Name IN :OUR_SETS
        ]
      )
    );
  }

  @IsTest
  static void onlyLeadershipChangesTheChampionAndDecides() {
    Assert.areEqual(
      new Set<String>{ 'HowTo_Leadership_Access' },
      setsIn(
        [
          SELECT Parent.Name
          FROM FieldPermissions
          WHERE
            Field IN (
              'HowToContent__c.Champion_Name__c',
              'HowToContent__c.Champion_Email__c'
            )
            AND PermissionsEdit = TRUE
            AND Parent.Name IN :OUR_SETS
        ]
      )
    );
    Id decide = [
      SELECT Id
      FROM CustomPermission
      WHERE DeveloperName = 'HowTo_Decide_Ideas'
    ]
    .Id;
    Assert.areEqual(
      new Set<String>{ 'HowTo_Leadership_Access' },
      setsIn(
        [
          SELECT Parent.Name
          FROM SetupEntityAccess
          WHERE SetupEntityId = :decide AND Parent.Name IN :OUR_SETS
        ]
      )
    );
  }

  @IsTest
  static void nobodyEditsTheCounts() {
    Assert.isTrue(
      [
          SELECT Parent.Name
          FROM FieldPermissions
          WHERE
            Field = 'HowToContent__c.Vote_Count__c'
            AND PermissionsEdit = TRUE
            AND Parent.Name IN :OUR_SETS
        ]
        .isEmpty()
    );
  }
}
