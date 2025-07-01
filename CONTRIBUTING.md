# Contributing to chuck-stack-core

Thank you for your interest in contributing to chuck-stack-core! We welcome contributions from the community.

## Contributor License Agreement (CLA)

**Important**: All contributors must sign our Contributor License Agreement (CLA) before we can accept your contributions.

### Why we need a CLA

The CLA allows us to:
- Protect the project from legal issues
- Maintain the option to dual-license the project (open source + commercial)
- Ensure all contributions can be distributed under our chosen licenses

### How to sign the CLA

1. When you submit your first pull request, the CLA Assistant bot will comment
2. Read the [CLA terms](.github/CLA.md)
3. Comment "I have read and agree to the Contributor License Agreement" on the PR
4. The bot will verify your signature and mark it as complete

### What the CLA covers

- Grants us the right to use and relicense your contributions
- Confirms you have the right to submit the contributions
- Covers all your contributions to this project (past and future)

## Development Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests in the test environment (see test/TESTING_NOTES.md)
5. Commit your changes following our commit message conventions
6. Push to your fork
7. Open a Pull Request

## Code Style

- Follow existing code patterns in the codebase
- For Nushell modules, see modules/MODULE_DEVELOPMENT.md
- Always escape opening parentheses in Nushell string interpolation
- Use `api` schema for function calls, not `private` schema

## Testing

All changes must include appropriate tests. See:
- `test/TESTING_NOTES.md` for testing guidelines
- `test/suite/` for example tests

## Questions?

If you have questions about contributing, please:
- Check existing documentation
- Open an issue for clarification
- Contact us at [your-email@chuck-stack.org]

We appreciate your contributions to making chuck-stack-core better!