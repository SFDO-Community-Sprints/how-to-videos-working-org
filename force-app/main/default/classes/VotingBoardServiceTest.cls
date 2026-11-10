/**
 * Calls VotingBoardService the way the voting board component does, as a team member,
 * and checks the totals and the stored votes. Requests are saved through the real triage flow,
 * which casts a vote for their requester (ADR 0003).
 *
 * Not proved here: that a person with no access to Vote__c can vote. The org has one licensed user, a System
 * Administrator, who can read and write votes anyway, and the owner has not allowed creating other users, even
 * in tests. These tests would still pass if the service's system-mode access were removed. HowToDataModelTest
 * checks the configuration instead: outside View All Data holders, only Team Leadership can read votes.
 */
@IsTest
private class VotingBoardServiceTest {
  private static User me() {
    return new User(Id = UserInfo.getUserId());
  }

  private static String myKey(Id contentId) {
    return String.valueOf(contentId) + UserInfo.getUserEmail().toLowerCase();
  }

  /** Makes sure the running user holds the team member permission set, whatever their real assignments. */
  private static void asTeamMember() {
    Id member = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'HowTo_Member_Access'
    ]
    .Id;
    Boolean held = ![
        SELECT Id
        FROM PermissionSetAssignment
        WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :member
      ]
      .isEmpty();
    if (!held) {
      System.runAs(me()) {
        insert new PermissionSetAssignment(
          AssigneeId = UserInfo.getUserId(),
          PermissionSetId = member
        );
      }
    }
  }

  private static HowToContent__c idea(String title) {
    return new HowToContent__c(
      Name = title,
      Product__c = 'Nonprofit Success Pack'
    );
  }

  /** A qualified request from the running user's own email address, in upper case to prove case does not matter. */
  private static Case myRequestFor(HowToContent__c c) {
    return new Case(
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('HowTo_Video_Request')
        .getRecordTypeId(),
      Subject = 'My own request',
      SuppliedName = 'Me',
      SuppliedEmail = UserInfo.getUserEmail().toUpperCase(),
      Origin = 'Internal',
      Status = 'Qualified',
      HowTo_Content__c = c.Id
    );
  }

  private static List<Vote__c> storedVotes(Id contentId) {
    return [
      SELECT Source__c, Voter__c, Voter_Email__c, Voter_Key__c
      FROM Vote__c
      WHERE Content__c = :contentId
      WITH SYSTEM_MODE
    ];
  }

  private static String errorFrom(Id contentId, Boolean casting) {
    try {
      if (casting) {
        VotingBoardService.castVote(contentId);
      } else {
        VotingBoardService.withdrawVote(contentId);
      }
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void listsOnlyIdeasWithMostVotesFirst() {
    asTeamMember();
    HowToContent__c fewer = idea('A fewer votes');
    HowToContent__c more = idea('B more votes');
    HowToContent__c accepted = new HowToContent__c(
      Name = 'Accepted content',
      Status__c = 'Accepted',
      Champion_Name__c = 'Test Champion',
      Champion_Email__c = 'champion@example.com'
    );
    insert as system new List<HowToContent__c>{ fewer, more, accepted };
    insert as system new Vote__c(
      Content__c = more.Id,
      Voter_Email__c = 'someone@example.com',
      Voter_Key__c = String.valueOf(more.Id) + 'someone@example.com',
      Source__c = 'Request'
    );

    System.runAs(me()) {
      List<VotingBoardService.Idea> ideas = VotingBoardService.getIdeas();
      Assert.areEqual(2, ideas.size(), 'accepted content is not an idea');
      Assert.areEqual('B more votes', ideas[0].title);
      Assert.areEqual(1, ideas[0].votes);
      Assert.isFalse(ideas[0].voted, 'someone else\'s vote is not mine');
      Assert.areEqual('Nonprofit Success Pack', ideas[0].product);
      Assert.areEqual('A fewer votes', ideas[1].title);
      Assert.areEqual(0, ideas[1].votes);
    }
  }

  @IsTest
  static void castingTwiceLeavesOneVoteAndWithdrawingRemovesIt() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;

    System.runAs(me()) {
      VotingBoardService.Idea afterVote = VotingBoardService.castVote(c.Id);
      Assert.areEqual(1, afterVote.votes);
      Assert.isTrue(afterVote.voted);
      Assert.isFalse(afterVote.fromRequest);

      VotingBoardService.Idea afterDoubleClick = VotingBoardService.castVote(
        c.Id
      );
      Assert.areEqual(
        1,
        afterDoubleClick.votes,
        'a second vote by the same person is not counted'
      );

      VotingBoardService.Idea afterWithdraw = VotingBoardService.withdrawVote(
        c.Id
      );
      Assert.areEqual(0, afterWithdraw.votes);
      Assert.isFalse(afterWithdraw.voted);

      VotingBoardService.Idea afterSecondWithdraw = VotingBoardService.withdrawVote(
        c.Id
      );
      Assert.areEqual(
        0,
        afterSecondWithdraw.votes,
        'withdrawing twice is harmless'
      );
    }
    Assert.areEqual(0, storedVotes(c.Id).size());
  }

  @IsTest
  static void aBoardVoteNamesThePersonWhoCastIt() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    System.runAs(me()) {
      VotingBoardService.castVote(c.Id);
    }
    Vote__c stored = storedVotes(c.Id)[0];
    Assert.areEqual('Voting Board', stored.Source__c);
    Assert.areEqual(UserInfo.getUserId(), stored.Voter__c);
    Assert.areEqual(
      UserInfo.getUserEmail().toLowerCase(),
      stored.Voter_Email__c
    );
    Assert.areEqual(myKey(c.Id), stored.Voter_Key__c);
  }

  @IsTest
  static void aPersonWhoAskedCountsOnceAndCannotWithdrawTheRequestVote() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    insert as system myRequestFor(c);

    System.runAs(me()) {
      VotingBoardService.Idea listed = VotingBoardService.getIdeas()[0];
      Assert.areEqual(1, listed.votes, 'the request cast a vote');
      Assert.isTrue(listed.voted);
      Assert.isTrue(listed.fromRequest);

      Assert.areEqual(
        1,
        VotingBoardService.castVote(c.Id).votes,
        'asking and voting count once'
      );
      Assert.areEqual(VotingBoardService.FROM_REQUEST, errorFrom(c.Id, false));
    }
    Assert.areEqual(1, storedVotes(c.Id).size());
  }

  @IsTest
  static void aBoardVoteBecomesARequestVoteWhenThePersonAsks() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    System.runAs(me()) {
      VotingBoardService.castVote(c.Id);
    }
    insert as system myRequestFor(c);

    List<Vote__c> votes = storedVotes(c.Id);
    Assert.areEqual(1, votes.size());
    Assert.areEqual('Request', votes[0].Source__c);
    System.runAs(me()) {
      Assert.areEqual(VotingBoardService.FROM_REQUEST, errorFrom(c.Id, false));
    }
  }

  @IsTest
  static void unlinkingTheRequestGivesTheVoteBackToTheBoard() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    System.runAs(me()) {
      VotingBoardService.castVote(c.Id);
    }
    Case mine = myRequestFor(c);
    insert as system mine;
    mine.HowTo_Content__c = null;
    mine.Status = 'New';
    update as system mine;

    List<Vote__c> votes = storedVotes(c.Id);
    Assert.areEqual(1, votes.size(), 'the person still voted on the board');
    Assert.areEqual('Voting Board', votes[0].Source__c);
    System.runAs(me()) {
      Assert.areEqual(
        0,
        VotingBoardService.withdrawVote(c.Id).votes,
        'and can withdraw it again'
      );
    }
  }

  @IsTest
  static void aBoardVoteCastBySomeoneElseWithMyEmailCannotBeWithdrawn() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    Id someoneElse = [
      SELECT Id
      FROM User
      WHERE Id != :UserInfo.getUserId()
      LIMIT 1
    ]
    .Id;
    insert as system new Vote__c(
      Content__c = c.Id,
      Voter__c = someoneElse,
      Voter_Email__c = UserInfo.getUserEmail().toLowerCase(),
      Voter_Key__c = myKey(c.Id),
      Source__c = 'Voting Board'
    );
    System.runAs(me()) {
      Assert.areEqual(VotingBoardService.SOMEONE_ELSES, errorFrom(c.Id, false));
      Assert.areEqual(
        1,
        VotingBoardService.castVote(c.Id).votes,
        'the shared address already counts once'
      );
    }
    Assert.areEqual(1, storedVotes(c.Id).size());
  }

  @IsTest
  static void declinedContentRefusesAVoteWithAReadableMessage() {
    asTeamMember();
    Id leadership = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'HowTo_Leadership_Access'
    ]
    .Id;
    if (!FeatureManagement.checkPermission('HowTo_Decide_Ideas')) {
      System.runAs(me()) {
        insert new PermissionSetAssignment(
          AssigneeId = UserInfo.getUserId(),
          PermissionSetId = leadership
        );
      }
    }
    HowToContent__c c = idea('Out of scope');
    System.runAs(me()) {
      c.Status__c = 'Declined';
      c.Team_Response__c = 'Out of scope for the series.';
      insert as system c;
    }
    System.runAs(me()) {
      Assert.areEqual(
        'Voting is closed for this content.',
        errorFrom(c.Id, true)
      );
    }
    Assert.areEqual(0, storedVotes(c.Id).size());
  }

  @IsTest
  static void missingContentGivesAReadableMessage() {
    asTeamMember();
    HowToContent__c c = idea('Deleted idea');
    insert as system c;
    delete as system c;
    System.runAs(me()) {
      Assert.areEqual(
        'This idea is no longer available. Refresh the list.',
        errorFrom(c.Id, true)
      );
      Assert.areEqual(
        'This idea is no longer available. Refresh the list.',
        errorFrom(c.Id, false)
      );
    }
  }
}
