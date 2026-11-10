/**
 * The voting board's service: lists the ideas, and casts or withdraws the signed-in person's vote.
 *
 * A vote is keyed on the content and the voter's email address in lower case (ADR 0003), so a person who both
 * asked for an idea and votes for it counts once. A vote is the running user's if its key carries their email or
 * its Voter__c is them; when both match different votes, their own board vote comes first, so withdrawing it
 * corrects the count. Only a board vote that the running user cast can be withdrawn. A vote that came from a
 * request stays while the request points to the content. Votes are not moved when a user's email changes.
 *
 * Team members hold no access to Vote__c, so this class reads and writes votes in system mode, and only ever
 * for the running user. Content is read in user mode, so a person sees only the ideas and fields their
 * permissions allow. The class runs with sharing, so a vote can only be cast on content the person can see.
 */
public with sharing class VotingBoardService {
  @TestVisible
  private static final String FROM_REQUEST = 'Your vote comes from your request for this idea. It stays while your request points to it.';
  @TestVisible
  private static final String SOMEONE_ELSES = 'This vote was cast by someone else who uses your email address, so you cannot withdraw it.';

  /** One idea on the board, with its total and the running user's vote. */
  public class Idea {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String product;
    @AuraEnabled
    public Integer votes;
    @AuraEnabled
    public Boolean voted;
    @AuraEnabled
    public Boolean fromRequest;

    Idea(HowToContent__c c, Vote__c mine) {
      this.id = c.Id;
      this.title = c.Name;
      this.product = c.Product__c;
      this.votes = c.Vote_Count__c == null ? 0 : c.Vote_Count__c.intValue();
      this.voted = mine != null;
      this.fromRequest = mine != null && mine.Source__c == 'Request';
    }
  }

  /** The ideas (content with the status Submitted), most votes first, then by title. */
  @AuraEnabled
  public static List<Idea> getIdeas() {
    List<HowToContent__c> ideas = [
      SELECT Id, Name, Product__c, Vote_Count__c
      FROM HowToContent__c
      WHERE Status__c = 'Submitted'
      WITH USER_MODE
      ORDER BY Vote_Count__c DESC, Name ASC
      LIMIT 500
    ];
    Map<Id, Vote__c> mine = myVotes(
      new Map<Id, HowToContent__c>(ideas).keySet(),
      false
    );
    List<Idea> result = new List<Idea>();
    for (HowToContent__c c : ideas) {
      result.add(new Idea(c, mine.get(c.Id)));
    }
    return result;
  }

  /** Casts the running user's vote. If they already have one, from the board or a request, nothing changes. */
  @AuraEnabled
  public static Idea castVote(Id contentId) {
    HowToContent__c c = visibleContent(contentId);
    if (myVote(c.Id, false) == null) {
      Vote__c vote = new Vote__c(
        Content__c = c.Id,
        Voter__c = UserInfo.getUserId(),
        Voter_Email__c = myEmail(),
        Voter_Key__c = keyFor(c.Id),
        Source__c = 'Voting Board'
      );
      Database.SaveResult saved = Database.insert(
        vote,
        false,
        AccessLevel.SYSTEM_MODE
      );
      // A duplicate key means a vote arrived at the same moment, from a double click or a request: it is counted.
      if (
        !saved.isSuccess() &&
        saved.getErrors()[0].getStatusCode() != StatusCode.DUPLICATE_VALUE
      ) {
        throw error(saved.getErrors()[0].getMessage());
      }
    }
    return new Idea(visibleContent(contentId), myVote(c.Id, false));
  }

  /** Withdraws the board vote the running user cast, if there is one. A vote from a request stays. */
  @AuraEnabled
  public static Idea withdrawVote(Id contentId) {
    HowToContent__c c = visibleContent(contentId);
    // Locked, so triage cannot turn this vote into a request vote between the check and the delete.
    Vote__c mine = myVote(c.Id, true);
    if (mine != null) {
      if (mine.Source__c == 'Request') {
        throw error(FROM_REQUEST);
      }
      if (mine.Voter__c != UserInfo.getUserId()) {
        throw error(SOMEONE_ELSES);
      }
      try {
        Database.delete(mine, true, AccessLevel.SYSTEM_MODE);
      } catch (DmlException e) {
        throw error(e.getDmlMessage(0));
      }
    }
    return new Idea(visibleContent(contentId), myVote(c.Id, false));
  }

  private static String myEmail() {
    return UserInfo.getUserEmail().toLowerCase();
  }

  private static String keyFor(Id contentId) {
    return String.valueOf(contentId) + myEmail();
  }

  private static Vote__c myVote(Id contentId, Boolean lock) {
    return myVotes(new Set<Id>{ contentId }, lock).get(contentId);
  }

  /** The running user's vote on each content record: by email key or by Voter__c, their own board vote first. */
  private static Map<Id, Vote__c> myVotes(Set<Id> contentIds, Boolean lock) {
    Set<String> keys = new Set<String>();
    for (Id contentId : contentIds) {
      keys.add(keyFor(contentId));
    }
    Id me = UserInfo.getUserId();
    List<Vote__c> found = lock
      ? [
          SELECT Id, Content__c, Source__c, Voter__c
          FROM Vote__c
          WHERE
            Voter_Key__c IN :keys
            OR (Content__c IN :contentIds
            AND Voter__c = :me)
          WITH SYSTEM_MODE
          FOR UPDATE
        ]
      : [
          SELECT Id, Content__c, Source__c, Voter__c
          FROM Vote__c
          WHERE
            Voter_Key__c IN :keys
            OR (Content__c IN :contentIds
            AND Voter__c = :me)
          WITH SYSTEM_MODE
        ];
    Map<Id, Vote__c> result = new Map<Id, Vote__c>();
    for (Vote__c v : found) {
      Vote__c current = result.get(v.Content__c);
      Boolean ownBoardVote = v.Voter__c == me && v.Source__c == 'Voting Board';
      if (current == null || ownBoardVote) {
        result.put(v.Content__c, v);
      }
    }
    return result;
  }

  private static HowToContent__c visibleContent(Id contentId) {
    List<HowToContent__c> found = [
      SELECT Id, Name, Product__c, Vote_Count__c
      FROM HowToContent__c
      WHERE Id = :contentId
      WITH USER_MODE
    ];
    if (found.isEmpty()) {
      throw error('This idea is no longer available. Refresh the list.');
    }
    return found[0];
  }

  private static AuraHandledException error(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
