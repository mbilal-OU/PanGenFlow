#!/bin/bash
# =============================================================================
# batch_download.sh
# Download complete genomes for multiple taxa from NCBI
# Usage: bash batch_download.sh
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
OUTDIR="genomes_by_genus"
ASSEMBLY_LEVEL="complete"
ASSEMBLY_SOURCE="RefSeq"
INCLUDE="genome,gff3,gbff,seq-report"
THREADS=8

# ── Taxa to download ──────────────────────────────────────────────────────────
TAXA=(
    "Deinococcus"
    "Thermus"
    "Meiothermus"
    "Marinithermus"
    "Oceanithermus"
    "Vulcanithermus"
    "Rhabdothermus"
    "Truepera"
)

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$OUTDIR"
LOG="$OUTDIR/download_log.txt"
echo "Download started: $(date)" | tee "$LOG"

# ── Download loop ─────────────────────────────────────────────────────────────
for taxon in "${TAXA[@]}"; do
    safe=$(echo "$taxon" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    zip_file="${OUTDIR}/${safe}.zip"
    genome_dir="${OUTDIR}/${safe}"

    echo "" | tee -a "$LOG"
    echo "=== $taxon ===" | tee -a "$LOG"
    echo "Started: $(date)" | tee -a "$LOG"

    datasets download genome taxon "$taxon" \
        --assembly-level "$ASSEMBLY_LEVEL" \
        --assembly-source "$ASSEMBLY_SOURCE" \
        --exclude-atypical \
        --include "$INCLUDE" \
        --filename "$zip_file"

    mkdir -p "$genome_dir"
    unzip -q "$zip_file" -d "$genome_dir/"

    count=$(find "$genome_dir/" -name "*.fna" | wc -l)
    echo "Genomes downloaded: $count" | tee -a "$LOG"

    # Build genome list for this taxon
    find "$genome_dir/ncbi_dataset/data/" \
        -name "*.fna" -path "*/GCF_*" \
        > "${OUTDIR}/${safe}_genome_list.txt"

    gcf_count=$(wc -l < "${OUTDIR}/${safe}_genome_list.txt")
    echo "GCF genomes: $gcf_count" | tee -a "$LOG"
done

# ── Combine all genome lists ──────────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "=== Combining all genome lists ===" | tee -a "$LOG"

cat "${OUTDIR}"/*_genome_list.txt > "${OUTDIR}/all_genomes_list.txt"
total=$(wc -l < "${OUTDIR}/all_genomes_list.txt")
echo "Total genomes across all taxa: $total" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "Download complete: $(date)" | tee -a "$LOG"
echo "All genome paths saved to: ${OUTDIR}/all_genomes_list.txt"
