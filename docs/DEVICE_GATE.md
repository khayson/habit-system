# Device gate (Phase 3.2b): reminders and background sync on a real Android phone

This gate is Khay Studios'. Claude Code cannot run it: the emulator does not show how a real
phone delays alarms, kills background work or restricts battery use. Run every step on a real
Android device (Android 13 or later, so the notification prompt exists), and on an
aggressive-OEM device too if one is available (Xiaomi, Tecno/Infinix, Samsung).

**Known limit, not a failure:** reminders are planned 14 days ahead and replanned whenever the
app opens. If the app is not opened for 14 days, they stop until it is opened again.

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
| 8 | Create a new habit with a reminder 10 minutes ahead (08's Reminder row), then check the habit in at once. | No reminder today; tomorrow's is still scheduled. |
| 9 | Set a reminder 10 minutes ahead, then reboot the phone and do not open the app. | The reminder still appears after the reboot. |
| 10 | Settings → Apps → Habit System → Battery → **Restricted**. Set a reminder 10 minutes ahead; lock the phone for 30 minutes. | Note whether and when it arrived. (Delay is allowed; the app must not crash or show it twice.) |
| 11 | Battery back to **Optimised**/**Unrestricted**; repeat step 10. | It arrives within the inexact window. |
| 12 | Airplane mode on. Create a reminder 5 minutes ahead and check a habit in. | The reminder appears with no network. The check-in shows "waiting to sync". |
| 13 | Airplane mode off, app closed, wait 20 minutes (background sync, best effort). Then open the app on a second device signed in to the same account. | The second device shows the check-in. If it did not sync in the background, opening the first app syncs it at once. Record which happened. |
| 14 | Turn off automatic time. Set the date to the day before a DST change in your zone (or set the zone to America/New_York and the date to 7 March 2026), with a reminder at 02:30. Advance the clock past the change. | One reminder, at 03:00 on the change day; no second one. Restore automatic time afterwards. |
| 15 | Profile → **Sign out**. | No more reminders appear for that account. Sign in as another account on the same phone: its reminders appear; the first account's never do. |
| 16 | On 12, open the habit's Reminder row and change the time to 5 minutes ahead; save. | The old time never fires; the new time fires once. |
| 17 | On 12, open the Reminder row, turn **Reminder enabled** off; save. Wait past its time. | Nothing fires. |
| 18 | On 12, open the Reminder row and remove the reminder. Wait past its time. | Nothing fires; Today is unaffected. |
| 19 | On 12 for a habit that has no reminder, open the Reminder row and save a time 5 minutes ahead. | It fires. |
| 20 | Profile → tap the photo → **Choose photo**; pick a photo and crop it square. | The photo shows on 20 at once. The system asks for no storage permission. |
| 21 | Airplane mode on. Profile → tap the photo → choose a different photo. | The new photo shows at once, with "Waiting to upload". |
| 22 | Airplane mode off; wait for a sync (or open the app). Then open Profile on a second device signed in to the same account. | "Waiting to upload" goes away. The second device shows the new photo after it syncs. |
| 23 | Profile → **Edit profile**: change the name, type a city, pick a country; **Save**. Sync both devices. | 20 shows "City, Country" at once on the first device, and the same name, city and country on the second. |
| 24 | Profile → tap the photo → **Remove photo**. Sync both devices. | Initials on both devices. |
| 25 | Profile → **Reminders** → turn on **Hide habit names in notifications**. Set a reminder 5 minutes ahead; lock the phone. | The reminder that appears does not name the habit. Turning the setting off brings the names back on the next reminders. |
| 26 | Take a portrait photo with the phone camera, choose it as the profile photo, crop it. | It shows upright on this phone, and upright on a second device after sync. Result: ___. |
| 27 | Offline, create a duration habit on Monday, Wednesday and Friday. Reconnect. | It appears with the same schedule after a fresh sign-in on the same account. |
| 28 | Offline, raise a habit's target. Reconnect. | Before reconnecting the screen shows "Waiting to sync". After, it shows "starts {date}", and today's check-in still uses the old target. |
| 29 | Archive a habit with a reminder, then restore it. | The reminder stops on archive and returns on restore; the habit shows on screen 22 while archived. |
| 30 | Create an "every 2 days from today" habit. | Today shows it only on due days, and reminders match. |
| 31 | At 200% text size, open screens 08, 09, 10 and 22. | Nothing is clipped and every control is reachable. |
| 32 | Today: tap "+{step}" on a quantity habit, then Add. | The card's progress updates at once, also offline, and shows synced after reconnecting. |
| 33 | Two devices add to the same quantity habit while offline; reconnect both. | The total is the sum on both devices. |
| 34 | Start a timer from a duration habit ("+1 min", then "Time it instead"); lock the phone for a minute; open it. Pause, leave the app, return. | The elapsed time includes the locked minute. After pausing: still paused with the same time. |
| 35 | Kill the app while a timer runs; reopen. | The timer is still running and the time is right. |
| 36 | Finish a timer offline; reconnect. | One entry of whole seconds, the same on a second device. |
| 37 | At 200% text size, open 34, 33, 36 and Today with both card kinds. | Nothing is clipped and every control is reachable. |
| 38 | A reminder is due with the screen on. Then open the app by hand. Then change that reminder's time. | It pops up as a banner and stays in the tray; after opening the app the fired reminder is still in the tray; the next one shows once, at the new time, never twice. |
| 39 | Two devices on the same account (phone and emulator), both offline: edit the same quantity entry to different values; reconnect the first, then the second. | The second shows Needs a look on Today; Review opens 19 with both values and the version lines. |
| 40 | In 19 choose Keep synced value. | Both devices show the synced value and the queue is empty. |
| 41 | Repeat and choose Use my value. | Both devices end on it; if the other device changed it again before the sync, 19 asks again. |
| 42 | Remove a day's entry on one device while the other adds to it; reconnect. | The deleted-day variant; Keep it deleted and Bring it back each work. |
| 43 | Archive a habit on one device while the other checks in offline; reconnect. | The archived variant; Restore then Save my check-in works, and so does Discard this check-in. |
| 44 | Edit the same habit's name on both devices. | The stale-habit variant lists the differing fields. |
| 45 | At 200% text size and with a screen reader, open 19 in each variant. | Nothing is clipped and each card and button reads with its values. |
| 46 | Phase 5.2a. Sign in on a fresh install and let it sync. | Today's summary card shows "{xp} XP · Level {level}" under the habit count; the screen reader reads it as "{xp} XP, Level {level}". |
| 47 | Turn on airplane mode and complete a habit on Today. | The XP and level stay as they were; the card says "Includes changes waiting to sync. Rewards update after syncing." No "+10" appears anywhere. |
| 48 | Turn airplane mode off and wait for the sync. | The XP and level change to the server's new numbers and the waiting sentence goes away. |
| 49 | Open Profile. | Under the name: "{place} · Level {level} · {xp} XP" (or "Level {level} · {xp} XP" without a place). |
| 50 | Open a habit whose current streak includes a protected day (auto-freeze on, a day missed and closed). | 12's footer says "Your streak includes 1 protected day." |
| 51 | Phase 5.2b. Profile → XP and levels (16). | The level and XP match Today's line; Recent XP lists completions with habit names; Show more loads the next page. |
| 52 | Turn on airplane mode and open 16. | The level and XP stay; the list says it could not be loaded and offers Try again; nothing says "+10 pending". |
| 53 | Profile → Freezes (17), on an account where a freeze was used. | "{balance} / 2 freezes", the refill date, and a history row such as "{habit} · {date}, 1 freeze used · daily period protected, −1". |
| 54 | In airplane mode turn Auto-protect on. Reconnect. Relaunch the app. | It shows on with "Saved on this device. It applies after syncing." and the queue lists "Auto-protect turned on"; after reconnecting the note goes; after the relaunch it is still on. |
| 55 | Two phones on one account: toggle Auto-protect to opposite states at the same time. | Both end on the choice that reached the server last; nothing appears under Needs a look. |
| 56 | On a habit whose footer says it includes protected days, tap the footer. | 17 opens. |
| 57 | At 200% text size and with TalkBack, open 16 and 17. | Nothing is clipped; each history row reads habit, date and amount; the switch reads its name, its state and "After a scheduled day or week closes". |
| 58 | Phase 5.2c. Online, save an amount that reaches a quantity habit's target. | "{habit} complete" with "+10 XP"; the Level card matches 16; Back to today returns to Today. |
| 59 | Finish a timer at its target. | The same on the duration layout ("{n} min logged today"). |
| 60 | Repeat 58 in airplane mode. | It returns to Today at once; after reconnecting the XP line updates and no completion screen appears. |
| 61 | Save a partial amount. | It returns at once. |
| 62 | Undo the completed day, then complete it again from the amount screen. | The completion screen shows +10 XP again. |
| 63 | Tap the save, turn on airplane mode at once, then press Back while it says "Saved on this device. Confirming…". | It returns to Today and no completion screen appears later. |
| 64 | At 200% text size and with TalkBack, open the completion screen. | Nothing is clipped; the heading reads as a header; the chip reads "10 XP earned"; the Level card reads as one label. |
| 65 | Phase 5.3b. Online, tap the Insights tab. | "A week of progress" with this week's dates; the percentage and "{completed} / {eligible} closed periods", "+{n} XP" and "Through {yesterday}"; seven bars, future days flat; open weekly habits listed with "Pending". The tab shows as selected. |
| 66 | Switch to Month. Leave the tab and come back. | "Your consistency" with the month and "closed periods through {yesterday}"; a row per category with its numbers; Month is still selected on return. |
| 67 | On a Monday morning, before anything has closed this week, open Week. | "No closed periods yet" and "No closed days yet"; never "0%". |
| 68 | In airplane mode, open Insights after a fresh app start. | "Insights need a connection. They appear once your phone is back online." No error wording. |
| 69 | Open Insights online, then turn on airplane mode and pull to refresh. | The numbers stay, with "These are the last numbers from this session." |
| 70 | Check in offline, then open Insights. | "Check-ins waiting to sync aren't counted yet."; after reconnecting and syncing the line goes. |
| 71 | With TalkBack and at 200% text, open Week and Month. | The tab reads as selected; each day reads like "Monday, 3 of 5 completed"; each category reads its numbers and percent; nothing is clipped. |
| 72 | Phase 6.1. Profile, then Privacy and export. | "Your data, yours" with JSON backup selected, "Included in your export", "Cloud history is up to date" (or "{n} changes waiting to sync" while check-ins wait) and "Exports are private. Download links are temporary." No bottom bar. |
| 73 | Tap Request new export. Then tap Back to privacy and export, and open the screen again. | "Preparing your export" with "Queued securely" and today's time. Back on Privacy and export, "Latest export · queued", "preparing" or "ready" in words. |
| 74 | When it is ready (the dev server's queue worker runs), tap Download latest export and save it to Files. | The share sheet opens with habit-export.zip; Files saves it and it opens as a zip with export.json and manifest.json (and the photo if set). Repeat with CSV history: habit-export.csv. |
| 75 | On the dev server, run `UPDATE export_jobs SET expires_at = now() - interval '1 minute' WHERE id = '<id>';`, then reopen Privacy and export. | "Latest export · expired"; no Download button; "Request new export" still works. |
| 76 | Tap Download latest export and turn on airplane mode at once. | "The download did not finish. Try again when you're online." The screen stays; after reconnecting, Download works. |
| 77 | On the dev server, run `UPDATE export_jobs SET status = 'failed', error_code = 'export_failed' WHERE id = '<id>';` for a queued job, then open it from the status screen. | "Let's try that again", "Your habits and history are unchanged." and "JSON backup · failed"; Retry export returns to "Preparing your export". |
| 78 | With TalkBack and at 200% text, open Privacy and export, the status screen and the failed screen. | Every status reads as words (never colour alone); the format choice reads as selected; nothing is clipped. |

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
| 16 | | | | |
| 17 | | | | |
| 18 | | | | |
| 19 | | | | |
| 20 | | | | |
| 21 | | | | |
| 22 | | | | |
| 23 | | | | |
| 24 | | | | |
| 25 | | | | |
| 26 | | | | |
| 27 | | | | |
| 28 | | | | |
| 29 | | | | |
| 30 | | | | |
| 31 | | | | |
| 32 | | | | |
| 33 | | | | |
| 34 | | | | |
| 35 | | | | |
| 36 | | | | |
| 37 | | | | |
| 38 | | | | |
| 39 | | | | |
| 40 | | | | |
| 41 | | | | |
| 42 | | | | |
| 43 | | | | |
| 44 | | | | |
| 45 | | | | |
| 46 | | | | |
| 47 | | | | |
| 48 | | | | |
| 49 | | | | |
| 50 | | | | |
| 51 | | | | |
| 52 | | | | |
| 53 | | | | |
| 54 | | | | |
| 55 | | | | |
| 56 | | | | |
| 57 | | | | |
| 58 | | | | |
| 59 | | | | |
| 60 | | | | |
| 61 | | | | |
| 62 | | | | |
| 63 | | | | |
| 64 | | | | |
| 65 | | | | |
| 66 | | | | |
| 67 | | | | |
| 68 | | | | |
| 69 | | | | |
| 70 | | | | |
| 71 | | | | |
| 72 | | | | |
| 73 | | | | |
| 74 | | | | |
| 75 | | | | |
| 76 | | | | |
| 77 | | | | |
| 78 | | | | |
