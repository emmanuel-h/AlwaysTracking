# Always Tracking

A WoW Forever addon that keeps your gathering tracking on.

- Checks every 5 minutes (configurable) and turns **Find Herbs** back on if no tracking is active.
- Turns it back on right after you are resurrected, and after login or `/reload`.
- Waits out combat, casting, flights and the global cooldown, then retries.
- Stays off in battlegrounds and arenas.
- Leaves another tracking you picked yourself alone (unless override is on).

## Commands

| Command | What it does |
| --- | --- |
| `/at` | Show status |
| `/at on` / `/at off` | Turn the addon on or off |
| `/at track <herbs\|minerals\|treasure\|fish>` | Choose which tracking to keep on |
| `/at interval <minutes>` | How often to check (1-60) |
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

Push a tag such as `v1.0.0`. The release workflow packages the addon with the
[BigWigs packager](https://github.com/BigWigsMods/packager), uploads it to CurseForge and attaches
the zip to a GitHub release. The CurseForge upload needs the `CF_API_TOKEN` repository secret and
the `X-Curse-Project-ID` line in the toc.

## License

MIT
