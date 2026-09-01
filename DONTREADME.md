# sense

## Goals

### Rating

> Does `sense` use human feedback to score connections?

No.

Getting human feedback takes too much time.

Instead, `sense` leans on a large language model (LLM) to score connections.

### Coverage

> Does `sense` evaluate both single words and multiword phrases for double meanings?

Yes.

Both can act as pivots.

> Does `sense` evaluate every meaning of any English word?

No.

`sense` pulls its vocabulary from English Wiktionary entries.

> Does `sense` evaluate every meaning from Wiktionary?

No.

Evaluating every meaning in Wiktionary would cost too much.

`sense` throws out meanings that fail to meet both of the following criteria:

- 50% or more of Americans aged 10 or older are thought to know the meaning.

- The meaning is tagged as `idiomatic`, or the phrase has another meaning that 50% or more of Americans aged 10 or older are thought to know.

### Budget

> What is the target monthly budget?

The target is to keep monthly usage under $100. I set this limit because most productivity tools cost less than that.

## Scoring

> Can the connection score be negative?

No, because it's a percentage.

Specifically, it's the percentage of Americans 10 years or older who consider each meaning on topic.

- "Americans" pins it to a clear population, avoiding wishy-washy concepts like "native speakers" that are open to interpretation. Because the U.S. has the biggest number of native English speakers worldwide, it makes sense to treat it as the default audience.

- "10 years or older" filters out babies, making it easier to sanity-check the model output, as super obvious connections should hit near 100%.

> Is the connection score an integer?

Nah, it's a double. Doubles allow finer ordering.

> What model does `sense` use?

`sense` uses [`gemini-3.6-flash`](https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash) for these reasons:

- Among models that cost under $10 per million output tokens without batching, have a public API, and offer solid scoring, `gemini-3.6-flash` ranks highest on [Text Arena](https://arena.ai/leaderboard/text).

- `gemini-3.6-flash` is a production model.

- Less capable models tend to change their scores dramatically if the order of phrases to evaluate gets swapped. `gemini-3.6-flash` seems pretty resistant to this order dependency. Even though `sense` keeps the benchmark phrase in a fixed spot, the model's native resistance boosts confidence in the scores.

- `gemini-3.6-flash` allows running at a temperature of 0.

- Setting the thinking level to `minimal` effectively turns off thinking for this task.

- `gemini-3.6-flash` [supports structured outputs](https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash#:~:text=Supported-,Structured%20outputs,-Supported).

- `gemini-3.6-flash` [supports the Batch API](https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash#:~:text=Consumption%20options-,Batch%20API,-Supported).

> Does `sense` use a system prompt?

Yep.

If the list of phrases contains words that sound like commands, the model could treat them as instructions rather than just stuff to score. So the system prompt makes it crystal clear what's data and what's instruction.

> Does `sense` use a fixed `seed` for requests?

Yes.

`sense` sets the `seed` to `0`.

"[When seed is fixed to a specific value, the model makes a best effort to provide the same response for repeated requests.](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/content-generation-parameters#seed)"

> What's the temperature `sense` uses for scoring connections?

`sense` runs at a temperature of 0 for scoring connections. The whole point is to get the model to tap into its knowledge and spit out its best estimate.

> What thinking level does `sense` use?

`sense` uses `minimal` thinking.

Setting the thinking level to `minimal` effectively turns off thinking for this task.

Allowing thinking has these downsides:

- You could be charged for thinking tokens.

- Setting `temperature` to 0 might mess up the model's thinking, since [Gemini 3.x's reasoning capabilities are optimized for the default settings](https://ai.google.dev/gemini-api/docs/whats-new-gemini-3.5#parameter-updates:~:text=The%20following%20apply,the%20default%20settings.).

> Does `sense` use structured outputs?

Yes.

Using structured outputs makes sure the API response includes the scoring fields `sense` needs.

> How many items does each request in a batch evaluate?

Each request in a batch evaluates two items:

- The benchmark item, which sets the baseline across requests.

- The target item, which pairs a vocabulary entry with the topic passed in the command.

> What fields does each item in a rating request have?

Each item has three fields.

- `phrase`: A word or a multiword term.

- `meaning`: A Wiktionary gloss.

- `topic`: A topic to evaluate the phrase and meaning against.

> Does `sense` use JSON in a prompt to format items for evaluation?

No.

`sense` puts each item on its own line as an EDN map, which helps save token usage.

> What is the benchmark phrase?

`sense` uses `dog`.

The benchmark meaning is `A dull, unattractive girl or woman.` The benchmark topic is `ugly`.

A benchmark phrase should meet these criteria:

- At least two meanings are recognized by at least half of Americans 10 years or older.

- The benchmark meaning is so clearly tied to the topic that false positives get filtered out.

- A popular comic used the phrase in a double‑meaning joke in their stand‑up special.

- The phrase is a short word to minimize token costs across batch runs.

I watched Jimmy Carr's stand‑up specials on YouTube, joke by joke. Only the word `dog` met all the above criteria. Here's the joke: "[A dog is for life, not just for Christmas. So do be careful at the office party.](https://youtu.be/wwQS2YZhQ40?t=3875)"

> Is the benchmark item or the target item scored first?

The benchmark item gets scored first.

Scoring the benchmark item first makes sure it's evaluated before the target item's score is generated. This way, the benchmark item's context stays more alike across requests compared to using the reverse order.

> Are the connection scores normalized across multiple requests?

Yes.

Normalization makes the scores more consistent between different requests.

> What's the normalization formula?

It's piecewise:

$$
\bar{X} =
\begin{cases}
\frac{X \cdot \bar{B}}{B} & \text{if } X \leq B \\
100 - \frac{(100 - X)(100 - \bar{B})}{100 - B} & \text{if } X > B
\end{cases}
$$

where:

- $X$: The original score of a target item in the current request.

- $\bar{X}$: The normalized score of the target item.

- $B$: The score of the benchmark item in the current request.

- $\bar{B}$: The mean score of the benchmark item across all requests.

It's assumed that $B \neq 0$ and $B \neq 100$. If $B$ ever hits 0 or 100, the pair gets dropped during normalization.

This piecewise approach ensures that scores of 0% and 100% remain unchanged, while scores near the benchmark are adjusted proportionally to the benchmark item's difference from its mean.

> Does `sense` score each item multiple times and average the results?

No.

Running the same item a couple of times and averaging the results could potentially help smooth out any random noise.

But `sense` skips that. Making multiple requests per item incurs more API calls.

## Output

> How many columns does a TSV output file have?

A TSV output file comes with three columns:

1. The target phrase

1. The target meaning

1. The normalized connection score

> Does a TSV file group meanings by phrase?

Yes.

All the meanings of a target phrase appear together in a block.

Grouping all the meanings of the same phrase side by side helps you compare them when you're crafting a joke.

> Will `sense` overwrite an existing TSV output file?

No.

If the output TSV file is found in your current directory, the tool shuts down so you don't duplicate work.

> Are the phrase blocks sorted?

Yes.

> What are phrase blocks sorted by?

Phrase blocks are sorted by the difference between their highest and lowest scores.

> Are phrase blocks sorted in ascending or descending order?

Phrase blocks are sorted in descending order.

Phrases with the biggest contrast are meant to appear at the top of the file.

> Are the meanings sorted within each phrase block?

Yes.

> What are the meanings within each phrase block sorted by?

The meanings in each phrase block are sorted by their connection scores.

> Are meanings within each phrase block sorted in ascending or descending order?

Meanings within each block are sorted in descending order.

> Is a JSON output file a JSON array?

No.

A JSON output file is a JSON object. The object maps each phrase to an object whose keys are its meanings and whose values are raw score pairs for the benchmark and target items. If you adjust the formula, you can run the normalization again without incurring another batch API charge.

> Does `sense` split single words and multiword phrases into separate output files?

No.

- You'll probably want to search both single words and multiword phrases at once.

- If you ever need to split single words from multiword phrases, it's easy to filter the data in a spreadsheet by checking for spaces in the entries.

## Batching

> Does `sense` automatically loop to submit multiple batches?

No.

`sense` submits at most one batch per command invocation.

If an error occurs, loops on large datasets can cause runaway billing.

> Does `sense` require Tier 2?

Yes.

Tier 1 limits enqueued tokens for `gemini-3.6-flash` to [3,000,000](https://ai.google.dev/gemini-api/docs/rate-limits#:~:text=Gemini%203.6%20Flash-,3%2C000%2C000,-Gemini%203.5%20Flash). So evaluating the full dataset on Tier 1 would theoretically require invoking `sense` a bunch of times.

Tier 2 bumps the limits for `gemini-3.6-flash` up by roughly an order of magnitude, raising them to [400,000,000](https://ai.google.dev/gemini-api/docs/rate-limits#tier-2:~:text=Gemini%203.6%20Flash-,400%2C000%2C000,-Gemini%203.5%20Flash) enqueued tokens. In theory, this boost cuts down on the number of manual runs. If one run is enough, that'd be a batch made in heaven.

> Does `sense` wait for the batch to finish?

Yes.

`sense` stays running in the terminal to monitor the active batch.

If the batch completes successfully, `sense` processes the results into the output files.

> What's the polling interval?

The polling interval is set to 10 seconds.

Polling every second might overload the API.

> Does running multiple instances of `sense` cause duplicate batch requests?

No.

`sense` grabs a lock. The second instance run will fail to acquire the lock.

## Resuming

> Can `sense` keep going if it gets interrupted?

Yes.

If the `sense` process quits before making the output files, running the command again will pick up where it left off.

> Does a crash during a write operation corrupt the accumulated results?

No.

The tool swaps in a new JSON file atomically.
