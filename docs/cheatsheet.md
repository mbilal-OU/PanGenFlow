# NCBI Datasets CLI — Quick Reference Cheatsheet

## Installation
```bash
conda install -c conda-forge ncbi-datasets-cli -y
datasets --version
```

---

## Core Commands

| Command | Description |
|---|---|
| `datasets download genome taxon` | Download by organism name or taxid |
| `datasets download genome accession` | Download specific accessions |
| `datasets summary genome taxon` | Preview without downloading |
| `datasets rehydrate` | Download sequences after dehydrated download |

---

## Essential Flags

| Flag | Values | Use case |
|---|---|---|
| `--assembly-level` | `complete` `chromosome` `scaffold` `contig` | Filter by assembly quality |
| `--assembly-source` | `RefSeq` `GenBank` `all` | Prefer RefSeq for quality |
| `--include` | `genome` `gff3` `gbff` `protein` `rna` `cds` `seq-report` | Choose file types |
| `--exclude-atypical` | (flag) | Remove contaminated assemblies |
| `--annotated` | (flag) | Only annotated genomes |
| `--reference` | (flag) | Reference genomes only |
| `--limit` | number or `none` | Limit number of downloads |
| `--dehydrated` | (flag) | Download metadata only first |
| `--filename` | path | Output ZIP file name |

---

## Most Common Recipes

```bash
# Pangenome study — complete annotated genomes
datasets download genome taxon "ORGANISM" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --exclude-atypical \
  --include genome,gff3,gbff \
  --filename output.zip

# Check count before downloading
datasets summary genome taxon "ORGANISM" \
  --assembly-level complete \
  --assembly-source RefSeq | python3 -c \
  "import json,sys; print(json.load(sys.stdin)['total_count'])"

# Download specific accessions from a file
datasets download genome accession \
  --inputfile accessions.txt \
  --include genome,gff3 \
  --filename batch.zip

# Large dataset — dehydrate first then rehydrate
datasets download genome taxon "ORGANISM" \
  --assembly-level complete \
  --dehydrated \
  --filename output_dehydrated.zip
unzip output_dehydrated.zip -d genomes/
datasets rehydrate --directory genomes/ --max-workers 8
```

---

## Post-Download

```bash
# Unzip
unzip output.zip -d genomes/

# Count genomes
ls genomes/ncbi_dataset/data/ | grep "GCF_" | wc -l

# Get all FASTA paths (GCF only)
find genomes/ncbi_dataset/data/ -name "*.fna" -path "*/GCF_*" > genome_list.txt

# Get all GFF paths (GCF only)
find genomes/ncbi_dataset/data/ -name "*.gff" -path "*/GCF_*" > gff_list.txt

# Get all GBFF paths (GCF only)
find genomes/ncbi_dataset/data/ -name "*.gbff" -path "*/GCF_*" > gbff_list.txt
```

---

## Taxid Reference (Common Phyla)

| Organism | Taxid |
|---|---|
| Deinococcota | 188787 |
| Actinomycetota | 201174 |
| Pseudomonadota | 1224 |
| Bacillota | 1239 |
| Bacteroidota | 976 |
| Cyanobacteria | 1117 |
| Thermus thermophilus | 274 |
| Deinococcus radiodurans | 1299 |
| Corynebacterium glutamicum | 1718 |

---

## Troubleshooting

```bash
# If taxon name fails, use taxid
datasets download genome taxon 188787 --assembly-level complete

# If download interrupted, just re-run — it resumes
datasets download genome taxon "ORGANISM" --assembly-level complete --filename same_file.zip

# Check what files are in the ZIP before extracting
unzip -l output.zip | head -30

# Verify checksums
cd genomes/ && md5sum -c md5sum.txt
```
