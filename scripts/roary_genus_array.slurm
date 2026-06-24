#!/bin/bash
#SBATCH --job-name=roary_genus
#SBATCH --output=logs/roary_%A_%a.out
#SBATCH --error=logs/roary_%A_%a.err
#SBATCH --array=1-8
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --partition=normal
# =============================================================================
# roary_genus_array.slurm
# Run Roary pangenome analysis per genus using Slurm array jobs
#
# Requires:
#   genus_list.txt       — one genus name per line (matches folder names)
#   gff_by_genus/        — folder containing one subfolder per genus with GFFs
#
# genus_list.txt example:
#   Deinococcus
#   Thermus
#   Meiothermus
#   Marinithermus
#   Oceanithermus
#   Vulcanithermus
#   Rhabdothermus
#   Truepera
#
# gff_by_genus/ structure:
#   gff_by_genus/
#   ├── Deinococcus/
#   │   ├── GCF_000008565.1.gff
#   │   ├── GCF_000020685.1.gff
#   │   └── ...
#   ├── Thermus/
#   │   ├── GCF_000008125.1.gff
#   │   └── ...
#   └── ...
#
# Usage:
#   sbatch roary_genus_array.slurm
# =============================================================================

module load Roary/3.13.0

# ── Edit paths ────────────────────────────────────────────────────────────────
WORKDIR=/path/to/your/deino              # <-- CHANGE THIS
GENUS_LIST=$WORKDIR/genus_list.txt
GFF_DIR=$WORKDIR/gff_by_genus
OUTDIR=$WORKDIR/roary_results
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$OUTDIR"
mkdir -p "$WORKDIR/logs"

# Get genus for this task
GENUS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$GENUS_LIST")
GENUS_GFF_DIR="$GFF_DIR/$GENUS"
GENUS_OUTDIR="$OUTDIR/$GENUS"

echo "========================================"
echo "Task ID   : $SLURM_ARRAY_TASK_ID"
echo "Genus     : $GENUS"
echo "GFF dir   : $GENUS_GFF_DIR"
echo "Output    : $GENUS_OUTDIR"
echo "Started   : $(date)"
echo "========================================"

# Count GFFs
GFF_COUNT=$(ls "$GENUS_GFF_DIR"/*.gff 2>/dev/null | wc -l)
echo "GFF files : $GFF_COUNT"

if [ "$GFF_COUNT" -lt 2 ]; then
    echo "WARNING: Less than 2 GFF files for $GENUS — skipping pangenome"
    exit 0
fi

mkdir -p "$GENUS_OUTDIR"

# Run Roary
roary \
    -e \
    -n \
    -v \
    -r \
    -i 95 \
    -cd 99 \
    -p $SLURM_CPUS_PER_TASK \
    -f "$GENUS_OUTDIR" \
    "$GENUS_GFF_DIR"/*.gff

EXIT_CODE=$?
echo "Exit code : $EXIT_CODE"
echo "Finished  : $(date)"

if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Roary failed for $GENUS" >&2
    exit 1
fi

# Quick summary
echo ""
echo "=== Pangenome Summary: $GENUS ==="
if [ -f "$GENUS_OUTDIR/summary_statistics.txt" ]; then
    cat "$GENUS_OUTDIR/summary_statistics.txt"
fi
