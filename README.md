# **pCloud Backup Automation**

This repository contains a Bash script to automate the backup of folders and files from a local network (`myhomecloud`) to a pCloud account using `rclone`. The script includes features such as monthly transfer limits, real-time progress tracking, and robust error handling to ensure reliable backups.

---

## **Features**

- **Automated Backups**:
  - Syncs specific folders (`@DOCUMENTS`, `@SOUVENIRS`, `@MULTIMEDIA`) from a local network to pCloud.
  - Supports encrypted backups for sensitive folders (e.g., `@DOCUMENTS/ADMIN`).

- **Monthly Transfer Limit**:
  - Limits data transfer to **50GB per month**.
  - Resets the transfer limit on the **16th of each month**.

- **Real-Time Progress Tracking**:
  - Monitors the `rclone` log in real-time to track transferred data.
  - Updates a state file (`.rclone_monthly_transfer`) with the remaining transfer quota.

- **Crash Recovery**:
  - Ensures the current transfer state is saved even if the script crashes or is interrupted.
  - Resumes from the last saved state on the next run.

- **Detailed Logging**:
  - Logs all backup operations to a timestamped log file for debugging and auditing.

---

## **Requirements**

- **Operating System**: Linux, macOS, or Windows (with Bash installed, e.g., Git Bash or WSL).
- **Dependencies**:
  - [`rclone`](https://rclone.org/) (installed and configured).
  - Bash shell.

---

## **Setup**

1. **Install `rclone`**:
   - Follow the [official installation guide](https://rclone.org/install/).

2. **Configure `rclone` Remotes**:
   - Set up remotes for both your local network (`myhomecloud`) and pCloud:
     ```bash
     rclone config
     ```
   - Example remote names:
     - `myhomecloud`: Local network storage.
     - `pcloud`: pCloud account.

3. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd pcloud-backup-automation
   ```

---

## **Task Scheduler Setup on Windows 11**

To automate the execution of the `myhomecloud_to_pcloud_backup.sh` script on Windows 11 every time a user logs in, follow these steps:

1. **Open Task Scheduler**:
   - Press `Win + S`, type `Task Scheduler`, and press `Enter`.

2. **Create a New Task**:
   - In the Task Scheduler window, click on `Action` > `Create Task`.

3. **General Settings**:
   - In the `General` tab:
     - Enter a name for the task, e.g., `pCloud Backup`.
     - Select `Run only when user is logged on`.
     - Check `Run with highest privileges`.

4. **Trigger Configuration**:
   - Go to the `Triggers` tab and click `New`.
   - In the `Begin the task` dropdown, select `At log on`.
   - Ensure `Any user` is selected.
   - Click `OK`.

5. **Action Configuration**:
   - Go to the `Actions` tab and click `New`.
   - In the `Action` dropdown, select `Start a program`.
   - In the `Program/script` field, enter the path to `bash.exe` (e.g., `C:\Program Files\Git\bin\bash.exe` if using Git Bash).
   - In the `Add arguments` field, enter the full path to the `myhomecloud_to_pcloud_backup.sh` script, e.g.:
     ```bash
     "d:/APPRENTISSAGE/PROGRAMMATION/pcloud/myhomecloud_to_pcloud_backup.sh"
     ```
   - Click `OK`.

6. **Retry Settings**:
   - Go to the `Settings` tab:
     - Check `If the task fails, restart every:` and set it to `1 minute`.
     - Set `Attempt to restart up to:` to `3 times`.

7. **Save the Task**:
   - Click `OK` to save the task.
   - You may be prompted to enter your user credentials.

8. **Verify the Task**:
   - In the Task Scheduler library, locate your task, right-click it, and select `Run` to test it.
   - Check the logs or the `logs/` directory to ensure the script executed successfully.

---

## **Script Details**

### `myhomecloud_to_pcloud_backup.sh`

This Bash script automates the backup process from `myhomecloud` to pCloud using `rclone`. Below is a breakdown of its functionality:

1. **Variables**:
   - Defines remotes for `myhomecloud` and `pCloud`.
   - Sets up paths for backups, logs, and a state file to track monthly transfer limits.
   - Configures a **50GB monthly transfer limit** and resets it on the **16th of each month**.

2. **Monthly Transfer Management**:
   - Ensures the state file exists and initializes it if missing.
   - Resets the transfer limit if the current date is on or after the 16th and the state file was last modified before the 16th.

3. **Real-Time Progress Tracking**:
   - Monitors the `rclone` log file to track transferred data in real-time.
   - Updates the state file with the remaining transfer quota after each transfer.

4. **Crash Recovery**:
   - Uses a `trap` to save the current transfer state if the script is interrupted or crashes.

5. **Backup Functionality**:
   - Defines a `backup_folder` function to sync specific folders from `myhomecloud` to pCloud.
   - Ensures the transfer does not exceed the remaining monthly quota.
   - Logs all operations for debugging and auditing.

6. **Folder Backups**:
   - Backs up the following folders:
     - `@DOCUMENTS/ADMIN` (encrypted).
     - `@DOCUMENTS/ARCHIVES`, `@DOCUMENTS/PROGRAMMATION`.
     - `@SOUVENIRS`.
     - `@MULTIMEDIA`.

7. **Logging**:
   - Logs all operations to a timestamped log file in the `logs/` directory.

To execute the script:
```bash
bash myhomecloud_to_pcloud_backup.sh
```
Ensure that `rclone` is properly configured and the required remotes are accessible.