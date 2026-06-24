# PanGenFlow

Bulk download, deduplicate, and quality-control complete bacterial genomes from NCBI.
Works for any taxon from a single species to an entire phylum.

## What This Does

Download any taxon → Deduplicate GCA/GCF pairs → Extract metadata → ANI validation → CheckM2 QC → Clean genome list ready for analysis

## Installation

### NCBI Datasets CLI
conda install -c conda-forge ncbi-datasets-cli -y

### FastANI
conda install -c bioconda fastani -y

### CheckM2
pip install checkm2
checkm2 database --download --path ~/checkm2_db/

### Python
pip install pandas seaborn matplotlib scipy numpy

## Quick Start

### 1. Download
bash scripts/batch_download.sh "Deinococcota" output_genomes/

### 2. Deduplicate
python3 scripts/deduplicate_genomes.py output_genomes/ncbi_dataset/data/ genome_list.txt

### 3. Metadata
python3 scripts/extract_metadata.py output_genomes/ncbi_dataset/data/assembly_data_report.jsonl > metadata.tsv

### 4. ANI QC
bash scripts/run_fastani.sh genome_list.txt fastani_results/ 8

### 5. Genome QC
bash scripts/run_checkm2.sh genome_list.txt checkm2_results/ ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd 8

## Scripts

### batch_download.sh
Download complete genomes for any taxon from NCBI.

bash scripts/batch_download.sh "Deinococcus" deinococcus_genomes/
bash scripts/batch_download.sh "Thermus" thermus_genomes/
bash scripts/batch_download.sh "Deinococcota" deinococcota_genomes/

Options inside script:
ASSEMBLY_LEVEL="complete"
ASSEMBLY_SOURCE="RefSeq"
INCLUDE="genome,gff3,gbff"

### deduplicate_genomes.py
Removes GCA/GCF duplicate pairs. Keeps GCF (RefSeq) where available, GCA otherwise.

python3 scripts/deduplicate_genomes.py \
    deinococcota_genomes/ncbi_dataset/data/ \
    genome_list.txt

Output:
  Total GCF folders : 116
  GCA-only added    : 9
  Total final       : 125

### extract_metadata.py
Extracts species, genus, family, order, genome size, GC%, gene count from NCBI report.

python3 scripts/extract_metadata.py \
    deinococcota_genomes/ncbi_dataset/data/assembly_data_report.jsonl \
    > metadata_table.tsv

Output columns: accession | species | strain | genus | family | order |
                genome_size_bp | gc_percent | contig_n50 | gene_count

### run_fastani.sh
Runs FastANI all-vs-all and generates hierarchically clustered ANI heatmap.

bash scripts/run_fastani.sh genome_list.txt fastani_results/ 8

Output:
  fastani_results/fastani_results.txt
  figures/ANI_heatmap_clustered.pdf
  figures/ANI_heatmap_clustered.png

ANI thresholds:
  > 96%    same species
  80-96%   same genus
  70-80%   inter-order (expected at phylum level)
  < 70%    potential contamination

### run_checkm2.sh
Assesses completeness and contamination. Auto-splits passed/failed genomes.

bash scripts/run_checkm2.sh \
    genome_list.txt \
    checkm2_results/ \
    ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd \
    8

Default thresholds: Completeness >= 90%, Contamination <= 5%

Output:
  checkm2_results/quality_report.tsv
  checkm2_results/genome_list_qc_passed.txt
  checkm2_results/genome_list_qc_failed.txt

## Download Options Reference

Assembly level:
  --assembly-level complete          recommended for pangenomics
  --assembly-level chromosome
  --assembly-level scaffold
  --assembly-level contig

Source:
  --assembly-source RefSeq           recommended
  --assembly-source GenBank
  --assembly-source all

File types:
  --include genome                   FASTA only
  --include genome,gff3              + annotations
  --include genome,gff3,gbff         + GenBank flat file
  --include genome,gff3,gbff,protein + proteins

Filters:
  --exclude-atypical                 remove contaminated
  --annotated                        only annotated
  --limit 50                         limit results

## Check count before downloading

datasets summary genome taxon "Deinococcota" \
    --assembly-level complete \
    --assembly-source RefSeq | \
    python3 -c "import json,sys; print(json.load(sys.stdin)['total_count'])"

## Download by accession list

cat > accessions.txt << ACEOF
GCF_000008125.1
GCF_000091545.1
GCF_000020685.1
ACEOF

datasets download genome accession \
    --inputfile accessions.txt \
    --include genome,gff3 \
    --filename my_genomes.zip

## Large dataset — dehydrate first

datasets download genome taxon "Pseudomonadota" \
    --assembly-level complete \
    --dehydrated \
    --filename pseudomonadota.zip

unzip pseudomonadota.zip -d pseudomonadota_genomes/

datasets rehydrate \
    --directory pseudomonadota_genomes/ \
    --max-workers 8

## Taxid Reference

| Taxon            | Taxid  |
|------------------|--------|
| Deinococcota     | 188787 |
| Actinomycetota   | 201174 |
| Pseudomonadota   | 1224   |
| Bacillota        | 1239   |
| Bacteroidota     | 976    |
| Cyanobacteria    | 1117   |
| Deinococcus      | 1298   |
| Thermus          | 270    |
| Corynebacterium  | 1716   |
| Streptomyces     | 1883   |
| Bacillus         | 1386   |

## Troubleshooting

| Problem                  | Fix                                                    |
|--------------------------|--------------------------------------------------------|
| datasets not found       | conda install -c conda-forge ncbi-datasets-cli         |
| Download interrupted     | Re-run same command — resumes automatically            |
| 2x files expected        | GCA+GCF duplicates — run deduplicate_genomes.py        |
| No GFF files             | Re-download with --include genome,gff3                 |
| No genomes found         | Check spelling or use taxid instead of name            |
| Slow on large dataset    | Use --dehydrated then datasets rehydrate               |

## Citation

NCBI Datasets:
Sayers EW, et al. Database resources of the National Center for Biotechnology
Information in 2023. Nucleic Acids Research. 2023;51(D1):D29-D38.

FastANI:
Jain C, et al. High throughput ANI analysis of 90K prokaryotic genomes reveals
clear species boundaries. Nature Communications. 2018;9(1):5114.

CheckM2:
Chklovski A, et al. CheckM2: a rapid, scalable and accurate tool for assessing
microbial genome quality using machine learning. Nature Methods. 2023;20:1203-1212.

## License

MIT License — free to use, modify, and distribute with attribution.
