# Demo recording script (60 to 90 seconds)

Record the Android emulator with the sync build (`--dart-define=API_BASE_URL=http://10.0.2.2:3000`) and a terminal showing the database. Practise once without recording.

## Before recording

1. Start the API and PostgreSQL (see the README).
2. Clear the app's data so the first run shows: `adb shell pm clear com.example.daily_anchor`.
3. Open a terminal and keep this ready to show the database count:
   `docker compose -f api/docker-compose.yml exec -T db psql -U daily_anchor -d daily_anchor -c "select type, count(*) from events group by type;"`
4. Make the text readable: phone in portrait, brightness up, do-not-disturb on.

## Shot list

| Time | What to show | Say (short) |
|---|---|---|
| 0:00 | Launch. The splash, then the "Before you start" popup. Tap "I understand" | "A learning project, not a medical product." |
| 0:08 | Swipe or tap through the four intro cards, then Get started | |
| 0:15 | Empty Today screen. Tap an idea ("Short walk"), Save. Add a second routine | "Routines are the person's own." |
| 0:25 | Mark one done, then Undo, then done again | "Everything is saved on the phone first." |
| 0:32 | Settings: set text to 200%, switch on high contrast, go back | "Readable at 200% text, with a strong high-contrast theme." |
| 0:45 | Word exercise: start it, wait for the words, choose, show the result | "A short word exercise, no pass or fail." |
| 0:58 | Turn airplane mode on. Complete a routine, undo, complete again. Point at "Waiting to sync (3 items)" | "No connection. Nothing is lost, and the app never blocks." |
| 1:10 | Turn airplane mode off. Wait a few seconds for "All saved". Switch to the terminal and run the database command | "Each event arrived exactly once." |
| 1:20 | Open Progress | "Totals come from the server." |
| 1:25 | Show the GitHub page: tests and the green CI badge once CI has run, then the README | "Tests, CI and a decision log." |

## Notes

- Airplane mode on the emulator: swipe down for quick settings, or run `adb shell cmd connectivity airplane-mode enable` and `... disable`.
- To show "duplicates" explicitly, send the same batch twice from a terminal. The second reply lists every id under `duplicates`, and the database count does not change.
- Do not show real personal information. Everything in the app is made up.
- Say plainly that this is a learning project and that the iOS version was only run in the simulator.
