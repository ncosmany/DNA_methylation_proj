#!/bin/sh


module load GCC/11.3.0
module load BCFtools/1.18


#rehead so NA0001 replaced with sample names
#do this after running merge, all files from merge will go in order of their folder so just use that same list

#rehead with sample names 
bcftools reheader -s file_list.txt ../outputs/merged_files.vcf.gz > ../outputs/reheaded_merged.vcf.gz
