# Backup and restore

Your progress is kept on your phone, with no account. If you lose or reset the phone, it is gone, unless you made a backup. Back up before you switch phones.

## Back up

Settings > Your data > Backup and restore.

1. Tap Back up now. It saves one file, where you choose, named like `fluenough-backup-2026-10-22.fnbackup`. A copy is kept on the phone too.
2. Keep the file somewhere safe: in your cloud, on a computer, or sent to yourself.

One file holds your progress (the review log), your settings, your rater code (if you review decks) and the list of languages you downloaded. It does not hold deck files or anything that restricts a profile.

A backup holds your whole learning history. It leaves the phone only if you share it. Connecting a cloud service (Dropbox, Box, Google Drive, OneDrive, Nextcloud) is shown as "Feature incoming" for now.

The last five backups are kept on the phone, whatever made them: you, an app update, or a restore. They are listed under Recent backups, each with Download and Restore.

The app also makes a backup before it updates itself.

## Restore

1. Settings > Your data > Restore from a file, and choose a backup.
2. A sheet shows what is in it before anything changes: when it was made, which app version made it, how many reviews and in which languages, and which languages will be downloaded again.
3. Tap Replace and restore. Your progress and settings on this phone are replaced. A copy is kept first, in Recent backups.

After a restore, your decks download again.

If the file is not a Fluenough backup, or is damaged, nothing changes. If it was made by a newer Fluenough, update the app first, then restore it.

## Export the review log

Settings > Your data also has Export review log. It saves every answer as a JSONL file. See [Log format](Log-Format).

## The file format

The file is a plain zip of small text files, so any unzip tool opens it. See [Backup format](Backup-Format).

See also: [Learner guide](Learner-Guide), [Home](Home).
