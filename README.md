# River Rats Sailing — Report Tools

Perl scripts for generating attendance sheets and summary reports for the
[River Rats Sailing Club](https://www.riverratssailing.org) junior sailing program.
Also includes a separate tool for the kayak rack registration report.

## Repository Layout

```
junior-sailing/
  gen-all.pl          — Master report generator; loops over all sessions
  gen-attendance.pl   — Per-session attendance sheet + sailing level counts
  mk-sessions         — Creates the Session-1..7 data directories for a year
  mv-data             — Moves downloaded CSVs into a session directory
  mv-reports          — Moves downloaded report files into a session directory
  zip-it              — Packages session outputs into classes.zip
  test/
    run-tests.sh      — Regression test against synthetic golden data
    data/             — Synthetic input CSVs (safe to commit; no real data)
    golden/           — Reference outputs for regression testing

kayak/
  gen-kayak-report.pl — Generates Kayak-racks.csv from additional charges data
```

Input data and generated output live **outside** the repo, one subdirectory per session:

```
~/Documents/Data/RiverRats/<year>/
  Session-1/ .. Session-7/
    registration_data.csv     — exported from website
    registrant_data.csv       — exported from website
    Attendance <title>.csv    — generated
    Attendance.txt            — generated
    sailing-level-counts.csv  — generated
  TShirts.csv                 — generated (all sessions combined)
  TShirt-counts.csv           — generated
  sailing-level-counts.csv    — generated (all sessions combined)
  student-counts.csv          — generated
  student-list.csv            — generated
```

## Prerequisites

- Perl 5.10+
- `Text::ParseWords` (usually included with Perl; otherwise `cpan Text::ParseWords`)

## Junior Sailing Workflow

### 1. Set up directories for a new year

```bash
junior-sailing/mk-sessions <year>
```

Creates `~/Documents/Data/RiverRats/<year>/Session-{1..7}`.

### 2. Export and move data for each session

For each session, export from the club website (see [Exporting Data](#exporting-data) below),
then move the files into place:

```bash
junior-sailing/mv-data ~/Documents/Data/RiverRats/<year>/Session-<n>
```

### 3. Generate all reports

```bash
junior-sailing/gen-all.pl --data-dir ~/Documents/Data/RiverRats/<year>
```

This runs `gen-attendance.pl` in each session directory and produces the combined
summary files (`TShirts.csv`, `sailing-level-counts.csv`, `student-counts.csv`, `student-list.csv`).

### 4. Run the regression test

```bash
junior-sailing/test/run-tests.sh
```

Compares output against the golden files. Launches `meld` (or `opendiff` on macOS)
if differences are found.

If you've intentionally changed the output format, update the golden files with:

```bash
junior-sailing/test/run-tests.sh --update-golden
```

## Kayak Rack Report

Download **Additional Charges** and **Additional Member Data** from the club control panel,
save them as `Additional-Charges.csv` and `Additional-Data.csv`, then run:

```bash
kayak/gen-kayak-report.pl
```

Produces `Kayak-racks.csv`. Run with `--help` for download instructions.

## Exporting Data from the Website

For each session:

1. Log in to the website and select the **Events** tab.
2. Click the pencil icon for the session.
3. Click the calendar-like export icon in the admin panel (top right).
4. Export **Registration Data** — save as `registration_data.csv`.
5. Repeat, exporting **Registrant Data** — save as `registrant_data.csv`.
6. In **Status**, check **Paid** (and **Open** if needed), then click **Export**.
