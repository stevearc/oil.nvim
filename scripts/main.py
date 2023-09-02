#!/usr/bin/env python
import argparse
import os
import sys

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
DOC = os.path.join(ROOT, "doc")


def main() -> None:
    """Generate docs"""
    sys.path.append(HERE)
    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument("command", choices=["generate", "lint"])
    args = parser.parse_args()
    if args.command == "generate":
        import generate

        generate.main()
    elif args.command == "lint":
        from nvim_doc_tools import lint_md_links

        files = [os.path.join(ROOT, "README.md")] + [
            os.path.join(DOC, file) for file in os.listdir(DOC) if file.endswith(".md")
        ]
        lint_md_links.main(ROOT, files)


if __name__ == "__main__":
    main()
