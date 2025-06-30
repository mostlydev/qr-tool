## QR Tool

A PowerShell-based tool for automating DICOM study pre-fetching. It monitors an input directory for new DICOM files, and when a new file appears, it automatically queries a PACS for other studies belonging to the same patient, and then issues a move request to have those studies sent to a pre-configured destination.

### Features

*   **Automatic Prefetching:** Monitors a directory for incoming DICOM files and triggers a prefetching workflow.
*   **Patient-Centric Query:** Identifies the patient from the incoming file and queries a PACS for related studies.
*   **Configurable Query Parameters:** Allows specifying a timeframe for the study search (e.g., last 60 months) and can be configured to query for a fixed modality or the same modality as the trigger file.
*   **Flexible Destination:** The destination Application Entity (AE) for the C-MOVE operation is configurable.
*   **Robust Workflow Management:** Uses a multi-stage process with dedicated directories for tracking the state of each task (queued, processed, rejected, no-results).
*   **Efficient Processing:** Avoids re-processing of already handled studies by keeping a history of processed files.
*   **Pixel Data Stripping:** Optionally strips pixel data from large DICOM files to save space, as only the header information is needed for the query.
*   **Looping Operation:** Can be configured to run continuously, with a configurable sleep interval between cycles.

### How It Works

The tool operates in a three-stage pipeline:

1.  **Stage 1: File Ingestion (`stage-1.ps1`)**
    *   Monitors the `incoming-stored-items` directory for new `.dcm` files.
    *   For each new file, it extracts `PatientName`, `PatientBirthDate`, and `StudyDate`.
    *   A unique hash is generated from these tags to identify the study.
    *   If the study has not been processed before, the file is moved to the `queued-stored-items` directory. If it's a large file, the pixel data may be stripped.
    *   If the study has already been processed, the incoming file is rejected (either by deleting it or moving it to the `rejected-stored-items` directory).

2.  **Stage 2: Study Discovery (`stage-2.ps1`)**
    *   Processes files in the `queued-stored-items` directory.
    *   For each file, it performs a C-FIND query against the configured PACS (`qrServerAE`) to find other studies for the same patient.
    *   The search can be limited by the `studyFindMonthsBack` parameter and can be configured to look for a specific modality using `findAndMoveFixedModality`.
    *   If studies are found, it creates a `.move-request` ticket for each study in the `queued-study-moves` directory. The ticket is named with the `StudyInstanceUID`.
    *   The original file from the queue is then moved to the `processed-stored-items` directory.
    *   If no studies are found, the file is moved to the `no-results-stored-items` directory.

3.  **Stage 3: Study Retrieval (`stage-3.ps1`)**
    *   Processes the `.move-request` tickets in the `queued-study-moves` directory.
    *   For each ticket, it issues a C-MOVE request to the PACS to send the corresponding study to the configured destination AE (`qrDestinationAE`).
    *   Upon successful completion of the C-MOVE, the ticket is moved to the `processed-study-moves` directory.

### Project Structure

```
qr-tool/
├── cache/                    # Working directory for the tool, contains subdirectories for each stage.
│   ├── incoming-stored-items/  # Drop new DICOM files here to trigger the workflow.
│   ├── queued-stored-items/    # Stage 1 output, Stage 2 input.
│   ├── processed-stored-items/ # Files that have been processed by Stage 2.
│   ├── rejected-stored-items/  # Files that were rejected in Stage 1.
│   ├── no-results-stored-items/ # Files for which no studies were found in Stage 2.
│   ├── queued-study-moves/     # Stage 2 output, Stage 3 input.
│   └── processed-study-moves/  # Move requests that have been processed by Stage 3.
├── config.ps1              # Main configuration file for the tool.
├── FoDicomCmdlets/           # C# project for custom DICOM PowerShell cmdlets.
│   └── FoDicomCmdlets.cs     # Implements Move-StudyByStudyInstanceUIDSync and Get-StudiesByPatientNameAndBirthDate.
├── lib/                      # PowerShell modules for each stage and utility functions.
│   ├── dicom-funs.ps1        # DICOM-related helper functions.
│   ├── stage-1.ps1           # Logic for the File Ingestion stage.
│   ├── stage-2.ps1           # Logic for the Study Discovery stage.
│   ├── stage-3.ps1           # Logic for the Study Retrieval stage.
│   └── utility-funs.ps1      # Common utility functions.
├── qr-tool.ps1               # Main script to run the tool.
└── README.md                 # This file.
```

### Configuration

All configuration is done in the `config.ps1` file.

**DICOM Configuration:**

*   `$global:myAE`: The Application Entity Title (AET) of this tool.
*   `$global:qrServerAE`: The AET of the PACS to query.
*   `$global:qrServerHost`: The hostname or IP address of the PACS.
*   `$global:qrServerPort`: The port number of the PACS.
*   `$global:qrDestinationAE`: The AET of the destination where the studies should be sent.

**Query Parameters:**

*   `$global:studyFindMonthsBack`: The number of months back to search for studies.
*   `$global:findAndMoveFixedModality`: If set to a modality (e.g., "CT"), the tool will query for studies of that modality. If `$null`, it will query for studies with the same modality as the trigger file.

**Operational Settings:**

*   `$global:sleepSeconds`: The number of seconds to wait between processing cycles. If set to 0, the script will run once and exit.
*   `$global:mtimeThreshholdSeconds`: A file in the incoming directory is considered "fresh" and will be skipped if its last modified time is less than this many seconds ago. This prevents processing of partially written files.
*   `$global:largeFileThreshholdBytes`: Files larger than this size (in bytes) will have their pixel data stripped in Stage 1.
*   `$global:rejectByDeleting`: If `$true`, rejected files will be deleted. If `$false`, they will be moved to the `rejected-stored-items` directory.

**Directory Configuration:**

*   `$global:cacheDirBasePath`: The base path for the working directories. Defaults to the `cache` subdirectory of the project.
*   `$global:incomingStoredItemsDirPath`: The path to the directory where new DICOM files are placed.

### Build and Run

1.  **Build the Cmdlets:**
    *   Open the `FoDicomCmdlets/FoDicomCmdlets.sln` solution in Visual Studio.
    *   Build the solution in `Release` mode. This will produce the `FoDicomCmdlets.dll` and download the required `Dicom.Core.dll` from `fo-dicom`.

2.  **Configure the Tool:**
    *   Edit `config.ps1` to match your environment.

3.  **Run the Tool:**
    *   Run the `qr-tool.ps1` script from a PowerShell console in Windows.  If you are not currently on windows then use 
    `ssh windev "cd C:\dev\qr-tool && powershell -ExecutionPolicy Bypass -File qr-tool.ps1"`.

<!-- TASKMASTER_EXPORT_START -->
> 🎯 **Taskmaster Export** - 2025-06-27 18:02:31 UTC
> 📋 Export: without subtasks • Status filter: none
> 🔗 Powered by [Task Master](https://task-master.dev?utm_source=github-readme&utm_medium=readme-export&utm_campaign=qr-tool&utm_content=task-export-link)

```
╭─────────────────────────────────────────────────────────╮╭─────────────────────────────────────────────────────────╮
│                                                         ││                                                         │
│   Project Dashboard                                     ││   Dependency Status & Next Task                         │
│   Tasks Progress: █████████████░░░░░░░ 63%    ││   Dependency Metrics:                                   │
│   63%                                                   ││   • Tasks with no dependencies: 0                      │
│   Done: 10  In Progress: 0  Pending: 6  Blocked: 0     ││   • Tasks ready to work on: 2                          │
│   Deferred: 0  Cancelled: 0                             ││   • Tasks blocked by dependencies: 4                    │
│                                                         ││   • Most depended-on task: #1 (10 dependents)           │
│   Subtasks Progress: ░░░░░░░░░░░░░░░░░░░░     ││   • Avg dependencies per task: 4.0                      │
│   0% 0%                                               ││                                                         │
│   Completed: 0/6  In Progress: 0  Pending: 6      ││   Next Task to Work On:                                 │
│   Blocked: 0  Deferred: 0  Cancelled: 0                 ││   ID: 14 - Implement Study Deduplication     │
│                                                         ││   Priority: medium  Dependencies: Some                    │
│   Priority Breakdown:                                   ││   Complexity: ● 6                                       │
│   • High priority: 10                                   │╰─────────────────────────────────────────────────────────╯
│   • Medium priority: 4                                 │
│   • Low priority: 2                                     │
│                                                         │
╰─────────────────────────────────────────────────────────╯
┌───────────┬──────────────────────────────────────┬─────────────────┬──────────────┬───────────────────────┬───────────┐
│ ID        │ Title                                │ Status          │ Priority     │ Dependencies          │ Complexi… │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 1         │ Setup Project Structure              │ ✓ done          │ high         │ None                  │ ● 2       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 2         │ Create Configuration File            │ ✓ done          │ high         │ 1                     │ ● 3       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 3         │ Develop Utility Functions            │ ✓ done          │ high         │ 1, 2                  │ ● 4       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 4         │ Develop DICOM Helper Functions       │ ✓ done          │ high         │ 1, 2, 3               │ ● 5       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 5         │ Implement Stage 1 - File Ingestion   │ ✓ done          │ high         │ 1, 2, 3, 4            │ ● 6       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 6         │ Implement Stage 2 - Study Discovery  │ ✓ done          │ high         │ 1, 2, 3, 4, 5         │ ● 7       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 7         │ Implement Stage 3 - Study Retrieval  │ ✓ done          │ high         │ 1, 2, 3, 4, 6         │ ● 6       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 8         │ Develop FoDicomCmdlets C# Project    │ ✓ done          │ high         │ 1                     │ ● 8       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 9         │ Create Main QR Tool Script           │ ✓ done          │ high         │ 1, 2, 3, 4, 5, 6, 7,  │ ● 7       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 10        │ Create Comprehensive README          │ ✓ done          │ medium       │ 1, 2, 3, 4, 5, 6, 7,  │ ● 3       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 11        │ Implement Error Handling and Logging │ ○ pending       │ medium       │ 1, 2, 3, 4, 5, 6, 7,  │ ● 7       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 12        │ Implement Performance Monitoring     │ ○ pending       │ low          │ 5, 6, 7, 11           │ ● 6       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 13        │ Implement Retry Mechanism for Failed │ ○ pending       │ medium       │ 4, 11                 │ ● 5       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 14        │ Implement Study Deduplication        │ ○ pending       │ medium       │ 6, 7                  │ ● 6       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 15        │ Create Unit Tests                    │ ○ pending       │ low          │ 3, 4, 5, 6, 7, 11, 13 │ ● 8       │
├───────────┼──────────────────────────────────────┼─────────────────┼──────────────┼───────────────────────┼───────────┤
│ 16        │ Implement Periodic DICOM Modality Wo │ ○ pending       │ high         │ 4, 11, 13             │ ● 9       │
└───────────┴──────────────────────────────────────┴─────────────────┴──────────────┴───────────────────────┴───────────┘
```

╭────────────────────────────────────────────── ⚡ RECOMMENDED NEXT TASK ⚡ ──────────────────────────────────────────────╮
│                                                                                                                         │
│  🔥 Next Task to Work On: #14 - Implement Study Deduplication                                  │
│                                                                                                                         │
│  Priority: medium   Status: ○ pending                                                                                     │
│  Dependencies: 6, 7                                                                                                     │
│                                                                                                                         │
│  Description: Add functionality to avoid requesting the same study multiple times.     │
│                                                                                                                         │
│  Start working: task-master set-status --id=14 --status=in-progress                                                     │
│  View details: task-master show 14                                                                      │
│                                                                                                                         │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯


╭──────────────────────────────────────────────────────────────────────────────────────╮
│                                                                                      │
│   Suggested Next Steps:                                                              │
│                                                                                      │
│   1. Run task-master next to see what to work on next                                │
│   2. Run task-master expand --id=<id> to break down a task into subtasks             │
│   3. Run task-master set-status --id=<id> --status=done to mark a task as complete   │
│                                                                                      │
╰──────────────────────────────────────────────────────────────────────────────────────╯

> 📋 **End of Taskmaster Export** - Tasks are synced from your project using the `sync-readme` command.
<!-- TASKMASTER_EXPORT_END -->
Prior to runninig qr-tool.ps1, build the FoDicomCmdlets solution in Release mode as the script will need to make use of both the DLL it will build and the DLL of the copy of fo-dicom that the solution will install in itjs packages folder.

Before running the script, be sure to copy config.template.ps1 to config.ps1 to and make any required changes.
