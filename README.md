# sense

## A Sense of Humor

> What is this tool about?

`sense` rates phrases for double meanings.

## Usage

1. Open the terminal.

1. Make a `.yaml` config file named `fat.yaml` in the current directory.

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
