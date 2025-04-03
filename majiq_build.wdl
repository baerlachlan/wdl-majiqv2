version 1.0

workflow majiq_build {
    input {
        Array[File] bam
        Array[File] sj
        File gff3
        String ref_genome
        String dest_gs_uri = "NULL"
        String remove_bam_suffix = ".bam"
        Int machine_cpu = 1
        Int machine_mem_gb = 4
        Int machine_disk_gb = 20
    }

    call build {
        input:
        bam = bam,
        sj = sj,
        gff3 = gff3,
        ref_genome = ref_genome,
        dest_gs_uri = dest_gs_uri,
        remove_bam_suffix = remove_bam_suffix,
        machine_cpu = machine_cpu,
        machine_mem_gb = machine_mem_gb,
        machine_disk_gb = machine_disk_gb,
    }

    output {
        Array[File] majiq = build.majiq
        File splicegraph = build.splicegraph
    }
}

task build {
    input {
        Array[File] bam
        Array[File] sj
        File gff3
        String ref_genome
        String dest_gs_uri
        String remove_bam_suffix
        Int machine_cpu
        Int machine_mem_gb
        Int machine_disk_gb
    }

    command <<<
        for f in ~{sep=" " bam}; do
            mv ${f} ${f%~{remove_bam_suffix}}.bam
            basename ${f} ~{remove_bam_suffix}
        done | sort | uniq | paste -sd, - > samples.txt
        for f in ~{sep=" " bam}; do
            dirname ${f}
        done | sort | uniq | paste -sd, - > bam_dirs.txt
        for f in ~{sep=" " sj}; do
            dirname ${f}
        done | sort | uniq | paste -sd, - > sj_dirs.txt

        cat << EOF > settings.ini
        [info]
        bamdirs=$(cat bam_dirs.txt)
        sjdirs=$(cat sj_dirs.txt)
        genome=~{ref_genome}
        [experiments]
        samples=$(cat samples.txt)
        EOF

        echo "samples are:"
        cat samples.txt
        echo "bam_dirs are:"
        cat bam_dirs.txt
        echo "sj_dirs are:"
        cat sj_dirs.txt
        echo "settings.ini contains:"
        cat settings.ini

        majiq build -j 4 -c settings.ini -o . ~{gff3} --incremental \
        --disable-ir --disable-denovo --disable-denovo-ir \
        --min-experiments 0.5 --min-intronic-cov 0.1 --min-denovo 5 --minreads 10 --minpos 3 \
        --simplify-denovo 0 --simplify-annotated 0 --simplify-ir 0 --simplify 0.01 \
        --m 30 --irnbins 0.5

        if [[ ~{dest_gs_uri} != "NULL" ]]; then
            gsutil cp *.majiq ~{dest_gs_uri}
            gsutil cp *.sj ~{dest_gs_uri}
            gsutil cp splicegraph.sql ~{dest_gs_uri}
            gsutil cp majiq.log ~{dest_gs_uri}
        fi
    >>>

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: machine_cpu
        memory: "~{machine_mem_gb} GB"
        disks: "local-disk ~{machine_disk_gb} HDD"
    }

    output {
        Array[File] majiq = glob("*.majiq")
        String splicegraph = "splicegraph.sql"
    }
}