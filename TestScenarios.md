# Acuo De-Identification Service — Comprehensive Test Scenarios

**Product:** Acuo VNA — Acuo Deidentification Service  
**Version:** 25.1 (February 2026)  
**Document Purpose:** Functional and Non-Functional test scenarios derived from the Acuo Deidentification Service User Guide  

---

## Table of Contents

1. [Functional Test Scenarios](#1-functional-test-scenarios)
   1. [Installation and Upgrades](#11-installation-and-upgrades)
   2. [Configuration Properties](#12-configuration-properties)
   3. [Input Watch Directory — Study Identification](#13-input-watch-directory--study-identification)
   4. [RESTful API — Deidentification Endpoints](#14-restful-api--deidentification-endpoints)
   5. [RESTful API — Analytics Endpoints](#15-restful-api--analytics-endpoints)
   6. [Deidentification Profiles](#16-deidentification-profiles)
   7. [Bulk Mode](#17-bulk-mode)
   8. [Decoupled Mode](#18-decoupled-mode)
   9. [Part 10 Only Mode](#19-part-10-only-mode)
   10. [DIR Option](#110-dir-option)
   11. [Redaction](#111-redaction)
   12. [Hashing](#112-hashing)
   13. [Substituted Values](#113-substituted-values)
   14. [TimeShiftTag](#114-timeshifttag)
   15. [DICOM SCP Functionality](#115-dicom-scp-functionality)
   16. [Context Management](#116-context-management)
   17. [Email Notifications](#117-email-notifications)
   18. [Job ID Handling](#118-job-id-handling)
   19. [Context Save Frequency](#119-context-save-frequency)
   20. [DICOM Standard Supported Profiles](#120-dicom-standard-supported-profiles)
   21. [AnonymizationActions](#121-anonymizationactions)
   22. [ExtendedTags — Private Tags](#122-extendedtags--private-tags)
   23. [Reporting](#123-reporting)
   24. [Uncompressed P10 Image Download](#124-uncompressed-p10-image-download)
   25. [DICOM Destination and STOW-RS](#125-dicom-destination-and-stow-rs)
2. [Non-Functional Test Scenarios](#2-non-functional-test-scenarios)
   1. [Performance](#21-performance)
   2. [Scalability](#22-scalability)
   3. [Reliability and Resilience](#23-reliability-and-resilience)
   4. [Security and Compliance](#24-security-and-compliance)
   5. [Usability and Operability](#25-usability-and-operability)
   6. [Compatibility](#26-compatibility)
   7. [Storage and Resource Management](#27-storage-and-resource-management)

---

## 1. Functional Test Scenarios

### 1.1 Installation and Upgrades

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| INST-001 | Fresh installation via MSI | Run `AcuoDeidentificationSetup.msi`, accept license, configure Part10 WebService Server/Port, Deidentification Directory, Part10 Directory, History Directory, Context Directory, Input Watch Directory, and Database settings. Click Install. | Service installs successfully; `AcuoDeidentification` Windows service is registered and can be started. |
| INST-002 | Verify default directory creation | Install with default directory settings. | All configured directories (Part10, Deidentification, Context, InputWatch, History) are created on disk. |
| INST-003 | Custom directory paths during install | Provide non-default directory paths for all six directory fields during installation. | Service installs and uses the custom directory paths specified. |
| INST-004 | Database connection with integrated security | Configure DB connection string with `Integrated Security=true` and a valid `Initial Catalog` / `Data Source`. | Service starts successfully and can query the AcuoMed database. |
| INST-005 | Upgrade — stop, backup, install, restore, start | Stop the service, backup `AcuoDeidentificationService.exe.config`, run the new MSI installer, restore the backed-up config, and start the service. | Service upgrades without data loss; previous configuration properties are preserved. |
| INST-006 | Upgrade — config file preserved | After upgrade, compare restored config with original backup. | All custom configuration keys, profile definitions, and connection strings match. |
| INST-007 | Post-install config modification | After installation, manually edit `AcuoDeidentificationService.exe.config` and restart the service. | Service picks up the modified configuration values correctly. |
| INST-008 | Service account configuration | Configure the service to run under a specific service account (e.g., `.\AcuoServiceUser`). | Service starts and operates under the specified account with correct permissions. |

### 1.2 Configuration Properties

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| CFG-001 | DBConnectionString validation | Set a valid `DBConnectionString` with correct server, catalog, and credentials. | Service connects to the AcuoMed database and can run study identification queries. |
| CFG-002 | Invalid DBConnectionString | Set an invalid or unreachable `DBConnectionString`. | Service logs a meaningful error and does not crash; deidentification requests fail gracefully. |
| CFG-003 | Part10WebServiceEndpoint | Configure `Part10WebServiceEndpoint` to point to a valid AcuoAccess instance. | genp10 calls succeed; Part10 files are generated on disk. |
| CFG-004 | DeidentificationDirectory | Set `DeidentificationDirectory` to a valid writable path. | Deidentified output is written to the specified directory. |
| CFG-005 | Part10Directory | Set `Part10Directory` to a valid writable path. | Part10 files are staged in the specified directory during processing. |
| CFG-006 | ContextDirectory | Set `ContextDirectory` to a valid path. | Context files (`context_jobid.deident`) are created and persisted in this directory. |
| CFG-007 | HistoryDirectory | Set `HistoryDirectory` to a valid path with `IgnoreHistory=false`. | Processed study entries are recorded; re-processing the same input file skips already-processed studies. |
| CFG-008 | IgnoreHistory true | Set `IgnoreHistory=true`. | History tracking is disabled; re-processing the same input file re-processes all studies. |
| CFG-009 | RestServiceAddress | Set `RestServiceAddress` to a specific endpoint (e.g., `http://0.0.0.0:8099/AcuoDeidentification`). | REST API is available at the configured address. |
| CFG-010 | DeidentificationMaxDOP | Set `DeidentificationMaxDOP` to values 1, 5, and 10. | Service respects the degree of parallelism; higher values process studies concurrently in BulkMode. |
| CFG-011 | RemoteDicomDestination (global) | Set `RemoteDicomDestination` to `AETitle:Host:Port` format. | All jobs send deidentified data to the configured DICOM destination. |
| CFG-012 | LocalAETitle | Set `LocalAETitle` to a custom value. | DICOM send operations use the configured local AE title. |
| CFG-013 | DoNotDeleteAfterSend false (default) | Leave `DoNotDeleteAfterSend` at default (`false`). Send deidentified data to a DICOM destination. | After successful transmission, deidentified data is deleted from the output directory. |
| CFG-014 | DoNotDeleteAfterSend true | Set `DoNotDeleteAfterSend=true`. Send deidentified data to a DICOM destination. | After successful transmission, deidentified data remains in the output directory. |
| CFG-015 | IndexSeed property | Set `IndexSeed` to `1000`. | Generated PatientID values follow the pattern `[Patient ID.1001]`, `[Patient ID.1003]`, etc. |
| CFG-016 | PseudonymPattern | Set `PseudonymPattern` to `TEST{0}^ANONYMOUS^^^`. | Deidentified person names follow the template pattern (e.g., `TEST1001^ANONYMOUS^^^`). |
| CFG-017 | AnonymizationRecordDirectory | Define `AnonymizationRecordDirectory` to a valid path. | An anonymization report file is created for each run with Original→Deidentified mapping entries. |
| CFG-018 | ReidentificationSecret | Set an encrypted `ReidentificationSecret`. | `EncryptedAttributeSequence` content is encrypted using the configured key. |

### 1.3 Input Watch Directory — Study Identification

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| IW-001 | OID with StudyInstanceUID only | Drop file with line: `OID\|<StudyInstanceUID>` | Service identifies the study across all databases and deidentifies it. |
| IW-002 | OID with StudyInstanceUID and Database | Drop file with line: `OID\|<StudyInstanceUID>\|<Database>` | Service queries only the specified database (single SQL query) and deidentifies the study. |
| IW-003 | ACC with AccessionNumber only | Drop file with line: `ACC\|<AccessionNumber>` | Service identifies the study by accession number and deidentifies it. |
| IW-004 | ACC with AccessionNumber and Database | Drop file with line: `ACC\|<AccessionNumber>\|<Database>` | Single-database query used; study deidentified. |
| IW-005 | MRNSTD with PatientID and StudyDate | Drop file with line: `MRNSTD\|<PatientID>\|<StudyDate>` | Service identifies the study by patient ID + study date and deidentifies it. |
| IW-006 | MRNSTD with PatientID, StudyDate, Database | Drop file with line: `MRNSTD\|<PatientID>\|<StudyDate>\|<Database>` | Single-database query used; study deidentified. |
| IW-007 | MRNBLK with PatientID (BulkMode) | Enable `BulkMode=true`. Drop file with line: `MRNBLK\|<PatientID>` | All studies for the patient are deidentified at the patient level. |
| IW-008 | MRNBLK with PatientID and Database | Enable `BulkMode=true`. Drop file with line: `MRNBLK\|<PatientID>\|<Database>` | Patient-level deidentification using specified database. |
| IW-009 | ACCBLK with AccessionNumber (BulkMode) | Enable `BulkMode=true`. Drop file with line: `ACCBLK\|<AccessionNumber>` | All studies matching the accession number are deidentified. |
| IW-010 | ACCBLK with AccessionNumber and Database | Enable `BulkMode=true`. Drop file with line: `ACCBLK\|<AccessionNumber>\|<Database>` | Single-database bulk deidentification. |
| IW-011 | Multiple studies in one file | Drop file with multiple lines using different identification types. | All studies in the file are processed sequentially. |
| IW-012 | Study matches multiple records | Drop file where the identifier resolves to more than one study. | All matching studies are deidentified. |
| IW-013 | Invalid study identifier | Drop file with a non-existent StudyInstanceUID. | Service logs a failure for the entry; other entries continue processing. |
| IW-014 | Empty input file | Drop an empty file into the watch directory. | Service processes the file without error; no deidentification occurs. |
| IW-015 | Malformed input line | Drop file with a line missing the `\|` separator. | Service logs a parse error for the malformed line; other valid lines are processed. |
| IW-016 | File picked up automatically | Drop a file into `InputWatchDirectory`. | Service detects the new file and begins processing without manual intervention. |
| IW-017 | Output directory structure | Complete a deidentification via input watch. | Output is written in `DeIdPatientID\DeIdStudyInstanceUID\DeIdSOPInstanceUID.dcm` format. |
| IW-018 | Part10 cleanup after deidentification | Complete a deidentification via input watch. | Original Part10 staging files are deleted after successful deidentification. |
| IW-019 | History tracking — skip reprocessing | Process a file with `IgnoreHistory=false`, then drop the same file again. | Second run skips already-processed studies. |
| IW-020 | MRNBLK without BulkMode | Set `BulkMode=false`. Drop file with `MRNBLK` entry. | Service either rejects the entry or processes it incorrectly; validate expected behavior. |

### 1.4 RESTful API — Deidentification Endpoints

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| API-001 | POST /deidentify (async) | Send POST to `/deidentify` with valid `DeIdentificationRequest` JSON (StudyEntries, ID, ProfileID). | Returns immediately (202 or void); deidentification starts in background. |
| API-002 | POST /deidentifysync (sync) | Send POST to `/deidentifysync` with valid `DeIdentificationRequest` JSON. | Blocks until completion; returns `DeidentificationJobStatus` with Successful, Failed, PercentCompletion, ElapsedMilliseconds. |
| API-003 | GET /status | Send GET to `/status` while jobs are running. | Returns array of `DeidentificationJobStatus` objects for all active jobs. |
| API-004 | GET /anonymizationreport/{JobID} | After successful deidentification, send GET to `/anonymizationreport/{JobID}`. | Returns `DeidentificationReport` with OriginalPatientID→AnonymizedPatientID mappings for each study. |
| API-005 | GET /jobreport/{JobID} | After successful deidentification, send GET to `/jobreport/{JobID}`. | Returns job status report with per-entry details (Identifier, Status, Database, TimeStamp, InstanceCount, ErrorMessage). |
| API-006 | GET /studyreport/{JobID}/{Database}/{PatientID}/{StudyID} | After deidentification, request the study-level report. | Returns detailed changes between original and deidentified data for the specified study. |
| API-007 | POST /deidentify with DicomDestination | Include a non-null `RemoteDicomDestination` object in the request. | After deidentification, studies are sent to the specified DICOM destination and then deleted from the output directory. |
| API-008 | POST /deidentify with null DicomDestination | Set `RemoteDicomDestination` to null. | Deidentified studies remain on the preconfigured output partition. |
| API-009 | POST /deidentify with StatusCallbackURI | Include a valid `StatusCallbackURI` in the request. | Service sends periodic HTTP PATCH requests with `DeidentificationJobStatus` at 25% completion intervals. |
| API-010 | POST /deidentify with IndexSeed override | Include `IndexSeed > 0` in the request. | The provided IndexSeed overrides the global/profile value for this job. |
| API-011 | POST with SubstitutionValues | Include `SubstitionValues` dictionary with `tag\|oldvalue\|newvalue` mappings. | Specified tags use the substitution values instead of generated anonymized values. |
| API-012 | POST with invalid StudyInstanceUID | Send request with non-existent `StudyInstanceUID`. | Job reports failure for the entry; returns appropriate error in status. |
| API-013 | POST with empty StudyEntries array | Send request with an empty `StudyEntries` array. | Service handles gracefully; returns success with 0 processed. |
| API-014 | POST with missing ProfileID | Send request without `ProfileID`. | Default deidentification profile is applied. |
| API-015 | POST with invalid ProfileID | Send request with a `ProfileID` not defined in configuration. | Default deidentification profile is applied as fallback. |
| API-016 | Multiple concurrent POST requests | Send multiple async `/deidentify` requests simultaneously with different Job IDs. | All jobs process independently; no data corruption or cross-contamination between contexts. |

### 1.5 RESTful API — Analytics Endpoints

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| ANL-001 | POST /analytics (async) with Type=DID | Send POST to `/analytics` with `AnalyticsRequest` where `Type=DID`. | Deidentification operation is triggered asynchronously. |
| ANL-002 | POST /analyticssync (sync) with Type=DID | Send POST to `/analyticssync` with `Type=DID`. | Blocks until completion; returns `DeidentificationJobStatus`. |
| ANL-003 | POST /analytics with Type=P10 | Send POST to `/analytics` with `Type=P10`. | Part10 files are generated without deidentification. |
| ANL-004 | POST /analytics with Type=P10 and TargetDirectory | Include `TargetDirectory` with `Type=P10`. | Part10 files are written to the specified `TargetDirectory` (overrides AcuoAccess default). |
| ANL-005 | POST /analytics with STOWURI | Include a valid `STOWURI` and null `RemoteDicomDestination`. | Studies are sent via STOW-RS to the specified endpoint. |
| ANL-006 | POST /analytics with both DicomDestination and STOWURI | Provide both `RemoteDicomDestination` and `STOWURI`. | DICOM destination takes precedence; STOW is ignored. |
| ANL-007 | POST /analytics with SubstitutionValues | Include `SubstitionValues` in the `AnalyticsRequest`. | Tag substitutions are applied during deidentification. |

### 1.6 Deidentification Profiles

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| PRF-001 | Multiple profiles defined | Define two profiles (`ResearchGroup1`, `PartnerProfile2`) in `DeidentificationProfileConfigSection`. | Both profiles are available for use by Job ID or REST API. |
| PRF-002 | Profile-specific DeidentificationEpochs | Define profile with `DeidentificationEpochs="1960"`. Submit a job using this profile. | Date shifting uses 1960 as the epoch base. |
| PRF-003 | Profile-specific AnonymizationActions | Define profile with custom `AnonymizationActions`. | Only the specified tag actions are applied (no default DICOM standard actions). |
| PRF-004 | Profile-specific PseudonymPattern | Define profile with `PseudonymPattern="TEST{0}^ANONYMOUS^^^"`. | Person names follow the configured pattern. |
| PRF-005 | Profile-specific IndexSeed | Define profile with a unique `IndexSeed` value. | Generated IDs start from the profile-specific seed. |
| PRF-006 | Profile-specific ContextSaveFrequency | Define profile with `ContextSaveFrequency=50`. | Context is saved every 50 entries rather than every entry. |
| PRF-007 | Profile-specific DeidOutputDirectory | Define profile with a custom `DeidOutputDirectory`. | Deidentified output is written to the profile-specific directory. |
| PRF-008 | Profile-specific DicomDestination | Define profile with a DICOM destination in `LocalAE:RemoteAE:host:port` format. | Deidentified data is sent to the profile-specific DICOM destination. |
| PRF-009 | Profile-specific DicomUidRoot | Define profile with a unique `DicomUidRoot`. | Generated UIDs use the profile-specific root prefix. |
| PRF-010 | Profile-specific HashedValues | Define profile with `HashedValues=true` and a unique `HashSalt`. | All values are hashed using the profile-specific salt. |
| PRF-011 | Profile fallback to defaults | Define profile with only `ProfileId` and no other properties. | Unspecified properties fall back to the global default values. |
| PRF-012 | Profile via input watch file name | Drop file named `523_ResearchGroup1_20200419.txt`. | Job ID is 523, and `ResearchGroup1` profile is applied. |
| PRF-013 | Profile via REST API ProfileID | Send POST with `ProfileID=PartnerProfile2`. | `PartnerProfile2` configuration is applied. |
| PRF-014 | Undefined profile in request | Reference a profile ID not in config via REST API or watch file. | Default profile settings are applied. |

### 1.7 Bulk Mode

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| BLK-001 | BulkMode=true with MRNBLK entries | Set `BulkMode=true`, `DecoupledMode=false`. Drop file with `MRNBLK\|<PatientID>` entries. | All studies for each patient are deidentified; no deidentification context is used. |
| BLK-002 | BulkMode=true with ACCBLK entries | Set `BulkMode=true`. Drop file with `ACCBLK\|<AccessionNumber>` entries. | All matching studies are deidentified in bulk. |
| BLK-003 | BulkMode with DeidentificationMaxDOP | Set `BulkMode=true` and `DeidentificationMaxDOP=5`. | Up to 5 studies are processed concurrently. |
| BLK-004 | BulkMode — no context file | Set `BulkMode=true`. Run a deidentification batch. | No context file is created or maintained. |
| BLK-005 | BulkMode with PseudonymPattern | Set `BulkMode=true` and define `PseudonymPattern`. | Pseudonym pattern is the only option for person names in BulkMode. |
| BLK-006 | BulkMode — IndexSeed progression | Run two consecutive bulk batches with different IndexSeed values. | Each batch uses its own starting seed; no overlapping anonymized IDs. |

### 1.8 Decoupled Mode

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| DCM-001 | DecoupledMode=true | Set `DecoupledMode=true` and `BulkMode=false`. | Service uses RESTful query and WADO classic from AcuoAccess; no direct DB or shared partition access needed. |
| DCM-002 | Decoupled — study retrieval via WADO | In decoupled mode, submit a deidentification request. | Studies are retrieved via WADO with `transferSyntax=donottranscode` and the correct `domainID`. |
| DCM-003 | Decoupled — remote server operation | Deploy the service on a remote server with only AcuoAccess endpoint access. | Service operates correctly without direct VNA database access. |
| DCM-004 | DecoupledMode and BulkMode mutual exclusion | Set both `DecoupledMode=true` and `BulkMode=true`. | Validate that the configuration behaves as documented (DecoupledMode must be false for BulkMode). |

### 1.9 Part 10 Only Mode

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| P10-001 | OID_P10 identification | Drop file with `OID_P10\|<StudyInstanceUID>` or `OID_P10\|<StudyInstanceUID>\|<Database>`. | Part10 files are generated without deidentification; data remains in Part10Directory. |
| P10-002 | ACC_P10 identification | Drop file with `ACC_P10\|<AccessionNumber>`. | Part10 files generated by accession number without deidentification. |
| P10-003 | MRNSTD_P10 identification | Drop file with `MRNSTD_P10\|<PatientID>\|<StudyDate>`. | Part10 files generated by patient + date without deidentification. |
| P10-004 | MRNBLK_P10 with BulkMode | Set `BulkMode=true`. Drop file with `MRNBLK_P10\|<PatientID>`. | Part10 generated for all studies of the patient without deidentification. |
| P10-005 | ACCBLK_P10 with BulkMode | Set `BulkMode=true`. Drop file with `ACCBLK_P10\|<AccessionNumber>`. | Part10 generated for all matching studies without deidentification. |
| P10-006 | Part10 data not deleted | Complete a Part10-only operation. | Data remains in the Part10 directory and is not cleaned up. |
| P10-007 | Sufficient disk space warning | Run Part10 generation when disk space is low. | Service logs a warning or handles the situation gracefully. |

### 1.10 DIR Option

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| DIR-001 | DIR basic operation | Drop file with `DIR\|<InputDirectory>\|<OutputDirectory>`. | All `.dcm` files in the input directory are deidentified and written to the output directory. |
| DIR-002 | DIR recursive parsing | Place `.dcm` files in nested subdirectories within the input directory. | Service recursively finds and processes all `.dcm` files. |
| DIR-003 | DIR output naming | Run a DIR deidentification. | Output files follow `DeIdPatientID\DeIdStudyInstanceUID\DeIdSOPInstanceUID.dcm` naming. |
| DIR-004 | DIR non-existent input directory | Drop file with `DIR\|<NonExistentDir>\|<OutputDir>`. | Service logs an error; does not crash. |
| DIR-005 | DIR mixed file types | Place both `.dcm` and non-`.dcm` files in the input directory. | Only `.dcm` files are processed; other files are ignored. |

### 1.11 Redaction

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| RED-001 | Redaction enabled | Set `Redact=True` in `<Hyland.Nil.Deidentify.Properties.Settings>`. | Noise patterns are applied to mask burned-in demographics in DICOM images. |
| RED-002 | Redaction disabled (default) | Leave `Redact` at default (`False`). | No noise patterns are applied to images. |
| RED-003 | Redaction with matching template | Configure a `Masks` template matching a specific Modality/Manufacturer/Model/Rows/Columns. Process a DICOM file matching those attributes. | Redaction rectangles are applied at the specified coordinates. |
| RED-004 | Redaction with non-matching template | Process a DICOM file that does not match any configured `Masks` template. | No redaction is applied to the image. |
| RED-005 | Multiple redaction rectangles | Define a template with multiple `<RG>` elements. | All specified rectangles are masked with noise. |
| RED-006 | Redaction template — Philips US | Configure template for Modality=US, Manufacturer=Philips, Model=iE33, Rows=600, Cols=800. | Correct regions are redacted for matching Philips US images. |

### 1.12 Hashing

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| HSH-001 | HashedValues enabled | Set `HashedValues=true` with a non-zero `HashSalt`. | String VRs, DA/DT VRs, PN VRs, and UI VRs are hashed using CRC64-based algorithms. |
| HSH-002 | SH value length | Hash an SH VR value. | Result is exactly 16 hexadecimal characters (0-9, A-F). |
| HSH-003 | LO value length | Hash an LO VR value. | Result is exactly 32 hexadecimal characters. |
| HSH-004 | UI VR compliance | Hash a UI VR value. | Result is a valid, compliant DICOM UID. |
| HSH-005 | Date hashing | Hash DA/DT VR values. | Dates are shifted using the TimeMachine class with hashing applied. |
| HSH-006 | Consistency with same HashSalt | Run deidentification twice on the same data with the same `HashSalt`. | Identical anonymized values are produced both times. |
| HSH-007 | Different HashSalt produces different results | Run deidentification on the same data with different `HashSalt` values. | Different anonymized values are produced. |
| HSH-008 | Hashing irreversibility | Attempt to reverse hashed values. | Hashed values cannot be reversed to original values. |

### 1.13 Substituted Values

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| SUB-001 | Profile-level SubstitutedValues | Set `SubstitutedValues=true` in a profile and define `TagSubstitutions`. | Specified tags use the substitution values. |
| SUB-002 | Programmatic SubstitutionValues via POST | Include `SubstitionValues` in the POST body with `tag\|oldvalue\|newvalue` entries. | Tags matching the old values are replaced with the specified new values. |
| SUB-003 | Substitution with tag\|\|newvalue format | Use the `tag\|\|newvalue` format for a CS VR. | Tag is set to the new value regardless of the original value. |
| SUB-004 | PatientID substitution | Provide PatientID (0010,0020) substitution mapping. | Original PatientID values are replaced with the specified substitutes. |
| SUB-005 | AccessionNumber substitution | Provide AccessionNumber (0008,0050) substitution mapping. | Original accession numbers are replaced with specified substitutes. |
| SUB-006 | SubstitutionValues overrides profile defaults | Provide substitutions via POST for a profile that also has defaults. | POST-provided substitutions take precedence. |

### 1.14 TimeShiftTag

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| TSH-001 | TimeShiftTag with valid DA tag | Set `TimeShiftTag` to a valid DA VR tag (e.g., `0x00100030` — Patient Birth Date). | All dates in the study are shifted relative to the value of the specified tag. |
| TSH-002 | TimeShiftTag with DeidentificationEpochs | Set `TimeShiftTag` and `DeidentificationEpochs=1960`. | Dates are shifted using the epoch as the target base. |
| TSH-003 | TimeShiftTag not set | Leave `TimeShiftTag` unspecified. | Default date de-identification behavior is used (dates > 100 years in the future). |

### 1.15 DICOM SCP Functionality

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| SCP-001 | DeidentificationSCP configuration | Set `DeidentificationSCP=DEIDAE:1045`. | Service listens for C-Store requests on AETitle `DEIDAE`, port `1045`. |
| SCP-002 | ReidentificationSCP configuration | Set `ReidentificationSCP=REIDAE:1046`. | Service listens for re-identification C-Store requests on the configured AE/port. |
| SCP-003 | DICOM C-Store ingestion for de-id | Send DICOM data via C-Store to the DeidentificationSCP endpoint. | Data is received and stored in `DeidentificationSCPDirectory` organized by profile/jobid/studyinstanceuid. |
| SCP-004 | DICOM C-Store ingestion for re-id | Send DICOM data via C-Store to the ReidentificationSCP endpoint. | Data is received; re-identification is performed using EncryptedAttributeSequence. |
| SCP-005 | Re-identification — missing EncryptedAttributeSequence | Send data without EncryptedAttributeSequence to the re-id SCP. | Service throws an exception and logs the error. |
| SCP-006 | Re-identification — mismatched secret key | Attempt re-identification with a different `ReidentificationSecret`. | Service throws an exception due to decryption failure. |
| SCP-007 | Multiple Called AETitles on same port | Define two profiles with different AETitles on the same port. | Service correctly routes to the appropriate profile based on Called AETitle. |
| SCP-008 | Job ID from CallingAETitle | Send data with Calling AETitle `AE_37651`. | Job ID is set to `37651`. |
| SCP-009 | DicomCompletionIntervalSeconds | Set `DicomCompletionIntervalSeconds=120`. Send data and wait. | Processing does not begin until the study directory's last-write timestamp is older than 120 seconds. |
| SCP-010 | Directory suffix progression | Track directory suffixes during SCP pipeline processing. | Directories progress from no suffix → `.deid`/`.reid` → `.deidc`/`.reidc` on completion. |
| SCP-011 | DICOM SCP cache cleaner | Configure `DICOMSCPCacheCleanerIntervalSeconds`, `DICOMSCPCacheHoursToRetain`, and `DICOMSCPCacheCleanerDOP`. | Completed directories (`.deidc`/`.reidc`) are cleaned up after the configured retention period. |
| SCP-012 | ReidentificationMaxDOP | Set `ReidentificationMaxDOP=3`. Send multiple studies for re-identification. | Up to 3 studies are re-identified concurrently. |
| SCP-013 | DeidentificationMaxDOP with SCP | Set `DeidentificationMaxDOP=5`. | Parallelism is applied at the jobid level for de-identification contexts. |
| SCP-014 | Profile-specific DeidOutputDirectory via SCP | Configure `DeidOutputDirectory` in a profile. Send data to the profile's SCP. | Deidentified output is written to the profile-specific directory. |
| SCP-015 | Profile-specific ReidOutputDirectory | Configure `ReidOutputDirectory` in a profile. Send data for re-id. | Re-identified output is written to the profile-specific directory. |
| SCP-016 | ReidDicomDestination | Configure `ReidDicomDestination` in a profile. | Re-identified data is sent to the specified DICOM destination. |

### 1.16 Context Management

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| CTX-001 | GET /context | Send GET to `/context`. | Returns array of `ContextInfo` objects with ID, Size, CreationDateTime, LastUpdateDateTime. |
| CTX-002 | DELETE /context/{JobID} | Send DELETE to `/context/{JobID}` for an existing context. | Context is deleted; subsequent GET confirms removal. |
| CTX-003 | Context reuse across submissions | Submit two batches with the same Job ID spaced in time. | Second batch leverages the persisted context; consistent deidentification mappings. |
| CTX-004 | Context growth monitoring | Submit progressively larger batches. | Context file size grows; `GetContextInfo` reflects the increased size. |
| CTX-005 | Delete non-existent context | Send DELETE for a non-existent Job ID. | Service returns an appropriate error or no-op. |

### 1.17 Email Notifications

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| EML-001 | Email on status update | Configure SMTP settings (SmtpServer, SmtpPort, SmtpUser, SmtpPwd, SmtpUseSSL, SmtpFromAddress, SmtpToAddresses). Submit a job with `StatusCallbackURI`. | Email is sent with the same body as the PATCH request at each status update. |
| EML-002 | Email to multiple recipients | Set `SmtpToAddresses` with comma-separated addresses. | Email is delivered to all configured recipients. |
| EML-003 | Email with SSL | Set `SmtpUseSSL=true` with correct port (587). | Emails are sent over a secure TLS connection. |
| EML-004 | Invalid SMTP configuration | Configure invalid SMTP server settings. | Email sending fails gracefully with a logged error; deidentification is not affected. |
| EML-005 | Email disabled | Do not configure any SMTP properties. | No emails are sent; service operates normally. |

### 1.18 Job ID Handling

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| JOB-001 | Job ID from file name prefix | Drop file named `523_CTProfile1_20200419.txt`. | Job ID is set to `523`. |
| JOB-002 | ProfileID from file name | Drop file named `523_CTProfile1_20200419.txt`. | Profile `CTProfile1` is applied. |
| JOB-003 | Job ID from REST API | Send POST with `ID=101`. | Job ID is `101` for all context, status, and report operations. |
| JOB-004 | Job ID reuse | Submit two batches with the same Job ID. | Second batch attaches to the existing context; consistent patient/study mappings. |
| JOB-005 | Concurrent jobs with different IDs | Submit multiple jobs with different Job IDs simultaneously. | Each job operates independently with separate contexts. |
| JOB-006 | Job ID for status tracking | Submit a job and call GET `/status` and GET `/jobreport/{JobID}`. | Correct status is returned for the specified Job ID. |
| JOB-007 | File name without Job ID prefix | Drop file named `profile_20200419.txt` (no integer prefix). | Service handles the file with a default or auto-generated Job ID. |

### 1.19 Context Save Frequency

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| CSF-001 | Default ContextSaveFrequency=1 | Leave `ContextSaveFrequency` at default. Process a batch of 100 studies. | Context is saved after every single study (100 save operations). |
| CSF-002 | ContextSaveFrequency=50 | Set `ContextSaveFrequency=50`. Process a batch of 100 studies. | Context is saved every 50 entries (2 save operations during processing + 1 at completion). |
| CSF-003 | Context saved at batch completion | Set `ContextSaveFrequency=50`. Process a batch of 75 studies. | Context is saved after entry 50 and once more at batch completion. |
| CSF-004 | BulkMode ignores ContextSaveFrequency | Set `BulkMode=true` and `ContextSaveFrequency=50`. | ContextSaveFrequency has no effect in BulkMode (no context is used). |
| CSF-005 | Interrupted batch with large save frequency | Set `ContextSaveFrequency=50`. Interrupt processing at entry 30. | Context on disk reflects the last save point (entry 0 — no saves yet); potential data/context mismatch. |

### 1.20 DICOM Standard Supported Profiles

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| DSP-001 | RetainSafePrivate | Set `Profiles=RetainSafePrivate`. | Safe private attributes are retained during deidentification. |
| DSP-002 | RetainUIDs | Set `Profiles=RetainUIDs`. | DICOM UIDs are retained (not replaced). |
| DSP-003 | RetainDeviceIdent | Set `Profiles=RetainDeviceIdent`. | Device identification attributes are retained. |
| DSP-004 | RetainInstitutionIdent | Set `Profiles=RetainInstitutionIdent`. | Institution identification attributes are retained. |
| DSP-005 | RetainPatientChars | Set `Profiles=RetainPatientChars`. | Patient characteristic attributes are retained. |
| DSP-006 | RetainLongFullDates | Set `Profiles=RetainLongFullDates`. | Full dates are retained for longitudinal consistency. |
| DSP-007 | RetainLongModifDates | Set `Profiles=RetainLongModifDates`. | Modified dates are retained for longitudinal consistency. |
| DSP-008 | CleanDesc | Set `Profiles=CleanDesc`. | Description fields are cleaned of identifying information. |
| DSP-009 | CleanStructCont | Set `Profiles=CleanStructCont`. | Structured content is cleaned. |
| DSP-010 | CleanGraph | Set `Profiles=CleanGraph`. | Graphic data is cleaned. |
| DSP-011 | Multiple profiles combined | Set `Profiles=RetainSafePrivate,RetainLongModifDates,CleanDesc`. | All specified profiles are applied in combination. |
| DSP-012 | Conflicting profiles | Set profiles that are documented as conflicting (e.g., `RetainLongFullDates,RetainLongModifDates`). | Service handles the conflict as per DICOM PS 3.15 specification. |

### 1.21 AnonymizationActions

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| AA-001 | Action code D (dummy value) | Set `AnonymizationActions` with `BasicProfile=D` for a tag. | Tag value is replaced with a non-zero dummy value consistent with the VR. |
| AA-002 | Action code Z (zero-length) | Set `BasicProfile=Z` for a tag. | Tag value is replaced with a zero-length or dummy value. |
| AA-003 | Action code X (remove) | Set `BasicProfile=X` for a tag. | Tag is removed from the DICOM dataset. |
| AA-004 | Action code K (keep) | Set `BasicProfile=K` for a tag. | Non-Sequence attribute is kept unchanged; Sequences are cleaned. |
| AA-005 | Action code C (clean) | Set `BasicProfile=C` for a tag. | Tag is replaced with a similar-meaning value that contains no identifying information. |
| AA-006 | Action code U (UID replace) | Set `BasicProfile=U` for a UID tag. | UID is replaced with a consistent, non-zero-length UID within the instance set. |
| AA-007 | Action code Z/D | Set `BasicProfile=Z/D` for a tag. | Z is applied unless D is required for IOD conformance (Type 2 vs. Type 1). |
| AA-008 | Action code X/Z | Set `BasicProfile=X/Z` for a tag. | X is applied unless Z is required (Type 3 vs. Type 2). |
| AA-009 | Action code X/D | Set `BasicProfile=X/D` for a tag. | X is applied unless D is required (Type 3 vs. Type 1). |
| AA-010 | Action code X/Z/D | Set `BasicProfile=X/Z/D` for a tag. | X unless Z or D is required (Type 3 vs. 2 vs. 1). |
| AA-011 | Action code X/Z/U* | Set `BasicProfile=X/Z/U*` for a sequence tag. | Appropriate action based on IOD conformance for sequences with UID references. |
| AA-012 | Multiple AnonymizationActions | Define actions for multiple tags in a single `AnonymizationActions` JSON array. | Each tag is processed with its specified action; no other tags are affected. |
| AA-013 | AnonymizationActions overrides DICOM profiles | Set `AnonymizationActions` when DICOM `Profiles` are also set. | Only `AnonymizationActions` are applied; standard profiles are bypassed. |

### 1.22 ExtendedTags — Private Tags

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| EXT-001 | Define ExtendedTags | Configure `ExtendedTags` with private creator tags and their associated private tags. | Private tags are registered as dictionary extensions. |
| EXT-002 | ExtendedTags in AnonymizationActions | Define an extended tag and reference it in `AnonymizationActions`. | The private tag is processed according to the specified action. |
| EXT-003 | ExtendedTags in AnonymizationExtensions | Define an extended tag and reference it in `AnonymizationExtensions`. | The private tag is treated as a regular tag during deidentification. |
| EXT-004 | ExtendedTags in profile config | Define `ExtendedTags` within a `DeidentificationProfile` using `&quot;` XML encoding. | JSON deserializes correctly; private tags are registered for the profile. |
| EXT-005 | Private tags without ExtendedTags | Process a DICOM file with private tags and no `ExtendedTags` defined (no `RetainSafePrivate`). | Private tags are removed during deidentification. |

### 1.23 Reporting

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| RPT-001 | Anonymization report file | Configure `AnonymizationRecordDirectory`. Run a deidentification job. | Report file is created with entries: `OriginalPatientID\|OriginalAccessionNumber\|OriginalStudyInstanceUID\|DeidentifiedPatientID\|DeidentifiedAccessionNumber\|DeidentifiedStudyInstanceUID`. |
| RPT-002 | Report per job | Run multiple jobs. Check `AnonymizationRecordDirectory`. | Separate report files exist for each job. |
| RPT-003 | GET deidentification report via API | Call GET `/anonymizationreport/{JobID}`. | Returns `DeidentificationReport` with entries showing original-to-anonymized mappings. |
| RPT-004 | GET study report via API | Call GET `/studyreport/jobs/{JobID}/databases/{Database}/patients/{PatientID}/studies/{StudyID}`. | Returns detailed tag-level changes for the specified study. |
| RPT-005 | GET job status report | Call GET `/jobreport/{JobID}`. | Returns per-entry status with Identifier, Status, Database, TimeStamp, InstanceCount, ErrorMessage. |

### 1.24 Uncompressed P10 Image Download

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| UNC-001 | Download uncompressed P10 — ILE | Set `DownloadUncompressedP10Images=true` and `P10UncompressedTransferSyntaxValue=1.2.840.10008.1.2`. | P10 images are decompressed to Implicit VR Little Endian. |
| UNC-002 | Download uncompressed P10 — ELE | Set `P10UncompressedTransferSyntaxValue=1.2.840.10008.1.2.1`. | P10 images are decompressed to Explicit VR Little Endian. |
| UNC-003 | Compressed source images | Source images stored as JPEG Lossless or JPEG 2000 Lossless in VNA. | Images are correctly decompressed to the configured transfer syntax. |
| UNC-004 | Feature disabled (default) | Do not set `DownloadUncompressedP10Images`. | P10 images are retrieved in their original compressed format. |

### 1.25 DICOM Destination and STOW-RS

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| DST-001 | RemoteDicomDestination via REST API | Include `RemoteDicomDestination` in POST with `LocalAETitle`, `RemoteAETitle`, `RemoteHost`, `RemotePort`. | Deidentified studies are sent to the specified DICOM destination. |
| DST-002 | Profile-level DicomDestination | Configure `DicomDestination` in a profile. | All jobs using the profile send data to the profile's DICOM destination. |
| DST-003 | API DicomDestination overrides global | Set a global `RemoteDicomDestination` and provide a different one via API. | API-provided destination is used (programmatic non-null values overwrite global). |
| DST-004 | STOW-RS endpoint | Include `STOWURI` in the analytics request with null `RemoteDicomDestination`. | Studies are sent via STOW-RS protocol. |
| DST-005 | STOW credentials | Configure `StowCredentials` for the de-id profile. | STOW-RS requests include the correct authentication credentials. |
| DST-006 | STOW re-id credentials | Configure `StowReidCredentials` / `StowReidUserId` / `StowReidPassword` for re-id. | Re-identification STOW-RS requests use the separate re-id credentials. |
| DST-007 | DICOM + STOW both specified | Provide both `RemoteDicomDestination` and `STOWURI`. | DICOM takes precedence; STOW is ignored. |
| DST-008 | Deletion after successful send | Set `DoNotDeleteAfterSend=false`. Send studies to a DICOM destination. | Studies are deleted from the output directory after successful send. |

---

## 2. Non-Functional Test Scenarios

### 2.1 Performance

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| PERF-001 | Single study de-id throughput | Deidentify a single CR/DX study (few instances). | Completes within acceptable time (baseline measurement). |
| PERF-002 | Large study de-id throughput | Deidentify a CT/MR study with thousands of DICOM instances. | Completes within acceptable time relative to instance count. |
| PERF-003 | Batch processing — small batch | Process a batch of 100 studies with `BulkMode=false`. | Batch completes; measure total elapsed time and per-study average. |
| PERF-004 | Batch processing — large batch | Process a batch of 10,000 studies with `BulkMode=true` and `DeidentificationMaxDOP=5`. | Batch completes with parallelism; measure throughput. |
| PERF-005 | ContextSaveFrequency impact | Compare batch processing time with `ContextSaveFrequency=1` vs. `ContextSaveFrequency=50` for 1,000 studies. | Higher save frequency significantly reduces total duration. |
| PERF-006 | Context growth impact | Process batches of increasing size (100, 1000, 5000, 10000 studies). | Measure context save/load time growth; verify it scales sub-linearly or report degradation. |
| PERF-007 | Synchronous API response time | Call `/deidentifysync` for a small study. | Response is returned within an acceptable latency. |
| PERF-008 | Concurrent API requests | Submit 10 concurrent async requests. | All requests are accepted and processed without significant throughput degradation. |
| PERF-009 | StatusCallbackURI latency | Submit a job with `StatusCallbackURI`. | PATCH callbacks arrive at approximately 25% intervals relative to actual completion. |
| PERF-010 | DICOM SCP ingestion throughput | Send 100 studies via C-Store to the SCP endpoint. | Studies are received and queued for processing within acceptable ingestion rate. |

### 2.2 Scalability

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| SCL-001 | DeidentificationMaxDOP scaling | Increase `DeidentificationMaxDOP` from 1 to 5 to 10 for the same batch. | Processing time decreases proportionally (or reports diminishing returns). |
| SCL-002 | ReidentificationMaxDOP scaling | Increase `ReidentificationMaxDOP` and measure concurrent re-id operations. | System scales re-identification operations according to the configured DOP. |
| SCL-003 | 100,000 study dataset — Chest X-Ray | Process 100,000 CR studies in batches of 20,000–25,000. | All batches complete successfully with properly managed IndexSeed progression. |
| SCL-004 | 100,000 study dataset — CT | Process 100,000 CT studies in batches of 5,000–10,000. | All batches complete; IndexSeed and context are properly managed between batches. |
| SCL-005 | Multiple concurrent jobs | Submit 10+ independent jobs simultaneously via REST API. | All jobs execute with independent contexts; no resource contention failures. |
| SCL-006 | Large context file handling | Grow a context file to > 1 GB through large batches. | Service continues to save and reload the context without memory or I/O failures. |
| SCL-007 | DICOMSCPCacheCleanerDOP | Configure `DICOMSCPCacheCleanerDOP` for parallel cache cleanup of thousands of completed directories. | Directories are cleaned up efficiently using the configured parallelism. |

### 2.3 Reliability and Resilience

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| REL-001 | Service restart recovery | Stop the service mid-batch, then restart. | With history enabled, service skips already-processed studies and resumes processing. |
| REL-002 | Interrupted batch — context integrity | Interrupt a batch during processing (`ContextSaveFrequency=50`, stopped at entry 30). | Context file reflects last saved state; operator can assess and recover. |
| REL-003 | AcuoAccess unavailability | Bring down AcuoAccess while the deidentification service is running. | Service logs errors for pending requests; does not crash; recovers when AcuoAccess returns. |
| REL-004 | Database unavailability | Make the AcuoMed database inaccessible. | Service logs DB connection errors; queued jobs fail gracefully. |
| REL-005 | Disk full — output directory | Fill the output directory partition. | Service logs appropriate errors; does not corrupt existing data. |
| REL-006 | Disk full — context directory | Fill the context directory partition. | Context save fails gracefully with a logged error. |
| REL-007 | DICOM destination unreachable | Configure a DICOM destination that is offline. | Service logs send failure; deidentified data is retained (not deleted). |
| REL-008 | Corrupt DICOM input | Send a corrupt or non-DICOM file for processing. | Service logs an error for the file; other files in the batch are processed normally. |
| REL-009 | Large file in input watch | Drop a very large input file (> 100,000 entries). | Service processes the file without crashing; may take longer but completes. |
| REL-010 | Service uptime — long running | Run the service continuously for 7+ days processing periodic batches. | Service remains stable with no memory leaks or degradation. |

### 2.4 Security and Compliance

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| SEC-001 | PHI removal completeness | Deidentify a study and inspect all DICOM Attribute Confidentiality Profile tags (PS 3.15 Annex E). | All tags specified by the DICOM standard for removal/replacement are properly handled. |
| SEC-002 | EncryptedAttributeSequence | Verify that the `EncryptedAttributeSequence` is populated and encrypted using `ReidentificationSecret`. | Sequence is present and encrypted; cannot be read without the correct key. |
| SEC-003 | Re-identification only with correct key | Attempt re-identification with the correct `ReidentificationSecret`. | Original data is correctly restored. |
| SEC-004 | Re-identification with wrong key | Attempt re-identification with an incorrect `ReidentificationSecret`. | Service throws an exception; data is not decrypted. |
| SEC-005 | Hashed values irreversibility | Analyze hashed output values for a large dataset. | No statistical method can reverse the CRC64-based hashing. |
| SEC-006 | SMTP credentials encryption | Verify that `SmtpUser` and `SmtpPwd` values are encrypted in the config file. | Credentials are not stored in plaintext. |
| SEC-007 | ReidentificationSecret encryption | Verify that `ReidentificationSecret` is stored encrypted in the config. | Secret is not readable in plaintext from the configuration file. |
| SEC-008 | Authenticated REST endpoint | Configure the authenticated REST endpoint (`http://0.0.0.0:8299/AcuoDeidentification`). | Only authenticated requests are accepted. |
| SEC-009 | Deidentified dates — 100+ years in future | Inspect deidentified date values. | All deidentified dates are > 100 years in the future (unless TimeShiftTag/epoch is used). |
| SEC-010 | Private tag removal | Process a study with private tags (no `RetainSafePrivate`, no `ExtendedTags`). | All private tags are removed. |
| SEC-011 | PseudonymPattern — no original data leakage | Use `PseudonymPattern` and verify person names. | No original person name data appears in the deidentified output. |
| SEC-012 | Burned-in demographics — redaction verification | Enable redaction with appropriate templates. Visually inspect output images. | All specified demographic regions are masked with noise. |
| SEC-013 | Context file access control | Check file system permissions on the context directory. | Only the service account and administrators have read/write access. |
| SEC-014 | Anonymization report access control | Check permissions on the `AnonymizationRecordDirectory`. | Reports containing original-to-deidentified mappings are access-controlled. |

### 2.5 Usability and Operability

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| USB-001 | Log file informativeness | Review `DeidentifyLog.txt` after processing a batch. | Logs contain job ID, study identifiers, success/failure status, completion percentage, and elapsed time. |
| USB-002 | Error messages clarity | Trigger known error conditions (bad DB, missing files, invalid config). | Error messages in logs are descriptive and actionable. |
| USB-003 | Status callback usefulness | Receive status callbacks during processing. | `DeidentificationJobStatus` provides ID, Successful count, Failed count, PercentCompletion, and ElapsedMilliseconds. |
| USB-004 | API discoverability | List all available REST API endpoints. | Endpoints are accessible and return expected response formats (JSON). |
| USB-005 | Configuration documentation | Compare all config keys in `AcuoDeidentificationService.exe.config` with the user guide. | All documented properties are present and correctly described. |
| USB-006 | File naming convention clarity | Use various file naming patterns in the input watch directory. | `xxxx_ProfileId_date.txt` pattern is correctly parsed for Job ID, Profile, and date. |

### 2.6 Compatibility

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| CMP-001 | AcuoAccess 2018 Q1 compatibility | Run the service with AcuoAccess 2018 Q1. | Service operates correctly with the minimum supported AcuoAccess version. |
| CMP-002 | AcuoAccess latest version | Run the service with the latest AcuoAccess version. | Service operates correctly with the latest version. |
| CMP-003 | .NET Framework 4.5.1 minimum | Install and run on a system with .NET Framework 4.5.1. | Service installs and runs correctly. |
| CMP-004 | DICOM transfer syntax preservation | Process studies in various transfer syntaxes (JPEG Lossless, JPEG 2000, Implicit VR LE, Explicit VR LE). | Deidentified output preserves the original transfer syntax (unless uncompressed download is configured). |
| CMP-005 | Multiple DICOM databases | Run queries against multiple Acuo DICOM databases (DicomDb1, DicomDb2, etc.). | Service correctly identifies and processes studies from different databases. |
| CMP-006 | Various DICOM modalities | Deidentify studies of different modalities (CR, DX, CT, MR, US, MG). | All modalities are processed correctly with modality-specific handling (redaction templates, etc.). |
| CMP-007 | Part10SOPClassExclusions | Configure `Part10SOPClassExclusions` to exclude specific SOP classes. | Excluded SOP classes are not generated during Part10 creation. |
| CMP-008 | Part10ModalityExclusions | Configure `Part10ModalityExclusions` to exclude specific modalities. | Excluded modalities are not generated during Part10 creation. |
| CMP-009 | AWS S3 DICOM storage | Configure AWS S3 storage endpoints with SigV4 authentication. | DICOM data can be stored to and retrieved from S3. |

### 2.7 Storage and Resource Management

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| STR-001 | Part10 cleanup after de-id | Run a standard deidentification job. | Part10 staging files are deleted after deidentification completes. |
| STR-002 | Output cleanup after DICOM send | Send deidentified data to a DICOM destination with `DoNotDeleteAfterSend=false`. | Output files are deleted after successful transmission. |
| STR-003 | Part10-only disk usage | Run Part10-only operations. | Files remain on disk; available space decreases as expected. |
| STR-004 | DICOM SCP cache management | Run SCP operations with cache cleaner configured. | Old completed directories are cleaned up per `DICOMSCPCacheHoursToRetain`. |
| STR-005 | History directory growth | Process thousands of studies. | History directory grows proportionally; does not cause disk issues. |
| STR-006 | Context file size management | Monitor context file size across large batches. | Context grows as expected; size is reported correctly via `/context` API. |
| STR-007 | Memory usage under load | Monitor service memory during processing of a large batch. | Memory usage remains within acceptable bounds; no memory leaks. |
| STR-008 | CPU utilization with MaxDOP | Monitor CPU usage with different `DeidentificationMaxDOP` values. | CPU usage scales with DOP but does not exceed available resources. |

---

## Appendix: Deidentification Action Codes Reference

| Code | Description |
|------|-------------|
| D | Replace with a non-zero length dummy value consistent with the VR |
| Z | Replace with a zero-length value, or a non-zero length dummy value consistent with the VR |
| X | Remove |
| K | Keep (unchanged for non-Sequence attributes, cleaned for Sequences) |
| C | Clean — replace with similar-meaning values free of identifying information |
| U | Replace with a non-zero length UID, internally consistent within an instance set |
| Z/D | Z unless D is required for IOD conformance (Type 2 vs. Type 1) |
| X/Z | X unless Z is required for IOD conformance (Type 3 vs. Type 2) |
| X/D | X unless D is required for IOD conformance (Type 3 vs. Type 1) |
| X/Z/D | X unless Z or D is required for IOD conformance (Type 3 vs. Type 2 vs. Type 1) |
| X/Z/U* | X unless Z or UID replacement is required for IOD conformance (Type 3 vs. Type 2 vs. Type 1 sequences with UID references) |

*Reference: DICOM PS3.15 — Security and System Management Profiles*
