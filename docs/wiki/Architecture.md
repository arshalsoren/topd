# Architecture

topd has two Swift targets and a check runner.

| Target | Contents |
| --- | --- |
| `Sources/TopdCore` | Sampling (CPU, memory, storage, network, GPU via IOKit, processes via libproc), ranking, history, and preference rules. No UI code. |
| `Sources/topd` | The menu bar app: status item, popover, cards, charts, Preferences, themes, and launch at login. |
| `Checks/` | `topd-checks`, the behavior checks. It is an executable, not XCTest, so it runs with the Command Line Tools alone. |

## Sampling

- The sampler runs on a background queue. Results are published on the main queue.
- Every second while the popover is open, and every two seconds while it is closed.
- Process scanning runs only while the popover is open.
- Storage capacity is re-read every 30 seconds. The GPU accelerator service is looked up once.

## Design rules

- No network access and no telemetry.
- Charts use the validated data palette in every theme. Themes change only the chrome.
- Labels stay readable in every theme and in light and dark appearance.
