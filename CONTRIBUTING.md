# Contributing to the infrastructure codebase

## Code Style

### YAML

- Use 2 spaces for indentation.
- Use single quotes for strings.
- Use double quotes for strings that contain single quotes.
- Use single quotes for strings that contain double quotes.
- Use double quotes for strings that contain single quotes.
- Use double quotes for strings that contain double quotes.

### This file is TODO.


### Regex searches that'll help you find and replace things:

All of the following will be provided for a vs code-like editor.

- `([^\$])(\${1}[a-z]+)` with `$1$$$2` - fix compose-spec `configs:` section variables that are intended to be e.g. bash variables, not docker compose variables. Simple, use case-sensitive search and replace!