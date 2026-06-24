# Complete Pipeline Documentation

## Overview

This document describes the complete bioinformatics pipeline from genome download through machine learning AMP prediction, as used in the Deinococcota pangenome study.

---

## Pipeline Phases

```
Phase 1 — Genome Collection
Phase 2 — Quality Control (ANI + CheckM2)
Phase 3 — Taxonomy (GTDBTk)
Phase 4 — Pangenome (Roary per genus)
Phase 5 — BGC Mining (antiSMASH + BAGEL5)
Phase 6 — BGC Clustering (BiG-SCAPE)
Phase 7 — Phylogenomics (RAxML-NG + iTOL)
Phase 8 — Machine Learning AMP Prediction
```

---

## Phase 1 — Genome Collection

**Tool:** NCBI Datasets CLI

```bash
datasets download genome taxon "Deinococcota" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --exclude-atypical \
  --include genome,gff3,gbff,seq-report \
  --filename deinococcota_complete.zip

unzip deinococcota_complete.zip -d deinococcota_genomes/

# Keep GCF (RefSeq) only
find deinococcota_genomes/ncbi_dataset/data/ \
  -name "*.fna" -path "*/GCF_*" > genome_list.txt

wc -l genome_list.txt  # 116 genomes
```

**Output:** `genome_list.txt` — 116 paths to complete genome FASTAs

---

## Phase 2 — Quality Control

### 2A. ANI Analysis

**Tool:** FastANI v1.34

```bash
fastANI \
  --ql genome_list.txt \
  --rl genome_list.txt \
  --output fastani_results.txt \
  --threads 8 \
  --matrix
```

**Thresholds:**
- Same species: ANI > 95–96%
- Same genus: ANI 80–95%
- Inter-order (expected): ANI 76–80%
- Remove if: ANI < 70% against all other genomes

**Output:** `fastani_results.txt`, `figures/ANI_heatmap_clustered.pdf`

### 2B. Genome Completeness

**Tool:** CheckM2 v1.0.1

```bash
checkm2 predict \
  --input all_genomes_fasta/ \
  --output-directory checkm2_results/ \
  --database_path ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd \
  --threads 8 \
  --extension fna
```

**Thresholds:**
- Completeness: ≥ 90% ✅
- Contamination: ≤ 5% ✅

**Output:** `checkm2_results/quality_report.tsv`, `genome_list_qc_passed.txt`

---

## Phase 3 — Taxonomy

**Tool:** GTDBTk

```bash
# On HPC
gtdbtk classify_wf \
  --genome_dir genomes/ \
  --out_dir gtdbtk_results/ \
  --extension fna \
  --cpus 16 \
  --skip_ani_screen
```

**Output:** `gtdbtk_results/gtdbtk.bac120.summary.tsv` — GTDB taxonomy per genome

**Use taxonomy to:**
- Assign each genome to genus and order
- Split genomes for genus-level Roary runs
- Map BGC distribution onto phylogenetic tree

---

## Phase 4 — Pangenome Construction

### Strategy

```
Genus-level (Roary 95%) — one per genus
    ↓
Order-level (Roary 80%) — Deinococcales + Thermales separately
    ↓
Phylum-level (BiG-SCAPE) — BGC comparison across all 116 genomes
```

### Split GFF files by genus

```bash
python3 scripts/split_gff_by_genus.py \
  --gff-dir deinococcota_genomes/ncbi_dataset/data/ \
  --metadata metadata_table.tsv \
  --output-dir gff_by_genus/ \
  --ncbi-mode
```

### Run Roary array on HPC

```bash
# genus_list.txt must exist with one genus per line
sbatch scripts/roary_genus_array.slurm
```

### Roary parameters

| Parameter | Value | Description |
|---|---|---|
| `-i` | 95 | Protein identity threshold |
| `-cd` | 99 | Core genome definition (% genomes) |
| `-e` | flag | Create multiFASTA alignment |
| `-n` | flag | Fast core genome alignment (MAFFT) |
| `-p` | 16 | CPU threads |

### Key outputs per genus

```
roary_results/{GENUS}/
├── gene_presence_absence.csv    ← presence/absence matrix
├── core_gene_alignment.aln      ← core genome alignment
├── summary_statistics.txt       ← core/accessory/cloud counts
├── pan_genome_reference.fa      ← pan-genome reference
└── accessory_binary_genes.fa    ← accessory gene sequences
```

### Heap's Law Analysis

```bash
python3 scripts/heaps_law.py \
  roary_results/Deinococcus/gene_presence_absence.csv \
  --output figures/heaps_law_deinococcus.pdf
```

---

## Phase 5 — BGC Mining

### antiSMASH

```bash
# Submit array job on HPC
sbatch scripts/antismash_array.slurm

# After completion — collect all BGC counts
for strain_dir in antismash_out/*/; do
    strain=$(basename "$strain_dir")
    count=$(ls "$strain_dir"*.gbk 2>/dev/null | wc -l)
    echo "$strain $count"
done > bgc_counts_per_genome.txt
```

**BGC classes detected:**
- Terpene
- RiPP (RiPP-like, lanthipeptide, bacteriocin)
- Polyketide (T1PKS, T2PKS, T3PKS)
- NRPS
- Hybrid clusters

### BAGEL5 (web-based)

URL: https://bagel4.molgenrug.nl

Upload all genome FASTAs → download results → save to `bagel5_results/`

Detects: bacteriocins, lanthipeptides, sactipeptides, head-to-tail cyclized peptides

---

## Phase 6 — BGC Clustering (BiG-SCAPE)

```bash
conda activate bigscape

bigscape \
  --inputdir antismash_out/ \
  --outputdir bigscape_out/ \
  --pfam_dir pfam/ \
  --cores 16 \
  --mode glocal \
  --cutoffs 0.3 0.5 0.7

# View results in browser
cd bigscape_out/
python3 -m http.server 8080
```

**Output:** Gene Cluster Families (GCFs) — groups all BGCs across all 116 genomes

---

## Phase 7 — Phylogenomics

### Build phylogenetic tree

```bash
# Use core genome alignment from Roary (order-level run at 80% identity)
roary -e -n -i 80 -cd 99 -p 16 \
  gff_by_genus/*/*.gff \
  -f roary_phylum/

# Build ML tree
raxml-ng \
  --all \
  --msa roary_phylum/core_gene_alignment.aln \
  --model GTR+G \
  --prefix phylo/deinococcota_tree \
  --threads 16 \
  --bs-trees 100
```

### Annotate tree in iTOL

Upload to https://itol.embl.de:
- `deinococcota_tree.raxml.bestTree` — tree file
- Annotation files: BGC count per genome, BGC types, isolation habitat, order

---

## Phase 8 — Machine Learning AMP Prediction

### Data preparation

```bash
# Download AMPs from APD3 (https://aps.unmc.edu)
# Download non-AMPs from UniProt

# Deduplicate at 97% identity
cd-hit -i all_sequences.fasta \
       -o cd-hit_out.fasta \
       -c 0.97 -n 5 -M 8000 -T 8
```

### Feature extraction (CTD)

```python
# 735 features per peptide
# 7 physicochemical properties × 3 CTD components × 5 percentile positions
# Properties: hydrophobicity, van der Waals volume, polarity,
#             polarizability, charge, secondary structure, solvent accessibility

python3 scripts/extract_ctd_features.py \
  --input cd-hit_out.fasta \
  --output ctd_features.csv
```

### Model training

```python
from sklearn.svm import SVC
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import RandomizedSearchCV, StratifiedKFold
from imblearn.over_sampling import SMOTE

# 80/20 stratified train/test split
# SMOTE applied to training set only
# 5-fold cross-validation for hyperparameter tuning
# Soft-voting ensemble of SVM + RF + KNN

python3 scripts/train_amp_classifier.py \
  --features ctd_features.csv \
  --labels labels.csv \
  --output models/
```

### Apply to genome-mined peptides

```python
# Extract RiPP sequences from BAGEL5 + antiSMASH output
python3 scripts/apply_amp_classifier.py \
  --antismash-dir antismash_out/ \
  --bagel5-dir bagel5_results/ \
  --model models/ensemble_model.pkl \
  --scaler models/scaler.pkl \
  --threshold 0.95 \
  --output amp_candidates.tsv
```

**Filtering:**
- Probability ≥ 0.95 (high confidence)
- Collapse duplicate sequence IDs — keep highest probability
- Final candidates annotated with genus, BGC source, habitat

---

## Software Versions

| Tool | Version | Installation |
|---|---|---|
| NCBI Datasets CLI | latest | `conda install -c conda-forge ncbi-datasets-cli` |
| FastANI | 1.34 | `conda install -c bioconda fastani` |
| CheckM2 | 1.0.1 | `pip install checkm2` |
| GTDBTk | 2.x | `conda install -c bioconda gtdbtk` |
| Prokka | 1.14.6 | `conda install -c bioconda prokka` |
| Roary | 3.13.0 | `conda install -c bioconda roary` |
| antiSMASH | 7.0 | `conda install -c bioconda antismash` |
| BAGEL5 | web | https://bagel4.molgenrug.nl |
| BiG-SCAPE | 1.1.5 | `conda install -c bioconda bigscape` |
| RAxML-NG | 1.2 | `conda install -c bioconda raxml-ng` |
| CD-HIT | 4.8.1 | `conda install -c bioconda cd-hit` |
| scikit-learn | 1.3+ | `pip install scikit-learn` |
| imbalanced-learn | 0.11 | `pip install imbalanced-learn` |
| Biopython | 1.81 | `pip install biopython` |

---

## Directory Structure

```
deino/
├── genome_list.txt                    ← input genome paths
├── genome_list_qc_passed.txt          ← clean genome list after QC
├── genus_list.txt                     ← genera for Roary array
├── metadata_table.tsv                 ← taxonomy + assembly stats
│
├── deinococcota_genomes/              ← raw NCBI download
│   └── ncbi_dataset/data/
│       └── GCF_*/
│
├── fastani_results/                   ← ANI analysis
│   └── fastani_results.txt
│
├── checkm2_results/                   ← QC results
│   └── quality_report.tsv
│
├── gtdbtk_results/                    ← GTDB taxonomy
│   └── gtdbtk.bac120.summary.tsv
│
├── gff_by_genus/                      ← GFFs split by genus
│   ├── Deinococcus/
│   ├── Thermus/
│   └── ...
│
├── roary_results/                     ← Pangenome results
│   ├── Deinococcus/
│   ├── Thermus/
│   └── ...
│
├── antismash_out/                     ← BGC predictions
│   └── GCF_*/
│
├── bagel5_results/                    ← RiPP predictions
├── bigscape_out/                      ← BGC families
│
├── phylo/                             ← Phylogenetic tree
│   └── deinococcota_tree.raxml.bestTree
│
├── ml_analysis/                       ← ML models and results
│   ├── ctd_features.csv
│   ├── models/
│   └── amp_candidates.tsv
│
├── figures/                           ← All publication figures
│   ├── ANI_heatmap_clustered.pdf
│   ├── pangenome_*.pdf
│   ├── bgc_distribution.pdf
│   └── ml_performance.pdf
│
└── logs/                              ← HPC job logs
```
