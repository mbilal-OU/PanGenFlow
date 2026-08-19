#!/usr/bin/env bash
# Run CheckM2 and create QC-passed / QC-failed genome lists.
# Genomes are staged as symlinks rather than copied, avoiding duplicate disk use.

set -euo pipefail

GENOME_LIST=${1:-"genome_list_clean.txt"}
OUTDIR=${2:-"checkm2_results"}
DB_PATH=${3:-"${CHECKM2DB:-}"}
THREADS=${4:-8}
MIN_COMPLETENESS=${5:-90}
MAX_CONTAMINATION=${6:-5}

if [[ ! -f "$GENOME_LIST" ]]; then
    echo "ERROR: genome list not found: $GENOME_LIST" >&2
    exit 1
fi
if ! command -v checkm2 >/dev/null 2>&1; then
    echo "ERROR: checkm2 is not available in PATH" >&2
    exit 127
fi
if [[ -z "$DB_PATH" ]]; then
    echo "ERROR: provide the CheckM2 database path as argument 3 or set CHECKM2DB" >&2
    exit 2
fi
if [[ -e "$OUTDIR/quality_report.tsv" ]]; then
    echo "ERROR: $OUTDIR/quality_report.tsv already exists; choose a new output directory or remove the old run" >&2
    exit 2
fi

STAGE_DIR="${OUTDIR%/}.input_genomes"
MAPPING_TMP=$(mktemp)
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
trap 'rm -f "$MAPPING_TMP"' EXIT

python3 - "$GENOME_LIST" "$STAGE_DIR" "$MAPPING_TMP" <<'PYEOF'
from pathlib import Path
import re
import sys

list_file = Path(sys.argv[1])
stage_dir = Path(sys.argv[2])
mapping_file = Path(sys.argv[3])
accession_re = re.compile(r"GC[AF]_\d+\.\d+")
used = set()
rows = []

for raw in list_file.read_text().splitlines():
    raw = raw.strip()
    if not raw:
        continue
    src = Path(raw).expanduser().resolve()
    if not src.is_file():
        raise SystemExit(f"Genome file not found: {src}")
    if src.name.endswith(".gz"):
        raise SystemExit(f"Compressed genome detected: {src}. Rehydrate without --gzip or decompress before CheckM2 staging.")

    accession = next((p for p in reversed(src.parts) if accession_re.fullmatch(p)), None)
    stem = accession or src.stem.replace("_genomic", "")
    label = stem
    counter = 2
    while label in used:
        label = f"{stem}_{counter}"
        counter += 1
    used.add(label)

    target = stage_dir / f"{label}.fna"
    target.symlink_to(src)
    rows.append((label, str(src)))

with mapping_file.open("w", encoding="utf-8") as out:
    out.write("Name\toriginal_path\n")
    for label, src in rows:
        out.write(f"{label}\t{src}\n")

print(f"Staged {len(rows)} genome symlinks")
PYEOF

GENOME_COUNT=$(find "$STAGE_DIR" -maxdepth 1 -type l -name '*.fna' | wc -l)
if (( GENOME_COUNT == 0 )); then
    echo "ERROR: no genomes were staged" >&2
    exit 1
fi

checkm2 predict \
    --input "$STAGE_DIR" \
    --output-directory "$OUTDIR" \
    --database_path "$DB_PATH" \
    --threads "$THREADS" \
    --extension fna

cp "$MAPPING_TMP" "$OUTDIR/input_mapping.tsv"

python3 - "$OUTDIR/quality_report.tsv" "$OUTDIR/input_mapping.tsv" "$OUTDIR" "$MIN_COMPLETENESS" "$MAX_CONTAMINATION" <<'PYEOF'
from pathlib import Path
import sys
import pandas as pd

report_path = Path(sys.argv[1])
mapping_path = Path(sys.argv[2])
outdir = Path(sys.argv[3])
min_comp = float(sys.argv[4])
max_cont = float(sys.argv[5])

report = pd.read_csv(report_path, sep="\t")
mapping = pd.read_csv(mapping_path, sep="\t")
required = {"Name", "Completeness", "Contamination"}
missing = required - set(report.columns)
if missing:
    raise SystemExit(f"CheckM2 report is missing required columns: {sorted(missing)}")

report["Name"] = report["Name"].astype(str).str.replace(r"\.fna$", "", regex=True)
merged = mapping.merge(report, on="Name", how="left", validate="one_to_one")
if merged["Completeness"].isna().any():
    absent = merged.loc[merged["Completeness"].isna(), "Name"].tolist()
    raise SystemExit(f"No CheckM2 result matched staged genome(s): {absent[:10]}")

passed_mask = (merged["Completeness"] >= min_comp) & (merged["Contamination"] <= max_cont)
passed = merged.loc[passed_mask].copy()
failed = merged.loc[~passed_mask].copy()

passed["original_path"].to_csv(outdir / "genome_list_qc_passed.txt", index=False, header=False)
failed["original_path"].to_csv(outdir / "genome_list_qc_failed.txt", index=False, header=False)
merged.to_csv(outdir / "quality_report_with_paths.tsv", sep="\t", index=False)

print(f"Total genomes assessed : {len(merged)}")
print(f"Passed QC              : {len(passed)}")
print(f"Failed QC              : {len(failed)}")
print(f"Mean completeness      : {merged['Completeness'].mean():.2f}%")
print(f"Mean contamination     : {merged['Contamination'].mean():.2f}%")
PYEOF

rm -rf "$STAGE_DIR"

echo "Passed list: ${OUTDIR}/genome_list_qc_passed.txt"
echo "Failed list: ${OUTDIR}/genome_list_qc_failed.txt"
echo "Report     : ${OUTDIR}/quality_report_with_paths.tsv"
