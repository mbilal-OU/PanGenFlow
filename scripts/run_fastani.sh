#!/usr/bin/env bash
# Optional FastANI relatedness check for sufficiently similar genome sets.
# FastANI generally does not report pairs that are much below ~80% ANI; missing
# comparisons are therefore preserved as missing rather than assigned a value.

set -euo pipefail

GENOME_LIST=${1:-"genome_list_qc_passed.txt"}
OUTDIR=${2:-"fastani_results"}
THREADS=${3:-8}

if [[ ! -f "$GENOME_LIST" ]]; then
    echo "ERROR: genome list not found: $GENOME_LIST" >&2
    exit 1
fi
for cmd in fastANI python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 127
    fi
done

mkdir -p "$OUTDIR" "$OUTDIR/figures"
GENOME_COUNT=$(grep -cve '^$' "$GENOME_LIST" || true)
if (( GENOME_COUNT < 2 )); then
    echo "ERROR: FastANI requires at least two genomes" >&2
    exit 2
fi

RAW="${OUTDIR}/fastani_results.tsv"

fastANI \
    --ql "$GENOME_LIST" \
    --rl "$GENOME_LIST" \
    --output "$RAW" \
    --threads "$THREADS"

python3 - "$GENOME_LIST" "$RAW" "$OUTDIR" <<'PYEOF'
from pathlib import Path
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

list_file = Path(sys.argv[1])
results_file = Path(sys.argv[2])
outdir = Path(sys.argv[3])
paths = [Path(x.strip()) for x in list_file.read_text().splitlines() if x.strip()]


def genome_label(path: Path) -> str:
    parent = path.parent.name
    if parent.startswith(("GCA_", "GCF_")):
        return parent
    name = path.name
    for suffix in (".fna.gz", ".fasta.gz", ".fa.gz", ".fna", ".fasta", ".fa"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    return name.replace("_genomic", "")

labels = [genome_label(p) for p in paths]
if len(labels) != len(set(labels)):
    raise SystemExit("Genome labels are not unique; rename inputs or use accession-named folders")

matrix = pd.DataFrame(np.nan, index=labels, columns=labels, dtype=float)
np.fill_diagonal(matrix.values, 100.0)

if results_file.exists() and results_file.stat().st_size > 0:
    df = pd.read_csv(results_file, sep="\t", header=None,
                     names=["query", "reference", "ani", "fragments_mapped", "total_query_fragments"])
    df["query_label"] = df["query"].map(lambda x: genome_label(Path(x)))
    df["reference_label"] = df["reference"].map(lambda x: genome_label(Path(x)))
    df["alignment_fraction"] = df["fragments_mapped"] / df["total_query_fragments"].replace(0, np.nan)
    df.to_csv(outdir / "fastani_pairs.tsv", sep="\t", index=False)
    for row in df.itertuples(index=False):
        if row.query_label in matrix.index and row.reference_label in matrix.columns:
            matrix.loc[row.query_label, row.reference_label] = float(row.ani)
else:
    df = pd.DataFrame()

for i, a in enumerate(labels):
    for b in labels[i + 1:]:
        ab = matrix.loc[a, b]
        ba = matrix.loc[b, a]
        observed = [x for x in (ab, ba) if pd.notna(x)]
        if observed:
            value = float(np.mean(observed))
            matrix.loc[a, b] = value
            matrix.loc[b, a] = value

matrix.to_csv(outdir / "ani_matrix.tsv", sep="\t", na_rep="NA")
off_diag = matrix.values.copy()
np.fill_diagonal(off_diag, np.nan)
observed = off_diag[~np.isnan(off_diag)]
total_directed = len(labels) * (len(labels) - 1)
reported_directed = int(np.count_nonzero(~np.isnan(off_diag)))
missing_directed = total_directed - reported_directed

summary = {
    "genomes": len(labels),
    "reported_directed_pairs": reported_directed,
    "missing_directed_pairs": missing_directed,
    "reported_fraction": reported_directed / total_directed if total_directed else np.nan,
    "minimum_reported_ani": float(np.min(observed)) if observed.size else np.nan,
    "maximum_reported_ani": float(np.max(observed)) if observed.size else np.nan,
    "mean_reported_ani": float(np.mean(observed)) if observed.size else np.nan,
    "median_reported_ani": float(np.median(observed)) if observed.size else np.nan,
}
pd.DataFrame([summary]).to_csv(outdir / "ani_summary.tsv", sep="\t", index=False)

fig_side = max(8, min(24, 0.22 * len(labels) + 6))
fig, ax = plt.subplots(figsize=(fig_side, fig_side))
sns.heatmap(matrix, mask=matrix.isna(), cmap="viridis", vmin=80, vmax=100,
            square=True, xticklabels=True, yticklabels=True,
            cbar_kws={"label": "ANI (%)"}, ax=ax)
ax.set_title(
    f"FastANI pairwise relatedness (n={len(labels)})\n"
    "Missing cells were not reported by FastANI; they are not assigned an ANI value"
)
ax.tick_params(axis="x", labelrotation=90, labelsize=max(4, 9 - len(labels) / 30))
ax.tick_params(axis="y", labelrotation=0, labelsize=max(4, 9 - len(labels) / 30))
plt.tight_layout()
fig.savefig(outdir / "figures" / "ANI_heatmap.png", dpi=300)
fig.savefig(outdir / "figures" / "ANI_heatmap.pdf")
plt.close(fig)

print(f"Reported pair fraction: {summary['reported_fraction']:.3f}")
if missing_directed:
    print(f"NOTE: {missing_directed} directed pair(s) were not reported; missing output is not a specific ANI value.")
PYEOF

echo "Results: ${OUTDIR}/fastani_pairs.tsv"
echo "Matrix : ${OUTDIR}/ani_matrix.tsv"
echo "Summary: ${OUTDIR}/ani_summary.tsv"
echo "Heatmap: ${OUTDIR}/figures/ANI_heatmap.png"
