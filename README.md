# sense

## A Sense of Humor

> What is this tool about?

`sense` rates phrases for double meanings.

## Setup

> How do I set up `sense`?

1. Make sure you're using a Mac with Apple silicon.

1. Make sure the billing account linked to your Google AI Studio project is on Tier 2.

1. Install [Homebrew](https://brew.sh/#install).

1. Install [devenv](https://github.com/cachix/devenv/blob/83e8d7d34bdebad98ab936b6af53d57ae67af420/docs/src/getting-started.md#installation).

1. Open a terminal.

1. Copy an API key from [Google AI Studio](https://aistudio.google.com/api-keys).

1. Run these commands:
   ```bash
   mkdir -p ~/.config/sense
   pbpaste > ~/.config/sense/key
   git clone https://github.com/8ta4/sense
   cd sense
   devenv allow
   devenv shell download
   ```

## Usage

> How do I run `sense`?

1. Open a terminal.

1. Make a YAML config file like this in the current directory.

   ```yaml
   meaning: "Used other than figuratively or idiomatically: see on, plate."
   phrase: "on one's plate"
   theme: "fat"
   ```

1. Run the command with your configuration file.

   ```bash
   sense fat.yaml
   ```

Once the API batches finish, `sense` will drop two files into your current directory:

- fat.tsv: a file that contains normalized scores

- fat.json: a file that contains raw scores

> Can I run `sense` only on idioms?

Yes.

If you set `idioms: true` in your YAML file, `sense` will only run idioms.

Checking the whole vocabulary:

- costs a lot.

- gives you phrases that only have one meaning.

Limiting the run to idioms:

- costs a fraction of the price.

- guarantees multiple meanings because an idiom has both a literal meaning and an idiomatic one.

For common topics, you can evaluate the whole vocabulary without `idioms: true` to prioritize recall. Finding as many potential double meanings as possible may be worth the extra cost and review time.

For niche topics, you can set `idioms: true` to prioritize precision. You might prefer a reliable set of double meanings at a lower cost rather than complete coverage.
