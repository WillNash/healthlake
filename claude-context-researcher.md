# Research Findings

## Source URLs

- [REDCap FAQ — projectredcap.org](https://projectredcap.org/about/faq/) — **Official**
- [REDCap Shared Library — projectredcap.org](https://projectredcap.org/resources/library/) — **Official**
- [REDCap Trial/Demo signup — redcapdemo.vumc.org](http://redcapdemo.vumc.org/trial/) — **Official**
- [REDCap Join page — projectredcap.org](https://projectredcap.org/join/) — **Official**
- [redcap-tools/redcap-test-datasets — GitHub](https://github.com/redcap-tools/redcap-test-datasets) — **Official** (redcap-tools org)
- [redcap-test-datasets archer folder](https://github.com/redcap-tools/redcap-test-datasets/tree/master/archer) — **Official**
- [REDCapDM vignette — bruigtp.github.io](https://bruigtp.github.io/REDCapDM/articles/REDCapDM.html) — **Official** (package docs)
- [covican dataset docs — rdrr.io](https://rdrr.io/cran/REDCapDM/man/covican.html) — **Official** (CRAN mirror)
- [heartland-redcap-template — GitHub vickymuller-md](https://github.com/vickymuller-md/heartland-redcap-template) — Semi-official (community GitHub, not affiliated with REDCap org)
- [NACC REDCap XML docs — docs.naccdata.org](https://docs.naccdata.org/edc/data-capture-development/project-initiation/redcap-xml) — **Official** (NACC)
- [NACC UDSv4 Resources — naccdata.org](https://www.naccdata.org/udsv4-resources-and-tools) — **Official** (NACC)
- [Synthea GitHub — synthetichealth/synthea](https://github.com/synthetichealth/synthea) — **Official**
- [Synthea CSVExporter javadoc](https://synthetichealth.github.io/synthea/build/javadoc/org/mitre/synthea/export/CSVExporter.html) — **Official**
- [Synthea FHIR for Research overview — mitre.github.io](https://mitre.github.io/fhir-for-research/modules/synthea-overview) — Semi-official (MITRE, Synthea authors)
- [AWS HealthLake Synthea preloaded data types](https://docs.aws.amazon.com/healthlake/latest/devguide/reference-healthlake-preloaded-data-types.html) — **Official** (AWS)
- [MIMIC-IV Clinical Database Demo v2.2 — PhysioNet](https://physionet.org/content/mimic-iv-demo/2.2/) — **Official** (PhysioNet)
- [CMS Synthetic Medicare dataset collection — data.cms.gov](https://data.cms.gov/collection/synthetic-medicare-enrollment-fee-for-service-claims-and-prescription-drug-event) — **Official** (CMS)
- [prostateredcap R package — stopsack.github.io](https://stopsack.github.io/prostateredcap/) — Semi-official (MSK researcher GitHub Pages)
- [hcv-target-sites — ctsit/hcv-target-sites GitHub](https://github.com/ctsit/hcv-target-sites) — Semi-official (University of Florida CTS-IT)
- [mCODE Test Data — HL7 Confluence](https://confluence.hl7.org/display/COD/mCODE+Test+Data) — **Official** (HL7)
- [Harvard Dataverse: 10K synthetic Medicare patients](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/QDXLWR) — Semi-official (academic repository)

---

## Core Concepts

### 1. REDCap Demo / Trial Instance

There is a public REDCap trial server at **http://redcapdemo.vumc.org/trial/** (Vanderbilt VUMC). Anyone can sign up with an email address. Key limitations confirmed from the official page:

- Trial accounts last **3 days** (not 7 — earlier search summaries said 7 days but the live page says 3).
- Projects created are **automatically deleted after 3 days**.
- The server is not monitored by administrative staff — entirely self-service.
- **No sample projects or pre-loaded datasets are included.** Users must build their own projects.
- One email can only be used once; to trial again, a new email is required.

The Vanderbilt Shared Library (the REDCap instrument library at projectredcap.org/resources/library/) requires an institutional REDCap login — it is not publicly accessible to anonymous users.

**Conclusion:** The trial server lets you experience REDCap's UI and build test instruments, but provides zero pre-loaded clinical data to export.

---

### 2. REDCap Shared Instrument Library

The official REDCap Shared Library is gated behind an institutional login. Instruments (data dictionaries / form definitions) are available, but not sample datasets with records. There is no path to downloading realistic CSV export data through this route without an institutional REDCap account.

---

### 3. GitHub Repositories with REDCap Sample Data

#### A. redcap-tools/redcap-test-datasets (Best verified option for CSV structure)
- URL: https://github.com/redcap-tools/redcap-test-datasets
- Maintained by the redcap-tools community organization.
- Contains 20 test cases (case-01 through case-20) plus an "archer" project.
- Each case includes: data dictionary CSV, metadata CSV, records CSV (UI and API formats), project information CSV.
- The **archer** subfolder is the most realistic — it contains `exported-csv.csv`, `data-dictionary.csv`, and `metadata.csv`. The archer records CSV has 24 columns including: `record_id`, `name_first`, `name_last`, `address`, `telephone`, `email`, `dob`, `age`, `sex`, `height`, `weight`, `bmi`, `comments`, `race___1` through `race___6`, `ethnicity`, plus completion flags. This is the closest thing to a realistic REDCap flat CSV with demographic/health fields.
- The **case-01** records CSV has 31 columns covering REDCap field types (dates, text, dropdowns, checkboxes, yes_no, etc.) with 100 randomly generated records — useful for testing field type handling but not clinically realistic.
- All files are directly downloadable from GitHub without any login.
- Raw URL pattern: `https://raw.githubusercontent.com/redcap-tools/redcap-test-datasets/master/archer/exported-csv.csv`

#### B. vickymuller-md/heartland-redcap-template (Best verified option for clinical realism)
- URL: https://github.com/vickymuller-md/heartland-redcap-template
- A heart failure registry template (HEARTLAND Protocol v3.3) for rural US hospitals.
- Files confirmed in the repo:
  - `instruments/heartland_data_dictionary.csv` — 75 fields across 5 clinical forms
  - `instruments/heartland_instrument.xml` — ODM-compatible REDCap XML
  - `examples/sample_data.csv` — 20 synthetic patients with 12-month follow-up data (no PHI)
  - `instruments/heartland_codebook.pdf`
- Confirmed column headers in `examples/sample_data.csv` (directly verified):
  `record_id, enr_date, consent_date, facility_name, facility_cah, facility_tier, state, county_fips, rural_urban, age, sex, race___5, ethnicity, bl_prior_hf_hosp_6mo, bl_lvef_pct, bl_lvef_category, bl_egfr, bl_np_type, bl_np_value, bl_sbp_admit, bl_diabetes, bl_ckm_stage, bl_distance_cardio_mi, bl_social_support_limited, bl_enrichd_score, bl_pro_consent, gdmt_arni_acei_arb_drug, gdmt_arni_acei_arb_dose, gdmt_arni_acei_arb_target, gdmt_arni_acei_arb_start, gdmt_bb_drug, gdmt_bb_dose, gdmt_bb_target, gdmt_bb_start, gdmt_mra_drug, gdmt_mra_dose, gdmt_mra_target, gdmt_mra_start, gdmt_sglt2_drug, gdmt_sglt2_dose, gdmt_sglt2_start, gdmt_hfpef_glp1, gdmt_generic_bridge, gdmt_init_tier, redcap_repeat_instrument, redcap_repeat_instance, mo_event_number, mo_date, mo_track, mo_weight_lb, mo_sbp, mo_dbp, mo_hr, mo_spo2, mo_egfr, mo_k, mo_bnp, mo_gdmt_change, mo_gdmt_change_notes, mo_red_flag_count, mo_hosp_any, mo_hosp_hf, mo_ed_any, mo_ed_hf, mo_kccq12_score, out_vital_status, out_death_date, out_death_cardiovascular, out_hf_hosp_count, out_hf_ed_count, out_days_alive_oh, out_gdmt_optimized, out_kccq12_12mo`
- Raw URL: `https://raw.githubusercontent.com/vickymuller-md/heartland-redcap-template/main/examples/sample_data.csv`
- This is the **most directly usable** verified REDCap export CSV with realistic clinical fields.

#### C. REDCapDM R package — COVICAN dataset
- URL: https://bruigtp.github.io/REDCapDM/articles/REDCapDM.html
- The CRAN package `REDCapDM` bundles a sample dataset from the COVICAN study (international oncology/COVID-19 cohort).
- Structure: 342 observations, 56 variables. Fields include: `record_id`, `d_birth`, `d_admission`, `age`, `dm` (diabetes), `copd`, `fio2`, `respiratory_rate`, `potassium`, `leuk_lymph`, `acute_leuk`, cancer-related fields, lab data.
- Access: `install.packages("REDCapDM"); library(REDCapDM); data(covican)`. No separate CSV download; the data is embedded in the R package on CRAN.
- The raw `.rda` files are in the GitHub package source at https://github.com/bruigtp/REDCapDM/tree/main/data but would need R to deserialise.

#### D. NACC UDSv4 REDCap XML (Instrument structure only — no sample records)
- URL: https://docs.naccdata.org/edc/data-capture-development/project-initiation/redcap-xml and https://www.naccdata.org/udsv4-resources-and-tools
- NACC (National Alzheimer's Coordinating Center) provides a full REDCap project XML for the Uniform Data Set v4 (Alzheimer's research).
- Contains complete instrument structure (forms, fields, logic, reports) but **no sample patient records**.
- Download appears to be on the NACC EDC File Downloads page. The docs.naccdata.org page is publicly accessible; the actual download link goes to an ADRC portal that may require registration.
- Useful for: constructing a realistic Alzheimer's registry schema in REDCap; would need synthetic data generated separately.

#### E. prostateredcap (MSK Prostate Cancer Registry package)
- URL: https://stopsack.github.io/prostateredcap/
- R package for loading/QC of the MSK IMPACT prostate cancer REDCap database.
- References a sample file `SampleGUPIMPACTDatab_DATA_LABELS_2021-05-26.csv` in the package GitHub for testing; the actual raw patient data from MSK is not public.
- The sample file is in the package repo at https://github.com/stopsack/prostateredcap but may be a small demonstration extract, not a full dataset.

---

### 4. Synthea

Synthea does **not** have a REDCap CSV export mode. Its native export formats are: FHIR R4 (JSON bundles), FHIR STU3, FHIR DSTU2, C-CDA, CPCDS, and a generic CSV.

**Synthea's CSV export is relational, not a REDCap flat export.** It produces 9+ separate files (`patients.csv`, `encounters.csv`, `conditions.csv`, `medications.csv`, `observations.csv`, `procedures.csv`, `allergies.csv`, `careplans.csv`, `immunizations.csv`) linked by patient UUID. This does not approximate a REDCap per-record flat CSV without ETL work.

**Pre-generated FHIR R4 datasets** are available at https://synthea.mitre.org/downloads (1,000-patient FHIR R4 bundles, downloadable free). These are directly relevant to the AWS HealthLake pipeline — see section 6 below.

**AWS HealthLake native Synthea support:** AWS HealthLake has a built-in "preloaded data" feature that accepts Synthea as a source type. When creating a HealthLake data store, Synthea FHIR R4 bundles can be preloaded directly. Supported resource types: AllergyIntolerance, CarePlan, CareTeam, Claim, Condition, Device, DiagnosticReport, Encounter, ExplanationOfBenefit, ImagingStudy, Immunization, Location, MedicationAdministration, MedicationRequest, Observation, Organization, Patient, Practitioner, PractitionerRole, Procedure, Provenance. (Source: AWS official docs.)

**Bridging Synthea to REDCap-style flat CSV:** No official tool exists for this. It would require custom ETL: pivot Synthea's `patients.csv` + `conditions.csv` + `observations.csv` etc. into one row per patient matching a target REDCap data dictionary.

---

### 5. Other Synthetic Clinical Datasets

#### MIMIC-IV Demo (PhysioNet)
- URL: https://physionet.org/content/mimic-iv-demo/2.2/
- 100 deidentified ICU patients from Beth Israel Deaconess Medical Center.
- **Freely downloadable without credentialing** under Open Data Commons Open Database License v1.0. Download is a 15.4 MB ZIP.
- Contains all 26 MIMIC-IV tables as CSV files (hospital + ICU modules): includes patients, admissions, diagnoses, labs, medications, vitals, procedures, etc.
- Format is relational (not a REDCap flat file) — requires pivot/ETL to create a per-patient flat CSV resembling a REDCap export.
- Useful as a source of realistic clinical values to populate a synthetic REDCap CSV.

#### CMS Synthetic Medicare Data (SynPUF / Synthetic RIF)
- URL: https://data.cms.gov/collection/synthetic-medicare-enrollment-fee-for-service-claims-and-prescription-drug-event
- Synthetic Medicare claims for 8,671 beneficiaries. Free download, CSV format, public domain.
- Contains enrollment, fee-for-service claims (inpatient, outpatient, carrier), and prescription drug events.
- US Medicare-specific structure (ICD codes, DRG, procedure codes, NPI). Not a REDCap format. Would require ETL to shape into REDCap-style flat CSV.

#### mCODE Synthea Test Data (Oncology)
- URL: https://confluence.hl7.org/display/COD/mCODE+Test+Data
- Synthea-generated cancer patients conforming to the mCODE FHIR Implementation Guide.
- Available as FHIR R4 bundles. Directly ingestible into AWS HealthLake.
- No REDCap CSV format.

#### Harvard Dataverse: 10,000 Synthetic Medicare Patients
- URL: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/QDXLWR
- Synthea-generated data modelling Medicare beneficiaries across the US. Free academic download.

---

### 6. REDCap API Token Approach (for institutions that already have REDCap)

For users with institutional REDCap access, the standard approach to getting a demo project with sample data is:
1. Import an existing project XML (e.g., the NACC UDSv4 XML, or the HEARTLAND XML) into your institution's REDCap instance.
2. Use REDCap's built-in Data Import Tool to upload a CSV of synthetic records.
3. Export as CSV (raw or labelled), then use that as test data for pipeline development.

The REDCap API (using an API token) can also export records programmatically in CSV format — this is what packages like `REDCapR` (R) and `PyCap` (Python) wrap. The `redcap-tools/redcap-test-datasets` repo was built specifically to support API library testing.

---

## Code Snippets

```python
# Directly download the HEARTLAND sample_data.csv (verified working, no auth required)
import urllib.request
url = "https://raw.githubusercontent.com/vickymuller-md/heartland-redcap-template/main/examples/sample_data.csv"
urllib.request.urlretrieve(url, "heartland_sample_data.csv")
```

```python
# Directly download the archer REDCap export CSV (demographic/health fields, no auth required)
import urllib.request
url = "https://raw.githubusercontent.com/redcap-tools/redcap-test-datasets/master/archer/exported-csv.csv"
urllib.request.urlretrieve(url, "archer_exported.csv")
```

```python
# Download MIMIC-IV Demo (free, no credentials required)
# Full download via PhysioNet wget command shown on the page, or:
import urllib.request
# ZIP download (15.4 MB)
url = "https://physionet.org/static/published-projects/mimic-iv-demo/mimic-iv-clinical-database-demo-2.2.zip"
# Note: verify exact URL on the PhysioNet page as it may redirect
```

```r
# Access COVICAN dataset (bundled in REDCapDM CRAN package)
install.packages("REDCapDM")
library(REDCapDM)
data(covican)
# covican is a list with: $data (342 obs, 56 vars), $dictionary (21 obs), $event_form (9 obs)
write.csv(covican$data, "covican_redcap_export.csv", row.names = FALSE)
```

---

## Gotchas & Warnings

**REDCap demo server is 3 days, not 7.**
The live page at redcapdemo.vumc.org/trial confirms 3 days. Some older documentation and community summaries incorrectly say 7 days.

**REDCap Shared Library requires institutional login.**
There is no anonymous/public path to browse or download instruments from the library at projectredcap.org/resources/library/. A trial account does not grant access to the library.

**Synthea CSV is relational, not flat.**
Synthea's CSV exporter produces 9+ files with one row per clinical event, linked by UUID. It is not a REDCap flat CSV (one row per patient). Transforming it requires non-trivial ETL.

**AWS HealthLake accepts Synthea FHIR R4 bundles natively.**
This is a better path than trying to make Synthea produce REDCap-style CSVs. Download from synthea.mitre.org/downloads and ingest directly into HealthLake during data store creation.

**NACC UDSv4 XML provides instrument structure only — no records.**
It is the gold standard for Alzheimer's registry form design in REDCap, but you still need to generate or supply synthetic patient records.

**HEARTLAND sample_data.csv has synthetic county_fips.**
The repo explicitly notes: "county_fips values in examples/sample_data.csv are synthetic placeholders generated for demonstration, not real ANSI/FIPS county codes."

**MIMIC-IV Demo is relational, not a REDCap flat file.**
The 26 CSV tables use patient/admission/ICU stay ID as foreign keys. Useful as a source of realistic clinical values, but requires pivot ETL to produce a single-row-per-patient REDCap-style export.

> **[TENTATIVE — unofficial source]** The prostateredcap package references a file `SampleGUPIMPACTDatab_DATA_LABELS_2021-05-26.csv` for testing; it is not clear from the documentation whether this file is publicly committed to the GitHub repo or restricted. Source: stopsack.github.io/prostateredcap (Semi-official, researcher GitHub Pages). Verify directly at https://github.com/stopsack/prostateredcap before relying on it.
