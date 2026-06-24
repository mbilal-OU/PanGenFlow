#!/bin/bash
#SBATCH --job-name=antismash_array
#SBATCH --output=logs/antismash_%A_%a.out
#SBATCH --error=logs/antismash_%A_%a.err
#SBATCH --array=1-116
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --partition=normal

source activate antismash

WORKDIR=/path/to/your/deino
GENOME_LIST=$WORKDIR/genome_list.txt
OUTDIR=$WORKDIR/antismash_out

mkdir -p "$OUTDIR"
mkdir -p "$WORKDIR/logs"

FASTA=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$GENOME_LIST")
STRAIN=$(basename $(dirname "$FASTA"))

echo "Task: $SLURM_ARRAY_TASK_ID | Strain: $STRAIN | Started: $(date)"

antismash "$FASTA" \
    --taxon bacteria \
    --output-dir "$OUTDIR/$STRAIN" \
    --genefinding-tool none \
    --cb-general \
    --cb-knownclusters \
    --cb-subclusters \
    --asf \
    --pfam2go \
    --smcog-trees \
    --cpus $SLURM_CPUS_PER_TASK

echo "Finished: $STRAIN at $(date)"
