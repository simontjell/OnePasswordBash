# OnePasswordBash
A very simple bash function that helps find passwords using the 1Password CLI.

## Usage
```bash
opp Github
```

If there is a single match for 'Github', the password will be copied to the clipboard.

If there are no matches, this is reported as an error.

If multiple matches are found, the items are provided as an indexed list. Use the index to get the specific item:

```bash
opp Github 2
```

And item can also be fetched with its full content:
```bash
opp Github 2 --raw
```

This wil provide the item in JSON format.