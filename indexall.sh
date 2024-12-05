#!/bin/sh

#SBATCH --time=3:00:00
#SBATCH --mem=70GB

module load GCC/11.3.0
module load BCFtools/1.18

file=$(sed -n "${SLURM_ARRAY_TASK_ID}p" file_list.txt)  #full file path to each vcf

bcftools index -f $file

echo "index for $file complete"



