/**
 * The voting board's service: lists the ideas, and casts or withdraws the signed-in person's vote.
 *
 * Team members hold no access to Vote__c (ADR 0003), so this class reads and writes votes in system mode,
 * and only ever for the running user: the voter is always UserInfo.getUserId(), and the key is built here.
 * Content is read in user mode, so a person sees only the ideas and fields their permissions allow.
 * The class runs with sharing, so a vote can only be cast on content the person can see.
 */
public with sharing class VotingBoardService {
  /** One idea on the board, with its totals and whether the running user has voted for it. */
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
    public Integer requests;
    @AuraEnabled
    public Boolean voted;

    Idea(HowToContent__c c, Boolean voted) {
      this.id = c.Id;
      this.title = c.Name;
      this.product = c.Product__c;
      this.votes = c.Vote_Count__c == null ? 0 : c.Vote_Count__c.intValue();
      this.requests = c.Request_Count__c == null
        ? 0
        : c.Request_Count__c.intValue();
      this.voted = voted;
    }
  }

  /** The ideas (content with the status Submitted), most votes first, then by title. */
  @AuraEnabled
  public static List<Idea> getIdeas() {
    List<HowToContent__c> ideas = [
      SELECT Id, Name, Product__c, Vote_Count__c, Request_Count__c
      FROM HowToContent__c
      WHERE Status__c = 'Submitted'
      WITH USER_MODE
      ORDER BY Vote_Count__c DESC, Name ASC
      LIMIT 500
    ];
    Set<Id> votedFor = votedFor(new Map<Id, HowToContent__c>(ideas).keySet());
    List<Idea> result = new List<Idea>();
    for (HowToContent__c c : ideas) {
      result.add(new Idea(c, votedFor.contains(c.Id)));
    }
    return result;
  }

  /** Casts the running user's vote. Casting twice leaves one vote. Returns the idea with its new total. */
  @AuraEnabled
  public static Idea castVote(Id contentId) {
    HowToContent__c c = visibleContent(contentId);
    Vote__c vote = new Vote__c(
      Content__c = c.Id,
      Voter__c = UserInfo.getUserId(),
      Voter_Key__c = keyFor(c.Id)
    );
    try {
      Database.upsert(
        vote,
        Vote__c.Voter_Key__c,
        true,
        AccessLevel.SYSTEM_MODE
      );
    } catch (DmlException e) {
      throw error(e.getDmlMessage(0));
    }
    return new Idea(visibleContent(contentId), true);
  }

  /** Withdraws the running user's vote, if there is one. Returns the idea with its new total. */
  @AuraEnabled
  public static Idea withdrawVote(Id contentId) {
    HowToContent__c c = visibleContent(contentId);
    String key = keyFor(c.Id);
    List<Vote__c> mine = [
      SELECT Id
      FROM Vote__c
      WHERE Voter_Key__c = :key
      WITH SYSTEM_MODE
    ];
    try {
      Database.delete(mine, true, AccessLevel.SYSTEM_MODE);
    } catch (DmlException e) {
      throw error(e.getDmlMessage(0));
    }
    return new Idea(visibleContent(contentId), false);
  }

  private static String keyFor(Id contentId) {
    return String.valueOf(contentId) + String.valueOf(UserInfo.getUserId());
  }

  private static Set<Id> votedFor(Set<Id> contentIds) {
    Set<Id> result = new Set<Id>();
    for (Vote__c v : [
      SELECT Content__c
      FROM Vote__c
      WHERE Voter__c = :UserInfo.getUserId() AND Content__c IN :contentIds
      WITH SYSTEM_MODE
    ]) {
      result.add(v.Content__c);
    }
    return result;
  }

  private static HowToContent__c visibleContent(Id contentId) {
    List<HowToContent__c> found = [
      SELECT Id, Name, Product__c, Vote_Count__c, Request_Count__c
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
