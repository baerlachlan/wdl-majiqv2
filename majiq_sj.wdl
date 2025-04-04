version 1.0

workflow majiq_sj {
    input {
        Array[File] bam
        File gff3
        String ref_genome
        String dest_gs_uri = "NULL"
        String remove_bam_suffix = ".bam"
        Boolean compress = true
        Int machine_cpu = 1
        Int machine_mem_gb = 4
        Int machine_disk_gb = 20
    }

    scatter(i in range(length(bam))) {
        call splice_junctions {
            input:
            bam = bam[i],
            bai = "~{bam[i]}.bai",
            gff3 = gff3,
            ref_genome = ref_genome,
            dest_gs_uri = dest_gs_uri,
            remove_bam_suffix = remove_bam_suffix,
            compress = compress,
            machine_cpu = machine_cpu,
            machine_mem_gb = machine_mem_gb,
            machine_disk_gb = machine_disk_gb,
        }
    }

    output {
        Array[File] sj = splice_junctions.sj
    }
}

task splice_junctions {
    input {
        File bam
        File bai
        File gff3
        String ref_genome
        String dest_gs_uri
        String remove_bam_suffix
        Boolean compress
        Int machine_cpu
        Int machine_mem_gb
        Int machine_disk_gb
    }

    String sample = basename(bam, ".bam")
    String id = basename(bam, remove_bam_suffix)
    String sj_out = if compress then "~{id}.sj.gz" else "~{id}.sj"

    command <<<
        cat << EOF > settings.ini
        [info]
        bamdirs=$(dirname ~{bam})
        genome=~{ref_genome}
        [experiments]
        sample=~{sample}
        EOF

        majiq build -j 1 -c settings.ini -o . ~{gff3} --junc-files-only
        mv ~{sample}.sj ~{id}.sj

        if [[ ~{compress} = "true" ]]; then
            gzip ~{id}.sj
        fi
        if [[ ~{dest_gs_uri} != "NULL" ]]; then
            gsutil cp ~{sj_out} ~{dest_gs_uri}
        fi
    >>>

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: machine_cpu
        memory: "~{machine_mem_gb} GB"
        disks: "local-disk ~{machine_disk_gb} HDD"
    }

    output {
        File sj = sj_out
    }
}