# **Network Backup Automation**

This repository contains a Bash script to automate the backup of folders and files from one network location to another using `rclone`. The script includes features such as monthly transfer limits, real-time progress tracking, and robust error handling to ensure reliable backups.

---

## **Features**

- **Automated Backups**:
  - Syncs specific folders from a source network to a destination network.
  - Supports encrypted backups for sensitive folders.

- **Monthly Transfer Limit**:
  - Limits data transfer to a configurable amount (default: **50GB per month**).
  - Resets the transfer limit on a configurable day of the month (default: **16th**).

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
   - Set up remotes for both your source and destination networks:
     ```bash
     rclone config
     ```
   - Example remote names:
     - `source_remote`: Source network storage.
     - `destination_remote`: Destination network storage.

3. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd network-backup-automation
   ```

4. **Edit the CSV File**:
   - Open the `backup_paths.csv` file in the repository.
   - Add or modify rows to specify the source and destination paths for backups. Each row should have the following format:
     ```csv
     source,destination
     ```
   - Example:
     ```csv
     /path/to/source/folder1/,destination:/backup/folder1
     /path/to/source/folder2/,destination:/backup/folder2
     ```

---

## **Task Scheduler Setup on Windows 11**

To automate the execution of the `network_backup.sh` script on Windows 11 every time a user logs in, follow these steps:

1. **Open Task Scheduler**:
   - Press `Win + S`, type `Task Scheduler`, and press `Enter`.

2. **Create a New Task**:
   - In the Task Scheduler window, click on `Action` > `Create Task`.

3. **General Settings**:
   - In the `General` tab:
     - Enter a name for the task, e.g., `Network Backup`.
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
   - In the `Add arguments` field, enter the full path to the `network_backup.sh` script, e.g.:
     ```bash
     "{FULL PATH TO}/network_backup.sh"
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

### `network_backup.sh`

This Bash script automates the backup process from a source network to a destination network using `rclone`. Below is a breakdown of its functionality:

1. **Variables**:
   - Defines remotes for the source and destination networks.
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
   - Reads the `backup_paths.csv` file to get the source and destination paths.
   - Runs the `backup_folder` function for each row in the CSV file.

6. **Logging**:
   - Logs all operations to a timestamped log file in the `logs/` directory.

To execute the script:
```bash
bash network_backup.sh
```
Ensure that `rclone` is properly configured and the required remotes are accessible.