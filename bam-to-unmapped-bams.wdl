## Copyright Broad Institute, 2017
## 
## This WDL converts BAM  to unmapped BAMs
##
## Requirements/expectations :
## - BAM file
##
## Outputs :
## - Sorted Unmapped BAMs
##
## Cromwell version support
## - Successfully tested on v31
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##
## LICENSING : 
## This script is released under the WDL source code license (BSD-3) (see LICENSE in 
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may 
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker 
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs.

# WORKFLOW DEFINITION
workflow BamToUnmappedBams {
  File input_bam

  Int? additional_disk_size
  Int additional_disk = select_first([additional_disk_size, 20])

  Float input_size = size(input_bam, "GB")
  
  String? gatk_path
  String path2gatk = select_first([gatk_path, "/gatk/gatk"])

  String? gitc_docker
  String gitc_image = select_first([gitc_docker, "broadinstitute/genomes-in-the-cloud:2.3.1-1512499786"])
  String? gatk_docker 
  String gatk_image = select_first([gatk_docker, "broadinstitute/gatk:latest"])

  call GenerateOutputMap {
    input:
      input_bam = input_bam,
      disk_size = ceil(input_size) + additional_disk,
      docker = gitc_image
  }

  call RevertSam {
    input:
      input_bam = input_bam,
      output_map = GenerateOutputMap.output_map,
      disk_size = ceil(input_size * 3) + additional_disk,
      docker = gatk_image,
      gatk_path = path2gatk
  }

  scatter (unmapped_bam in RevertSam.unmapped_bams) {
    String output_basename = basename(unmapped_bam, ".coord.sorted.unmapped.bam")
    Float unmapped_bam_size = size(unmapped_bam, "GB")

    call SortSam {
      input:
        input_bam = unmapped_bam,
        sorted_bam_name = output_basename + ".unmapped.bam",
        disk_size = ceil(unmapped_bam_size * 6) + additional_disk,
        docker = gatk_image,
        gatk_path = path2gatk
    }
  }

  output {
    Array[File] output_bams = SortSam.sorted_bam
  }
}

task GenerateOutputMap {
  File input_bam
  Int disk_size
  
  String docker

  command {
    set -e

    samtools view -H ${input_bam} | grep @RG | cut -f2 | sed s/ID:// > readgroups.txt

    echo -e "READ_GROUP_ID\tOUTPUT" > output_map.tsv

    for rg in `cat readgroups.txt`; do
      echo -e "$rg\t$rg.coord.sorted.unmapped.bam" >> output_map.tsv
    done
  }

  runtime {
    docker: docker
    disks: "local-disk " + disk_size + " HDD"
    preemptible: "3"
    memory: "1 GB"
  }
  output {
    File output_map = "output_map.tsv"
  }
}

task RevertSam {
  File input_bam
  File output_map
  Int disk_size

  String gatk_path

  String docker

  command {
    ${gatk_path} --java-options "-Xmx1000m" \
    RevertSam \
    --INPUT ${input_bam} \
    --OUTPUT_MAP ${output_map} \
    --OUTPUT_BY_READGROUP true \
    --VALIDATION_STRINGENCY LENIENT \
    --ATTRIBUTE_TO_CLEAR FT \
    --ATTRIBUTE_TO_CLEAR CO \
    --SORT_ORDER coordinate
  }
  runtime {
    docker: docker
    disks: "local-disk " + disk_size + " HDD"
    memory: "1200 MB"
  }
  output {
    Array[File] unmapped_bams = glob("*.bam")
  }
}

task SortSam {
  File input_bam
  String sorted_bam_name
  Int disk_size

  String gatk_path

  String docker

  command {
    ${gatk_path} --java-options "-Xmx3000m" \
    SortSam \
    --INPUT ${input_bam} \
    --OUTPUT ${sorted_bam_name} \
    --SORT_ORDER queryname \
    --MAX_RECORDS_IN_RAM 1000000
  }
  runtime {
    docker: docker
    disks: "local-disk " + disk_size + " HDD"
    memory: "3500 MB"
    preemptible: 3
  }
  output {
    File sorted_bam = "${sorted_bam_name}"
  }
}

