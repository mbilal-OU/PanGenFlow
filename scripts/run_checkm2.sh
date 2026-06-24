#!/bin/bash
# =============================================================================
# run_checkm2.sh
# Run CheckM2 genome quality assessment and filter by completeness/contamination
#
# Usage:
#   bash run_checkm2.sh <genome_list.txt> <output_dir> <db_path>
#
# Example:
#   bash run_checkm2.sh genome_list.txt checkm2_results/ ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd
#
# Requirements:
#   conda activate checkm2
#   checkm2 database --download --path ~/checkm2_db/
# =============================================================================

set -euo pipefail

GENOME_LIST=${1:-"genome_list.txt"}
OUTDIR=${2:-"checkm2_results"}
DB_PATH=${3:-"$HOME/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd"}
THREADS=${4:-8}
MIN_COMPLETENESS=${5:-90}
MAX_CONTAMINATION=${6:-5}

echo "========================================"
echo "CheckM2 Genome Quality Assessment"
echo "Genome list      : $GENOME_LIST"
echo "Output dir       : $OUTDIR"
echo "Database         : $DB_PATH"
echo "Threads          : $THREADS"
echo "Min completeness : ${MIN_COMPLETENESS}%"
echo "Max contamination: ${MAX_CONTAMINATION}%"
echo "Started          : $(date)"
echo "========================================"

# Stage genomes into one flat directory
GENOME_DIR="${OUTDIR}/input_genomes"
mkdir -p "$GENOME_DIR"

echo "Copying genomes to staging directory..."
while read path; do
    cp "$path" "$GENOME_DIR/"
done < "$GENOME_LIST"

GENOME_COUNT=$(ls "$GENOME_DIR"/*.fna | wc -l)
echo "Genomes staged: $GENOME_COUNT"

# Run CheckM2
echo ""
echo "Running CheckM2..."
checkm2 predict \
    --input "$GENOME_DIR/" \
    --output-directory "$OUTDIR/" \
    --database_path "$DB_PATH" \
    --threads "$THREADS" \
    --extension fna

echo "CheckM2 complete: $(date)"

# Filter results and generate clean genome list
echo ""
echo "Filtering genomes by quality thresholds..."

python3 << PYEOF
import pandas as pd
import sys

report = "${OUTDIR}/quality_report.tsv"
genome_list = "${GENOME_LIST}"
outdir = "${OUTDIR}"
min_comp = ${MIN_COMPLETENESS}
max_cont = ${MAX_CONTAMINATION}

# Load report
df = pd.read_csv(report, sep="\t")
print(f"\nTotal genomes assessed: {len(df)}")

# Apply filters
passed = df[
    (df["Completeness"] >= min_comp) &
    (df["Contamination"] <= max_cont)
]
failed = df[~(
    (df["Completeness"] >= min_comp) &
    (df["Contamination"] <= max_cont)
)]

print(f"Passed QC (completeness >={min_comp}%, contamination <={max_cont}%): {len(passed)}")
print(f"Failed QC: {len(failed)}")

if len(failed) > 0:
    print("\nFailed genomes:")
    for _, row in failed.iterrows():
        print(f"  {row['Name']}: completeness={row['Completeness']:.1f}%, contamination={row['Contamination']:.1f}%")

# Summary stats
print(f"\nQuality Summary:")
print(f"  Mean completeness  : {df['Completeness'].mean():.2f}%")
print(f"  Mean contamination : {df['Contamination'].mean():.2f}%")
print(f"  Min completeness   : {df['Completeness'].min():.2f}%")
print(f"  Max contamination  : {df['Contamination'].max():.2f}%")

# Save clean genome list
# Match genome names back to original paths
with open(genome_list) as f:
    all_paths = [l.strip() for l in f if l.strip()]

passed_names = set(passed["Name"].tolist())

clean_paths = []
for path in all_paths:
    # genome name = filename without extension
    name = path.split("/")[-1].replace(".fna","")
    # also try folder name
    folder = path.split("/")[-2]
    if name in passed_names or folder in passed_names:
        clean_paths.append(path)

with open(f"{outdir}/genome_list_qc_passed.txt", "w") as out:
    for p in clean_paths:
        out.write(p + "\n")

print(f"\nClean genome list saved: {outdir}/genome_list_qc_passed.txt")
print(f"Final genome count: {len(clean_paths)}")

# Save failed list
with open(f"{outdir}/genome_list_qc_failed.txt", "w") as out:
    for p in all_paths:
        name = p.split("/")[-1].replace(".fna","")
        folder = p.split("/")[-2]
        if name not in passed_names and folder not in passed_names:
            out.write(p + "\n")

PYEOF

echo ""
echo "========================================"
echo "All done: $(date)"
echo "Report   : ${OUTDIR}/quality_report.tsv"
echo "Passed   : ${OUTDIR}/genome_list_qc_passed.txt"
echo "Failed   : ${OUTDIR}/genome_list_qc_failed.txt"
echo "========================================"
