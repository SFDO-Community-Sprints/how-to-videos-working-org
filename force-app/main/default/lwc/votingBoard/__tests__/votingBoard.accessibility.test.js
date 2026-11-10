import { createElement } from "lwc";
import VotingBoard from "c/votingBoard";
import getIdeas from "@salesforce/apex/VotingBoardService.getIdeas";
import castVote from "@salesforce/apex/VotingBoardService.castVote";
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

async function render() {
  const element = createElement("c-voting-board", { is: VotingBoard });
  document.body.appendChild(element);
  await flush();
  await flush();
  return element;
}

describe("c-voting-board accessibility", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("is accessible with ideas listed", async () => {
    getIdeas.mockResolvedValue(ideas());
    const element = await render();
    await expect(element).toBeAccessible();
  });

  it("is accessible after a vote is announced", async () => {
    getIdeas.mockResolvedValue(ideas());
    castVote.mockResolvedValue({ ...ideas()[0], votes: 2, voted: true });
    const element = await render();
    element.shadowRoot.querySelector("li button").click();
    await flush();
    await flush();
    await expect(element).toBeAccessible();
  });

  it("is accessible with no ideas", async () => {
    getIdeas.mockResolvedValue([]);
    const element = await render();
    await expect(element).toBeAccessible();
  });

  it("is accessible when loading fails", async () => {
    getIdeas.mockRejectedValue({ body: { message: "Insufficient access." } });
    const element = await render();
    await expect(element).toBeAccessible();
  });
});
