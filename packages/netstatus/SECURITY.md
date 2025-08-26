# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please send an email to [security@yourcompany.com].

Please include:

- A description of the vulnerability
- Steps to reproduce the issue
- Affected versions
- Any possible mitigations

We will respond to security reports within 48 hours and provide regular updates on our progress.

## Security Considerations

This package makes HTTP requests to external endpoints for internet connectivity checks. Consider:

- Use your own controlled endpoints instead of public services for sensitive applications
- Be aware that ping URLs and DNS queries may be logged by network infrastructure
- Configure appropriate timeouts and retry limits to prevent resource exhaustion
- Validate that your ping endpoints return expected responses to prevent false positives
