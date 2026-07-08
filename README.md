# sense

## A Sense of Humor

> What is this tool about?

`sense` rates phrases for double meanings.

## Setup

> How do I set up `sense`?

1. Make sure you're using a Mac with Apple silicon.

1. Install [Homebrew](https://brew.sh/#install).

1. Open a terminal.

1. Copy an API key from the Google AI Studio website.

1. Run these commands:
   ```bash
   brew install 8ta4/sense/sense
   mkdir -p ~/.config/sense/
   pbpaste > ~/.config/sense/key
   ```

## Usage

> How do I run `sense`?

1. Open a terminal.

1. Make a `.yaml` config file like this in the current directory.

   ```yaml
   benchmark: "on one's plate"
   theme: "fat"
   ```

1. Run the command with your configuration file.

   ```bash
   sense fat.yaml
   ```

Once the API batches finish, `sense` will drop two files into your current directory:

- fat.tsv: a file that contains normalized scores

- fat.json: a file that contains raw scores
