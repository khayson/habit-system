# Device gate (Phase 3.2b): reminders and background sync on a real Android phone

This gate is Khay Studios'. Claude Code cannot run it: the emulator does not show how a real
phone delays alarms, kills background work or restricts battery use. Run every step on a real
Android device (Android 13 or later, so the notification prompt exists), and on an
aggressive-OEM device too if one is available (Xiaomi, Tecno/Infinix, Samsung).

Record each result in the table at the end: pass or fail, the device and Android version, the
date, and a note for anything unexpected. A failure is a finding for the next review, with what
you saw.

## Setup

1. Build and install a debug build that reaches your API (see DEV_SETUP.md, "Android").
2. Turn on automatic date and time, then create a fresh account.
3. Keep the phone plugged in only where a step says so; battery steps need it unplugged.

## Steps

| # | Do this | Expected |
|---|---------|----------|
| 1 | On screen 04, look at "Local reminders" before tapping anything. | It says "Not allowed yet". No system prompt has appeared. |
| 2 | Tap **Allow**, then choose **Allow** in the system prompt. | The card says "Allowed". |
| 3 | Reinstall (or clear the app's data), sign in, tap **Allow**, choose **Don't allow**. | The card says "Off in device settings" with **Open settings**. |
| 4 | Tap **Open settings**, then come back without changing anything. Tap it again. | The system prompt never appears again; the app opens Settings each time. |
| 5 | On screen 11 for a habit, with notifications off. | "Notifications are off", **Open device settings** and "Next reminder: …" are shown. No prompt appears. |
| 6 | Turn notifications on in Settings, return to 11. | The banner is gone; "Reminder enabled · Arrives on this device". |
| 7 | Create a habit with a reminder 3 minutes from now. Close the app (swipe it away). | The reminder appears within about 15 minutes of its time (Android delivers inexact alarms in a window). Its title is the habit name; the text is neutral. |
| 8 | Check the habit in for today, then set a reminder for later today. | No reminder appears for that habit today. Tomorrow's still appears. |
| 9 | Set a reminder 10 minutes ahead, then reboot the phone and do not open the app. | The reminder still appears after the reboot. |
| 10 | Settings → Apps → Habit System → Battery → **Restricted**. Set a reminder 10 minutes ahead; lock the phone for 30 minutes. | Note whether and when it arrived. (Delay is allowed; the app must not crash or show it twice.) |
| 11 | Battery back to **Optimised**/**Unrestricted**; repeat step 10. | It arrives within the inexact window. |
| 12 | Airplane mode on. Create a reminder 5 minutes ahead and check a habit in. | The reminder appears with no network. The check-in shows "waiting to sync". |
| 13 | Airplane mode off, app closed, wait 20 minutes (background sync, best effort). Then open the app on a second device signed in to the same account. | The second device shows the check-in. If it did not sync in the background, opening the first app syncs it at once. Record which happened. |
| 14 | Turn off automatic time. Set the date to the day before a DST change in your zone (or set the zone to America/New_York and the date to 7 March 2026), with a reminder at 02:30. Advance the clock past the change. | One reminder, at 03:00 on the change day; no second one. Restore automatic time afterwards. |
| 15 | Sign out. | No more reminders appear for that account. Sign in as another account on the same phone: its reminders appear; the first account's never do. |

## Results

| # | Pass / fail | Device and Android version | Date | Note |
|---|-------------|----------------------------|------|------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |
| 10 | | | | |
| 11 | | | | |
| 12 | | | | |
| 13 | | | | |
| 14 | | | | |
| 15 | | | | |
