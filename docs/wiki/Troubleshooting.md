# Troubleshooting

| Symptom | Fix |
| --- | --- |
| `./run.sh` cannot find the Swift compiler | Run `xcode-select --install`, then try again. |
| "topd is already running" | It is already in the menu bar. Restart with `pkill -x topd; ./run.sh`. |
| GPU card says "Not reported on this Mac" | The GPU counter is not exposed on this Mac. The other cards still work. |
| Launch at login asks for approval | Allow topd in System Settings, General, Login Items. |
| Launch at login stopped after moving the repo | Turn it off, run `./run.sh` from the new location, and turn it on again. |
| Process shows as `pid N` | topd could not read that process's name. This is normal for processes owned by other users. |

Still stuck? Open a discussion in the Q&A category, or an issue with your macOS version and steps to reproduce.
