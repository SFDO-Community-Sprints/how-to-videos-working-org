/**
 * Calls VotingBoardService the way the voting board component does, as a team member,
 * and checks the totals and the stored votes.
 */
@IsTest
private class VotingBoardServiceTest {
  private static User me() {
    return new User(Id = UserInfo.getUserId());
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

  private static Integer storedVotes(Id contentId) {
    return [
      SELECT COUNT()
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
      Voter__c = UserInfo.getUserId(),
      Voter_Key__c = String.valueOf(more.Id) +
        String.valueOf(UserInfo.getUserId())
    );

    System.runAs(me()) {
      List<VotingBoardService.Idea> ideas = VotingBoardService.getIdeas();
      Assert.areEqual(2, ideas.size(), 'accepted content is not an idea');
      Assert.areEqual('B more votes', ideas[0].title);
      Assert.areEqual(1, ideas[0].votes);
      Assert.isTrue(ideas[0].voted);
      Assert.areEqual('Nonprofit Success Pack', ideas[0].product);
      Assert.areEqual('A fewer votes', ideas[1].title);
      Assert.areEqual(0, ideas[1].votes);
      Assert.isFalse(ideas[1].voted);
      Assert.areEqual(0, ideas[1].requests);
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

      VotingBoardService.Idea afterDoubleClick = VotingBoardService.castVote(
        c.Id
      );
      Assert.areEqual(
        1,
        afterDoubleClick.votes,
        'a second vote by the same person is not counted'
      );
      Assert.areEqual(1, storedVotes(c.Id));

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
    Assert.areEqual(0, storedVotes(c.Id));
  }

  @IsTest
  static void theVoteBelongsToThePersonWhoCastIt() {
    asTeamMember();
    HowToContent__c c = idea('Recurring donations');
    insert as system c;
    System.runAs(me()) {
      VotingBoardService.castVote(c.Id);
    }
    Vote__c stored = [
      SELECT Voter__c, Voter_Key__c
      FROM Vote__c
      WHERE Content__c = :c.Id
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(UserInfo.getUserId(), stored.Voter__c);
    Assert.areEqual(
      String.valueOf(c.Id) + String.valueOf(UserInfo.getUserId()),
      stored.Voter_Key__c
    );
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
    Assert.areEqual(0, storedVotes(c.Id));
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
