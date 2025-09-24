#!/usr/bin/env python3
from __future__ import annotations

import sys
import re


def replace_nested_vars(text: str) -> str:
    """
    Collapse one level of nested ${...} expansions until none remain.
    Uses a compiled regex to match any ${...} containing exactly one nested ${...}
    and replaces the outer wrapper with the inner expansion.
    """
    nested_pattern = re.compile(r'\$\{[^{}]*\{([^{}]*)\}[^{}]*\}')
    prev = None
    while prev != text:
        prev = text
        text = nested_pattern.sub(r'${\1}', text)
    return text


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input_file> [output_file]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    with open(input_path, 'r') as infile:
        content = infile.read()

    result = replace_nested_vars(content)

    if output_path:
        with open(output_path, 'w') as outfile:
            outfile.write(result)
    else:
        sys.stdout.write(result)


if __name__ == '__main__':
    main() 