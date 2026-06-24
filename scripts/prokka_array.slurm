#!/bin/bash
#SBATCH --job-name=prokka_array
#SBATCH --output=logs/prokka_%A_%a.out
#SBATCH --error=logs/prokka_%A_%a.err
#SBATCH --array=1-116
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --partition=normal
# =============================================================================
# prokka_array.slurm
# Re-annotate all genomes with Prokka using Slurm array jobs
#
# Usage:
#   sbatch prokka_array.slurm
#
# Before submitting:
#   1. Edit WORKDIR to your HPC working directory
#   2. Edit --array=1-N to match your genome count (wc -l genome_list.txt)
#   3. Edit --partition to your HPC partition name (check: sinfo)
#   4. Choose module load or conda activate below
# =============================================================================

# ── Load Prokka (choose ONE method) ──────────────────────────────────────────
module load Prokka/1.12
# source activate deino                   # uncomment if using conda instead

# ── Edit paths ────────────────────────────────────────────────────────────────
WORKDIR=/path/to/your/deino              # <-- CHANGE THIS
GENOME_LIST=$WORKDIR/genome_list.txt
OUTDIR=$WORKDIR/prokka_out
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$OUTDIR"
mkdir -p "$WORKDIR/logs"

# Get this task's genome path from list
FASTA=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$GENOME_LIST")
STRAIN=$(basename $(dirname "$FASTA"))

echo "========================================"
echo "Task ID   : $SLURM_ARRAY_TASK_ID"
echo "Strain    : $STRAIN"
echo "FASTA     : $FASTA"
echo "Started   : $(date)"
echo "========================================"

prokka "$FASTA" \
    --outdir "$OUTDIR/$STRAIN" \
    --prefix "$STRAIN" \
    --kingdom Bacteria \
    --cpus $SLURM_CPUS_PER_TASK \
    --force \
    --quiet

EXIT_CODE=$?
echo "Exit code : $EXIT_CODE"
echo "Finished  : $(date)"

if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Prokka failed for $STRAIN" >&2
    exit 1
fi
