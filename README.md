# Always Tracking

A WoW Forever addon that keeps your gathering tracking on.

- Checks every 5 minutes (configurable) and turns **Find Herbs** back on if no tracking is active.
- Turns it back on 10 seconds after you are resurrected (time to buff up), and after login or `/reload`.
- Waits out combat, casting, flights and the global cooldown, then retries.
- Stays off in battlegrounds and arenas.
- Leaves another tracking you picked yourself alone (unless override is on).

## Options

Click **Always Tracking** in the addon compartment (the button at the top of the minimap), type
`/at options`, or open Options > AddOns > Always Tracking. The panel sets the tracking to keep on,
how often to check, how long to wait after resurrection, whether to replace another tracking, and
the chat message.

## Commands

| Command | What it does |
| --- | --- |
| `/at` | Show status |
| `/at options` | Open the options panel |
| `/at on` / `/at off` | Turn the addon on or off |
| `/at track <herbs\|minerals\|treasure\|fish>` | Choose which tracking to keep on |
| `/at interval <minutes>` | How often to check (1-60) |
| `/at rezdelay <seconds>` | Wait after resurrection before tracking (0-120, default 10) |
| `/at now` | Check right away |
| `/at override` | Also replace another tracking that is on |
| `/at quiet` | Toggle the chat message when tracking is turned back on |

`/alwaystracking` works too.

## Key press mode

Some clients refuse to turn tracking on from a timer. If that happens, the addon says so in chat
and from then on turns tracking on with your next movement key or click instead.

## Development

Link the repository into the game's AddOns folder so changes show up after a `/reload`:

```powershell
New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\AlwaysTracking" -Target "E:\Projects\AlwaysTracking"
```

## Releasing

Pushing a version tag such as `v1.1.0` publishes the addon to CurseForge and GitHub. See
[RELEASING.md](RELEASING.md) for the steps, the setup and what to do when a release fails.

## License

MIT
