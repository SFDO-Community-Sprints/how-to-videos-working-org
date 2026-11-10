import { LightningElement } from "lwc";
import getIdeas from "@salesforce/apex/VotingBoardService.getIdeas";
import castVote from "@salesforce/apex/VotingBoardService.castVote";
import withdrawVote from "@salesforce/apex/VotingBoardService.withdrawVote";

const count = (n, one, many) => `${n} ${n === 1 ? one : many}`;

const messageFrom = (error) =>
  error?.body?.message || error?.message || "Something went wrong.";

/**
 * Lists the ideas with their vote totals and a Vote or Withdraw vote button for each.
 * Your own vote updates its idea in place and is announced in a live region.
 * The order and other people's votes change only when you choose Refresh ideas.
 * A vote that came from your own request has no button: it stays while the request points to the idea.
 * Submit an idea opens the HowTo_Submit_Idea flow in place, and focus returns to the button when it closes.
 */
export default class VotingBoard extends LightningElement {
  ideas = [];
  busyIds = [];
  loading = true;
  loadError;
  announcement = "";
  submitting = false;
  focusAfterRender;

  connectedCallback() {
    this.load(false);
  }

  renderedCallback() {
    if (this.focusAfterRender) {
      const target = this.refs[this.focusAfterRender];
      this.focusAfterRender = undefined;
      target?.focus();
    }
  }

  get submitExpanded() {
    return this.submitting ? "true" : "false";
  }

  handleSubmitToggle() {
    this.submitting = !this.submitting;
    this.focusAfterRender = this.submitting ? "submitHeading" : "submitButton";
  }

  handleSubmitClose() {
    this.submitting = false;
    this.focusAfterRender = "submitButton";
  }

  handleFlowStatus(event) {
    if (
      event.detail.status === "FINISHED" ||
      event.detail.status === "FINISHED_SCREEN"
    ) {
      this.submitting = false;
      this.focusAfterRender = "submitButton";
      this.announce("Your idea was sent to the Triage Queue.");
    }
  }

  get hasIdeas() {
    return this.ideas.length > 0;
  }

  get rows() {
    return this.ideas.map((idea) => {
      const busy = this.busyIds.includes(idea.id);
      return {
        ...idea,
        url: `/lightning/r/HowToContent__c/${idea.id}/view`,
        summary: [count(idea.votes, "vote", "votes"), idea.product]
          .filter(Boolean)
          .join(", "),
        action: idea.voted ? "Withdraw vote" : "Vote",
        // Built here, not in the template: the template compiler drops a leading space in a text node.
        forTitle: ` for ${idea.title}`,
        buttonClass: idea.voted
          ? "slds-button slds-button_neutral"
          : "slds-button slds-button_brand",
        busy: busy ? "true" : "false"
      };
    });
  }

  async load(announce) {
    this.loading = !this.hasIdeas;
    try {
      this.ideas = await getIdeas();
      this.loadError = undefined;
      if (announce) {
        this.announce(
          `Ideas refreshed. ${count(this.ideas.length, "idea", "ideas")}.`
        );
      }
    } catch (error) {
      this.loadError = messageFrom(error);
      if (announce) {
        this.announce(`The ideas could not be refreshed. ${this.loadError}`);
      }
    } finally {
      this.loading = false;
    }
  }

  handleRefresh() {
    this.load(true);
  }

  async handleToggle(event) {
    const id = event.currentTarget.dataset.id;
    const idea = this.ideas.find((i) => i.id === id);
    if (!idea || this.busyIds.includes(id)) {
      return;
    }
    this.busyIds = [...this.busyIds, id];
    try {
      const updated = idea.voted
        ? await withdrawVote({ contentId: id })
        : await castVote({ contentId: id });
      this.ideas = this.ideas.map((i) => (i.id === id ? updated : i));
      const total = count(updated.votes, "vote", "votes");
      this.announce(
        updated.voted
          ? `You voted for ${updated.title}. It has ${total}.`
          : `You withdrew your vote for ${updated.title}. It has ${total}.`
      );
    } catch (error) {
      const verb = idea.voted ? "withdrawal of your vote" : "vote";
      this.announce(
        `Your ${verb} for ${idea.title} was not recorded. ${messageFrom(error)}`
      );
    } finally {
      this.busyIds = this.busyIds.filter((b) => b !== id);
    }
  }

  // A live region speaks only when its text changes, so a repeated message gets a silent trailing space.
  announce(message) {
    this.announcement =
      this.announcement === message ? `${message}\u00a0` : message;
  }
}
