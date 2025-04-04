# Contributing to MomentGif

Thank you for your interest in contributing to MomentGif! This document provides guidelines and instructions for contributing to this project.

## Prerequisites

Before you begin, ensure you have the following:

- A Mac computer running macOS (preferably the latest version)
- Xcode (latest version recommended)
- Git installed on your machine
- A GitHub account

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/MomentGif.git
   cd MomentGif
   ```
3. Add the original repository as an upstream remote:
   ```bash
   git remote add upstream https://github.com/cxhello/MomentGif.git
   ```

## Development Workflow

1. Create a new branch for your feature or bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and commit them with descriptive commit messages:
   ```bash
   git commit -m "Add feature: your feature description"
   ```

3. Keep your branch updated with the main repository using rebase:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

4. Resolve any conflicts that may arise during the rebase process

5. Push your changes to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Submit a Pull Request (PR) to the main repository

## Pull Request Guidelines

- Provide a clear, descriptive title for your PR
- Include a detailed description of the changes you've made
- Reference any related issues using the GitHub issue number (#123)
- Ensure your code follows the project's coding style and conventions
- Make sure all tests pass and add new tests for new functionality

## Coding Standards

- Follow Swift style and coding conventions
- Write clear, descriptive comments and documentation
- Ensure your code is properly formatted
- Use meaningful variable and function names

## Commit Message Guidelines

- Use the imperative mood ("Add feature" not "Added feature")
- Keep the first line under 50 characters
- Include the type of change (feature, fix, docs, etc.)
- Reference issues when applicable

## Localization

MomentGif supports multiple languages. If you're adding user-facing strings:

- Add them to the appropriate localization files
- Provide English strings at minimum
- Consider adding translations for other supported languages if possible

## Testing

- Test your changes on different iOS devices and versions if possible
- Ensure your changes don't break existing functionality
- Add unit tests for new features when appropriate

## Code Review

All submissions require review. We use GitHub pull requests for this purpose.

## License

By contributing to MomentGif, you agree that your contributions will be licensed under the project's license.

Thank you for your contributions! 