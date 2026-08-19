#!/usr/bin/env bash
# Download a filtered NCBI genome data package for one taxon or taxid.
# Minimal usage:
#   bash batch_download.sh "Deinococcota" genomes/

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  batch_download.sh <taxon-or-taxid> <output-directory> [options]

Options:
  --source <RefSeq|GenBank|all>   Assembly source (default: RefSeq)
  --level <levels>                Assembly level(s), comma-separated (default: complete)
  --include <files>               NCBI data files (default: genome,gff3,gbff,seq-report)
  --dehydrated                    Use dehydrated package + rehydrate for large downloads
  --workers <1-30>                Rehydration workers (default: 8)
  --keep-zip                      Keep the downloaded zip archive
  -h, --help                      Show this help

Examples:
  batch_download.sh "Deinococcus" deinococcus_genomes/
  batch_download.sh 188787 deinococcota_genomes/ --dehydrated --workers 12
  batch_download.sh "Bacillus" bacillus_genomes/ --source all --level complete,chromosome
USAGE
}

if [[ $# -lt 2 ]]; then
    usage >&2
    exit 2
fi

TAXON="$1"
OUTDIR="$2"
shift 2

ASSEMBLY_SOURCE="RefSeq"
ASSEMBLY_LEVEL="complete"
INCLUDE="genome,gff3,gbff,seq-report"
DEHYDRATED=0
WORKERS=8
KEEP_ZIP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            ASSEMBLY_SOURCE="${2:?missing value for --source}"
            shift 2
            ;;
        --level)
            ASSEMBLY_LEVEL="${2:?missing value for --level}"
            shift 2
            ;;
        --include)
            INCLUDE="${2:?missing value for --include}"
            shift 2
            ;;
        --dehydrated)
            DEHYDRATED=1
            shift
            ;;
        --workers)
            WORKERS="${2:?missing value for --workers}"
            shift 2
            ;;
        --keep-zip)
            KEEP_ZIP=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$ASSEMBLY_SOURCE" in
    RefSeq|GenBank|all) ;;
    *)
        echo "ERROR: --source must be RefSeq, GenBank, or all" >&2
        exit 2
        ;;
esac

if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || (( WORKERS < 1 || WORKERS > 30 )); then
    echo "ERROR: --workers must be an integer from 1 to 30" >&2
    exit 2
fi

for cmd in datasets unzip find; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 127
    fi
done

mkdir -p "$OUTDIR"
ZIP_FILE="${OUTDIR%/}/ncbi_dataset.zip"
LOG_FILE="${OUTDIR%/}/pangenflow_download.log"

{
    echo "PanGenFlow download"
    echo "Taxon             : $TAXON"
    echo "Output directory  : $OUTDIR"
    echo "Assembly source   : $ASSEMBLY_SOURCE"
    echo "Assembly level    : $ASSEMBLY_LEVEL"
    echo "Included files    : $INCLUDE"
    echo "Dehydrated mode   : $DEHYDRATED"
    echo "Started           : $(date -Is 2>/dev/null || date)"
} | tee "$LOG_FILE"

DOWNLOAD_CMD=(
    datasets download genome taxon "$TAXON"
    --assembly-level "$ASSEMBLY_LEVEL"
    --assembly-source "$ASSEMBLY_SOURCE"
    --exclude-atypical
    --include "$INCLUDE"
    --filename "$ZIP_FILE"
)

if (( DEHYDRATED == 1 )); then
    DOWNLOAD_CMD+=(--dehydrated)
fi

"${DOWNLOAD_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"
unzip -oq "$ZIP_FILE" -d "$OUTDIR"

if (( DEHYDRATED == 1 )); then
    datasets rehydrate --directory "$OUTDIR" --max-workers "$WORKERS" 2>&1 | tee -a "$LOG_FILE"
fi

DATA_DIR="${OUTDIR%/}/ncbi_dataset/data"
REPORT="${DATA_DIR}/assembly_data_report.jsonl"
GENOME_LIST="${OUTDIR%/}/genome_list_downloaded.txt"

if [[ ! -d "$DATA_DIR" ]]; then
    echo "ERROR: expected NCBI data directory not found: $DATA_DIR" >&2
    exit 1
fi

find "$DATA_DIR" -type f \( -name '*.fna' -o -name '*.fna.gz' \) | sort > "$GENOME_LIST"
GENOME_COUNT=$(grep -cve '^$' "$GENOME_LIST" || true)

{
    echo "Genome FASTA files : $GENOME_COUNT"
    echo "Genome list        : $GENOME_LIST"
    if [[ -f "$REPORT" ]]; then
        echo "Assembly report    : $REPORT"
    fi
    echo "Finished           : $(date -Is 2>/dev/null || date)"
} | tee -a "$LOG_FILE"

if (( KEEP_ZIP == 0 )); then
    rm -f "$ZIP_FILE"
fi

if (( GENOME_COUNT == 0 )); then
    echo "WARNING: no genome FASTA files were found in the downloaded package" >&2
fi
