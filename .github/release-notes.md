## Install

Doppio needs macOS 15 or later. It runs on Apple silicon and Intel Macs.

1. Download the `.dmg` file below.
2. Open the `.dmg` file.
3. Drag **Doppio** onto the **Applications** folder.
4. Open Doppio from the Applications folder.

**CAUTION:** Doppio does not have an Apple Developer ID signature. Thus macOS blocks Doppio the first time that you open it.

If macOS shows the message "Doppio" Not Opened, do these steps:

1. Click **Done**.
2. Open **System Settings** › **Privacy & Security**.
3. Scroll down to the **Security** section.
4. Click **Open Anyway** next to the message about Doppio.
5. Enter your password if macOS asks for it.
6. Click **Open Anyway** again.

macOS can show the message again after you install a new version. If it does, do the steps again.

To make sure that the download is correct, put the `.sha256` file in the same folder as the `.dmg` file. Then type `shasum -a 256 -c Doppio-*.dmg.sha256` in Terminal.
