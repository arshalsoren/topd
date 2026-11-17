# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability
reporting on this repository (Security tab, "Report a vulnerability"). Include the version,
macOS version, and steps to reproduce.

## Scope

topd reads process and system statistics locally. It does not use the network, does not
collect telemetry, and does not request elevated privileges. It can change nothing on the
system except its own launch-at-login registration.

Reports about these properties are especially welcome: any network access, any data written
outside the app's preferences, or any way to affect other processes.
