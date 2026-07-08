# sense

## Goals

### Rating

> Does `sense` use human feedback to rate associations?

No. Getting human feedback takes too much time.

Instead, `sense` leans on a large language model (LLM) to rate associations.

### Coverage

> Does `sense` evaluate every English word?

No. `sense` pulls its vocabulary from English Wiktionary entries.

> Does `sense` evaluate every English word in Wiktionary?

No. Evaluating every English word in Wiktionary would cost too much.

`sense` narrows its scope based on the following criteria:

- Wiktionary tags the phrase as `English lemmas`.

- About half of Americans aged 10 and up are thought to know the phrase's most common meaning.

### Budget

> What is the target monthly budget?

The target is to keep monthly usage under $100. I set this limit because most productivity tools cost less than that.

## Prompting

> Does `sense` use a system prompt?

Yep. If the list of phrases contains words that sound like commands, the model could treat them as instructions rather than just stuff to score. So the system prompt makes it crystal clear what's data and what's instruction.

> What's the temperature `sense` uses for rating associations?

`sense` runs at a temperature of 0 for rating associations. The whole point is to get the model to tap into its knowledge and spit out its best estimate.

## Scoring

> How many phrases are sent to the LLM per rating request?

Each request includes two phrases: the benchmark phrase plus another one.

> Are the association scores normalized across multiple requests?

Yes. Normalization makes the scores more consistent between different requests.

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
