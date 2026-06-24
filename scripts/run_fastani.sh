#!/bin/bash
# =============================================================================
# run_fastani.sh
# Run FastANI all-vs-all on a set of genomes and generate heatmap
#
# Usage:
#   bash run_fastani.sh <genome_list.txt> <output_dir>
#
# Example:
#   bash run_fastani.sh genome_list.txt fastani_results/
#
# Requirements:
#   conda install -c bioconda fastani -y
#   pip install pandas seaborn matplotlib scipy
# =============================================================================

set -euo pipefail

GENOME_LIST=${1:-"genome_list.txt"}
OUTDIR=${2:-"fastani_results"}
THREADS=${3:-8}

mkdir -p "$OUTDIR"
mkdir -p figures

echo "========================================"
echo "FastANI All-vs-All"
echo "Genome list : $GENOME_LIST"
echo "Output dir  : $OUTDIR"
echo "Threads     : $THREADS"
echo "Started     : $(date)"
echo "========================================"

# Verify input
if [ ! -f "$GENOME_LIST" ]; then
    echo "ERROR: genome list not found: $GENOME_LIST"
    exit 1
fi

GENOME_COUNT=$(wc -l < "$GENOME_LIST")
echo "Genomes to compare: $GENOME_COUNT"
echo "Total comparisons : $((GENOME_COUNT * GENOME_COUNT))"

# Run FastANI
echo ""
echo "Running FastANI..."
fastANI \
    --ql "$GENOME_LIST" \
    --rl "$GENOME_LIST" \
    --output "${OUTDIR}/fastani_results.txt" \
    --threads "$THREADS" \
    --matrix

echo "FastANI complete: $(date)"
echo "Output lines: $(wc -l < ${OUTDIR}/fastani_results.txt)"

# Generate heatmap
echo ""
echo "Generating ANI heatmap..."

python3 << PYEOF
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
from scipy.cluster.hierarchy import linkage, leaves_list
from scipy.spatial.distance import squareform
import sys

results_file = "${OUTDIR}/fastani_results.txt"
outdir       = "${OUTDIR}"

# Load results
df = pd.read_csv(results_file, sep="\t", header=None,
                 names=["query","ref","ANI","frags_mapped","total_frags"])

df["query"] = df["query"].apply(lambda x: x.split("/")[-2])
df["ref"]   = df["ref"].apply(lambda x: x.split("/")[-2])

genomes = sorted(df["query"].unique().tolist())
print(f"Genomes detected: {len(genomes)}")

# Add self-comparisons
self_df = pd.DataFrame({
    "query": genomes, "ref": genomes,
    "ANI": 100.0, "frags_mapped": 0, "total_frags": 0
})
df = pd.concat([df, self_df], ignore_index=True)

# Build matrix
matrix = df.pivot_table(index="query", columns="ref",
                         values="ANI", aggfunc="mean")
matrix = matrix.reindex(index=genomes, columns=genomes).fillna(70)

# Force symmetry
matrix_sym = (matrix.values + matrix.values.T) / 2
matrix = pd.DataFrame(matrix_sym, index=genomes, columns=genomes)

# Cluster
distance = np.clip(100 - matrix.values, 0, None)
np.fill_diagonal(distance, 0)
Z = linkage(squareform(distance), method="average")
order = leaves_list(Z)
ordered = [genomes[i] for i in order]
matrix_ordered = matrix.loc[ordered, ordered]

# Plot
fig, ax = plt.subplots(figsize=(22, 20))
sns.heatmap(matrix_ordered,
            cmap="RdYlBu_r",
            vmin=70, vmax=100,
            xticklabels=True,
            yticklabels=True,
            linewidths=0,
            ax=ax,
            cbar_kws={"label": "ANI (%)", "shrink": 0.6})
ax.set_title(f"Average Nucleotide Identity (n={len(genomes)})\nHierarchically clustered",
             fontsize=14, pad=12)
ax.tick_params(axis="x", labelsize=3.5, rotation=90)
ax.tick_params(axis="y", labelsize=3.5, rotation=0)
plt.tight_layout()
plt.savefig("figures/ANI_heatmap_clustered.pdf", dpi=300)
plt.savefig("figures/ANI_heatmap_clustered.png", dpi=300)
print("Heatmap saved to figures/")

# Print summary stats
no_self = matrix.values.copy()
np.fill_diagonal(no_self, np.nan)
vals = no_self[~np.isnan(no_self)]
vals = vals[vals > 0]
print(f"\nANI Summary:")
print(f"  Min  : {vals.min():.2f}%")
print(f"  Max  : {vals.max():.2f}%")
print(f"  Mean : {vals.mean():.2f}%")
print(f"  Median: {np.median(vals):.2f}%")

# Flag outliers
mean_ani = pd.DataFrame(no_self, index=genomes, columns=genomes).mean(axis=1)
low = mean_ani[mean_ani < 80]
if len(low) > 0:
    print(f"\nGenomes with mean ANI < 80% (check these):")
    for g, v in low.items():
        print(f"  {g}: {v:.2f}%")
else:
    print("\nNo outlier genomes detected.")

PYEOF

echo ""
echo "========================================"
echo "All done: $(date)"
echo "Results  : ${OUTDIR}/fastani_results.txt"
echo "Heatmap  : figures/ANI_heatmap_clustered.pdf"
echo "========================================"
