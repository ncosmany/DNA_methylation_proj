#!/bin/sh

#SBATCH --mem=10GB
#SBATCH --time=22:00:00 

module load GCC/11.3.0
module load BCFtools/1.18

#rehead so NA0001 replaced with sample names

for file in ../outputs/finalvcfs/*.vcf.gz; do
   sample_name=$(basename $file .vcf.gz)
   echo $sample_name > currsample.txt 
   bcftools reheader -s currsample.txt -o ../outputs/reheaded/$sample_name.vcf.gz $file
done
