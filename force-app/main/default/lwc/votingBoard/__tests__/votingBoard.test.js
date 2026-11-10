import { createElement } from "lwc";
import VotingBoard from "c/votingBoard";
import getIdeas from "@salesforce/apex/VotingBoardService.getIdeas";
import castVote from "@salesforce/apex/VotingBoardService.castVote";
import withdrawVote from "@salesforce/apex/VotingBoardService.withdrawVote";
const ideas = () => JSON.parse(JSON.stringify(require("./data/ideas.json")));

jest.mock(
  "@salesforce/apex/VotingBoardService.getIdeas",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/VotingBoardService.castVote",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/VotingBoardService.withdrawVote",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = () => new Promise((resolve) => process.nextTick(resolve));
const text = (el) => el.textContent.replace(/\s+/g, " ").trim();

async function render() {
  const element = createElement("c-voting-board", { is: VotingBoard });
  document.body.appendChild(element);
  await flush();
  await flush();
  return element;
}

const root = (element) => element.shadowRoot;
const buttons = (element) => [...root(element).querySelectorAll("li button")];
const titles = (element) =>
  [...root(element).querySelectorAll("li h3")].map(text);
const announcement = (element) =>
  text(root(element).querySelector('[role="status"]'));
const refreshButton = (element) =>
  [...root(element).querySelectorAll("button")].find(
    (b) => text(b) === "Refresh ideas"
  );

describe("c-voting-board", () => {
  beforeEach(() => {
    getIdeas.mockResolvedValue(ideas());
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("lists each idea with its totals and a button named for the idea", async () => {
    const element = await render();
    expect(titles(element)).toEqual([
      "Recurring donations",
      "Volunteer shifts"
    ]);
    expect([...root(element).querySelectorAll("li p")].map(text)).toEqual([
      "1 vote, 2 requests, Nonprofit Success Pack",
      "0 votes, 1 request"
    ]);
    expect(buttons(element).map(text)).toEqual([
      "Vote for Recurring donations",
      "Withdraw vote for Volunteer shifts"
    ]);
    expect(root(element).querySelector("li a").getAttribute("href")).toBe(
      "/lightning/r/HowToContent__c/a01000000000001AAA/view"
    );
  });

  it("casts a vote, updates the idea in place, and announces the result", async () => {
    castVote.mockResolvedValue({ ...ideas()[0], votes: 5, voted: true });
    const element = await render();
    const button = buttons(element)[0];

    button.click();
    await flush();
    await flush();

    expect(castVote).toHaveBeenCalledWith({ contentId: "a01000000000001AAA" });
    expect(announcement(element)).toBe(
      "You voted for Recurring donations. It has 5 votes."
    );
    expect(buttons(element)[0]).toBe(button);
    expect(text(button)).toBe("Withdraw vote for Recurring donations");
    expect(titles(element)).toEqual([
      "Recurring donations",
      "Volunteer shifts"
    ]);
    expect(text(root(element).querySelector("li p"))).toBe(
      "5 votes, 2 requests, Nonprofit Success Pack"
    );
  });

  it("withdraws a vote and announces the new total", async () => {
    withdrawVote.mockResolvedValue({ ...ideas()[1], votes: 0, voted: false });
    const element = await render();

    buttons(element)[1].click();
    await flush();
    await flush();

    expect(withdrawVote).toHaveBeenCalledWith({
      contentId: "a01000000000002AAA"
    });
    expect(castVote).not.toHaveBeenCalled();
    expect(announcement(element)).toBe(
      "You withdrew your vote for Volunteer shifts. It has 0 votes."
    );
    expect(text(buttons(element)[1])).toBe("Vote for Volunteer shifts");
  });

  it("announces a refused vote and leaves the idea as it was", async () => {
    castVote.mockRejectedValue({
      body: { message: "Voting is closed for this content." }
    });
    const element = await render();

    buttons(element)[0].click();
    await flush();
    await flush();

    expect(announcement(element)).toBe(
      "Your vote for Recurring donations was not recorded. Voting is closed for this content."
    );
    expect(text(buttons(element)[0])).toBe("Vote for Recurring donations");
  });

  it("ignores a second click while the first is still being saved", async () => {
    let finish;
    castVote.mockReturnValue(
      new Promise((resolve) => {
        finish = resolve;
      })
    );
    const element = await render();

    buttons(element)[0].click();
    await flush();
    expect(buttons(element)[0].getAttribute("aria-disabled")).toBe("true");
    buttons(element)[0].click();
    finish({ ...ideas()[0], votes: 2, voted: true });
    await flush();
    await flush();

    expect(castVote).toHaveBeenCalledTimes(1);
    expect(buttons(element)[0].getAttribute("aria-disabled")).toBe("false");
  });

  it("keeps its order when totals change, and reorders only on refresh", async () => {
    castVote.mockResolvedValue({ ...ideas()[1], votes: 9, voted: true });
    const element = await render();
    buttons(element)[1].click();
    await flush();
    await flush();
    expect(titles(element)).toEqual([
      "Recurring donations",
      "Volunteer shifts"
    ]);

    getIdeas.mockResolvedValue([{ ...ideas()[1], votes: 9 }, ideas()[0]]);
    refreshButton(element).click();
    await flush();
    await flush();

    expect(getIdeas).toHaveBeenCalledTimes(2);
    expect(titles(element)).toEqual([
      "Volunteer shifts",
      "Recurring donations"
    ]);
    expect(announcement(element)).toBe("Ideas refreshed. 2 ideas.");
  });

  it("announces a second identical refresh too", async () => {
    const element = await render();
    refreshButton(element).click();
    await flush();
    await flush();
    const first = root(element).querySelector('[role="status"]').textContent;
    refreshButton(element).click();
    await flush();
    await flush();
    const second = root(element).querySelector('[role="status"]').textContent;
    expect(second).not.toBe(first);
    expect(second.trim()).toBe(first.trim());
  });

  it("says so when there are no ideas", async () => {
    getIdeas.mockResolvedValue([]);
    const element = await render();
    expect(text(root(element).querySelector(".slds-card__body"))).toContain(
      "There are no ideas to vote on."
    );
    expect(buttons(element)).toEqual([]);
  });

  it("says so when the ideas cannot be loaded", async () => {
    getIdeas.mockRejectedValue({ body: { message: "Insufficient access." } });
    const element = await render();
    expect(text(root(element).querySelector('[role="alert"]'))).toBe(
      "The ideas could not be loaded. Insufficient access."
    );
  });
});
