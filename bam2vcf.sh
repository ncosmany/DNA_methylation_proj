#!/bin/sh

#SBATCH --time 20:00:00
#SBATCH --mem=25GB

module load GCC/11.3.0
module load SAMtools/1.18
module load HTSlib/1.18 #contains tabix and bgzip
module load BCFtools/1.18

sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ../missing_samples.txt)  #just the sample ID

#paths for sort
path_bam=/data/lea_lab/archive_raw_fastq/TurkanaTsimaneOA_DNAmeth_17Jun2024/bams/${sample}.bam
sorted_bam=/nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample}_sorted.bam
filtered_bam=/nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample}_filtered.bam

#paths for convert 
sorted_chr=/nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample} #path to sorted splits
path_human_genome=/nobackup/lea_lab/nicole/hg38.fa

#paths for snv 
converted_chr=/nobackup/lea_lab/nicole/dna_methylation/outputs/converted/${sample}
vcfs=/nobackup/lea_lab/nicole/dna_methylation/outputs/vcfs/${sample}
outs=/nobackup/lea_lab/nicole/dna_methylation/outputs/outs/${sample}

#paths for filter
merged_output=/nobackup/lea_lab/nicole/dna_methylation/test2/vcfs/fullsample.vcf
pass_output=/nobackup/lea_lab/nicole/dna_methylation/test2/vcfs

#make directorys 
mkdir /nobackup/lea_lab/nicole/dna_methylation/outputs/converted/${sample}
mkdir /nobackup/lea_lab/nicole/dna_methylation/outputs/vcfs/${sample}
mkdir /nobackup/lea_lab/nicole/dna_methylation/outputs/outs/${sample}

#sort bams
samtools sort -o $sorted_bam $path_bam
samtools view $path_bam | wc -l 
echo "sort for ${sample} done"

#split bams
samtools index $sorted_bam
mkdir /nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample}

#filter bams before split
samtools view --region-file ../targetbed.txt $sorted_bam -b -o $filtered_bam
samtools index $filtered_bam

for chr in {1..22} X Y ; do
    if samtools idxstats "$filtered_bam" | awk '{print $1}' | grep -q -w "chr$chr"; then
        output_bam=/nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample}
        echo "Starting chr ${chr} split"
        samtools view -b $filtered_bam "chr${chr}" >"$output_bam/chr${chr}.bam"
    fi 
done

echo "split done"

rm $sorted_bam
rm $filtered_bam

for chr in {1..22} X Y; do
    if [ -f "/nobackup/lea_lab/nicole/dna_methylation/outputs/sorted/${sample}/chr${chr}.bam" ]; then

    converted_chr=/nobackup/lea_lab/nicole/dna_methylation/outputs/converted/${sample}

    echo "Starting chr ${chr}"

    #convert
    cgmaptools convert bam2cgmap -b $sorted_chr/chr${chr}.bam --rmOverlap -g $path_human_genome -o $converted_chr/chr${chr}

    #snv
    cgmaptools snv -i $converted_chr/chr${chr}.ATCGmap.gz -m bayes -v $vcfs/chr${chr}.vcf --bayes-dynamicP -o $outs/chr${chr}.out --bayes-e=0.01 -a

    #filter and remove DP<5
    bgzip -c $vcfs/chr${chr}.vcf > $vcfs/chr${chr}.vcf.gz
    tabix -f -p vcf $vcfs/chr${chr}.vcf.gz
    bcftools view -f 'PASS,.' $vcfs/chr${chr}.vcf.gz --output-type z > $vcfs/chr${chr}_pass.vcf.gz
    tabix -f -p vcf $vcfs/chr${chr}_pass.vcf.gz
    bcftools filter -i 'FORMAT/DP>4' $vcfs/chr${chr}_pass.vcf.gz --output-type z > $vcfs/chr${chr}_pass_DP5.vcf.gz
    tabix -f -p vcf $vcfs/chr${chr}_pass_DP5.vcf.gz
    merge_files="$merge_files $vcfs/chr${chr}_pass_DP5.vcf.gz"

    #remove extra files 
    rm $vcfs/chr${chr}_pass.vcf.gz
    rm $vcfs/chr${chr}.vcf
    fi
done

#merge for final vcf
final=/nobackup/lea_lab/nicole/dna_methylation/outputs/finalvcfs/${sample}.vcf.gz
bcftools concat $merge_files -Oz -o $final

#remove unnecessary .outs 
rm -r /nobackup/lea_lab/nicole/dna_methylation/outputs/outs/${sample}

#remove files from convert step 
rm -r /nobackup/lea_lab/nicole/dna_methylation/outputs/converted/${sample}

#remove split bams
rm -r /nobackup/lea_lab/nicole/dna_methylation/outputs/vcfs/${sample}

rm -r $sorted_chr

echo "done with ${sample}"
