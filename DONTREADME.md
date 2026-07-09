# sense

## Goals

### Rating

> Does `sense` use human feedback to rate associations?

No.

Getting human feedback takes too much time.

Instead, `sense` leans on a large language model (LLM) to rate associations.

### Coverage

> Does `sense` evaluate every English word?

No.

`sense` pulls its vocabulary from English Wiktionary entries.

> Does `sense` evaluate every English word in Wiktionary?

No.

Evaluating every English word in Wiktionary would cost too much.

`sense` narrows its scope based on the following criteria:

- Wiktionary tags the phrase as `English lemmas`.

- About half of Americans aged 10 and up are thought to know the phrase's most common meaning.

> Does `sense` process a Wiktionary dump?

No.

`sense` pulls the `wiktionary.tsv` file from the `prevalence-data` repo.

> Does `sense` check both single words and multi-word phrases for double meanings?

Yes.

Both can act as pivots:

- "[Obese children put a lot of strain on the NHS, not to mention seesaws and swings.](https://youtu.be/6wplEAkNXow?t=1671)"

- "[She recently went to her GP just for the annual checkup. She was classified by her own GP as being morbidly obese. Who came up with that term? That's so unnecessarily harsh, morbidly obese as if she doesn't have enough on her plate.](https://youtu.be/Tehlt1P-NM0?t=2907)"

### Budget

> What is the target monthly budget?

The target is to keep monthly usage under $100. I set this limit because most productivity tools cost less than that.

## Scoring

> What model does `sense` use?

`sense` uses [`gemini-3.5-flash`](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash) for these reasons:

- On Text Arena, `gemini-3.5-flash` tops the list as the highest-ranking model that's under $10 per million output tokens without batching.

- `gemini-3.5-flash` is a production model.

- Less capable models tend to change their scores dramatically if the order of phrases to evaluate gets swapped. `gemini-3.5-flash` seems pretty resistant to this order dependency. Even though `sense` keeps the benchmark phrase in a fixed spot, the model's native resistance boosts confidence in the scores.

- `gemini-3.5-flash` allows running at a temperature of 0.

- Setting the thinking level to `minimal` effectively turns off thinking for this task.

- `gemini-3.5-flash` [supports structured outputs](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash#:~:text=Supported-,Structured%20outputs,-Supported).

- `gemini-3.5-flash` [supports the Batch API](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash#:~:text=Consumption%20options-,Batch%20API,-Supported).

> Does `sense` use a system prompt?

Yep.

If the list of phrases contains words that sound like commands, the model could treat them as instructions rather than just stuff to score. So the system prompt makes it crystal clear what's data and what's instruction.

> What's the temperature `sense` uses for rating associations?

`sense` runs at a temperature of 0 for rating associations. The whole point is to get the model to tap into its knowledge and spit out its best estimate.

> What thinking level does `sense` use?

`sense` uses `minimal` thinking.

Setting the thinking level to `minimal` effectively turns off thinking for this task.

Allowing thinking has these downsides:

- You could be charged for thinking tokens.

- Setting `temperature` to 0 might mess up the model's thinking, since [Gemini 3.x's reasoning capabilities are optimized for the default settings](https://ai.google.dev/gemini-api/docs/whats-new-gemini-3.5#parameter-updates:~:text=The%20following%20apply,the%20default%20settings.).

> Does `sense` use structured outputs?

Yes.

Using structured outputs makes sure the API response includes the scoring fields `sense` needs.

> How many phrases are sent to the LLM per rating request?

Each request includes two phrases: the benchmark phrase plus another one.

> Are the association scores normalized across multiple requests?

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

- $X$: The original score of a target phrase in the current request.

- $\bar{X}$: The normalized score of the target phrase.

- $B$: The score of the benchmark phrase in the current request.

- $\bar{B}$: The mean score of the benchmark phrase across all requests.

It is assumed that $B \neq 0$ and $B \neq 100$. If $B$ ever hits 0 or 100, that request gets tossed.

This piecewise approach ensures that scores of 0% and 100% remain unchanged, while scores near the benchmark are adjusted proportionally to the benchmark phrase's difference from its mean.

> Does `sense` score each phrase multiple times and average the results?

No.

Running the same phrase a couple of times and averaging the results could potentially help smooth out any random noise.

But `sense` skips that. Making multiple requests per phrase incurs more API calls.

## Output

> How many columns does a TSV output file have?

A TSV output file has two columns.

The first column has the target phrase, and the second one has the normalized score. The entries are ordered by descending score.

> Is a JSON output file a JSON array?

No.

A JSON output file is a JSON object. The keys hold the target phrases, while the values hold the maps the API returns.

> Does `sense` split single words and multi-word phrases into separate output files?

No.

- You'll probably want to search both single words and multi-word phrases at once.

- If you ever need to split single words from multi-word phrases, it's easy to filter the data in a spreadsheet by checking for spaces in the entries.

## Resumability

> Can `sense` keep going if it gets interrupted?

Yes.

If the `sense` process quits before making the output files, running the command again will pick up where it left off.

> Does `sense` write an incomplete JSON file to the current working directory?

No.

When it's gathering data, `sense` puts the growing JSON file into `~/.local/state/sense/`. `sense` only drops completed files into the current working directory when the JSON file is complete.

## Safety

> Will `sense` overwrite an existing TSV output file?

No.

If the output TSV file is found in your current directory, the tool shuts down so you don't duplicate work.

> Does a crash during a write operation corrupt the accumulated results?

No.

The tool swaps in a new JSON file atomically.

> Does running multiple instances of `sense` cause duplicate batch requests?

No.

`sense` grabs a lock on the state directory. The second instance run will fail to acquire the lock.
