/**
 * The voting board's service: lists the ideas, and casts or withdraws the signed-in person's vote.
 *
 * A vote is keyed on the content and the voter's email address in lower case (ADR 0003), so a person who both
 * asked for an idea and votes for it counts once. A vote that came from the person's request cannot be withdrawn
 * here: it stays while the request points to the content.
 *
 * Team members hold no access to Vote__c, so this class reads and writes votes in system mode, and only ever
 * for the running user, whose key it builds itself. Content is read in user mode, so a person sees only the
 * ideas and fields their permissions allow. The class runs with sharing, so a vote can only be cast on content
 * the person can see.
 */
public with sharing class VotingBoardService {
  @TestVisible
  private static final String FROM_REQUEST = 'Your vote comes from your request for this idea. It stays while your request points to it.';

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
    Set<String> keys = new Set<String>();
    for (HowToContent__c c : ideas) {
      keys.add(keyFor(c.Id));
    }
    Map<Id, Vote__c> mine = new Map<Id, Vote__c>();
    for (Vote__c v : [
      SELECT Content__c, Source__c
      FROM Vote__c
      WHERE Voter_Key__c IN :keys
      WITH SYSTEM_MODE
    ]) {
      mine.put(v.Content__c, v);
    }
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
    if (myVote(c.Id) == null) {
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
    return new Idea(visibleContent(contentId), myVote(c.Id));
  }

  /** Withdraws the running user's board vote, if there is one. A vote that came from a request stays. */
  @AuraEnabled
  public static Idea withdrawVote(Id contentId) {
    HowToContent__c c = visibleContent(contentId);
    Vote__c mine = myVote(c.Id);
    if (mine != null) {
      if (mine.Source__c == 'Request') {
        throw error(FROM_REQUEST);
      }
      try {
        Database.delete(mine, true, AccessLevel.SYSTEM_MODE);
      } catch (DmlException e) {
        throw error(e.getDmlMessage(0));
      }
    }
    return new Idea(visibleContent(contentId), myVote(c.Id));
  }

  private static String myEmail() {
    return UserInfo.getUserEmail().toLowerCase();
  }

  private static String keyFor(Id contentId) {
    return String.valueOf(contentId) + myEmail();
  }

  private static Vote__c myVote(Id contentId) {
    String key = keyFor(contentId);
    List<Vote__c> found = [
      SELECT Id, Content__c, Source__c
      FROM Vote__c
      WHERE Voter_Key__c = :key
      WITH SYSTEM_MODE
    ];
    return found.isEmpty() ? null : found[0];
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
