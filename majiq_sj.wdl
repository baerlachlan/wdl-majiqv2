version 1.0

workflow majiq_sj {
    input {
        Array[File] bam
        Array[File]? bai
        File gff3
        String ref_genome
        String dest_gs_uri = "NULL"
        String remove_suffix = ".bam"
        Boolean compress = true
    }

    scatter(i in range(length(bam))) {
        call splice_junctions {
            input:
            bam = bam[i],
            bai = select_first([bai, "~{bam[i]}.bai"]),
            gff3 = gff3,
            ref_genome = ref_genome,
            dest_gs_uri = dest_gs_uri,
            remove_suffix = remove_suffix,
            compress = compress,
        }
    }

    output {
        Array[File] sj = splice_junctions.sj
    }
}

task splice_junctions {
    input {
        File bam
        File? bai
        File gff3
        String ref_genome
        String dest_gs_uri
        String remove_suffix
        Boolean compress
    }

    ## Determine disk request based on input
    Int input_size_gb = ceil(size(bam, "GB")) + ceil(size(gff3, "GB"))
    Int disk_size_gb = input_size_gb + 5  # Add buffer
    String sample = basename(bam, ".bam")
    String id = basename(bam, remove_suffix)
    String sj_out = if compress then "~{id}.sj.gz" else "~{id}.sj"

    command <<<
        echo -e "[info]\nbamdirs=$(dirname ~{bam})\ngenome=~{ref_genome}\n[experiments]\nsample=~{sample}" > majiq.conf
        majiq build -j 1 -c majiq.conf -o . ~{gff3} --junc-files-only
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
        cpu: 1
        memory: "4 GB"
        disks: "local-disk ~{disk_size_gb} HDD"
    }

    output {
        File sj = sj_out
    }
}