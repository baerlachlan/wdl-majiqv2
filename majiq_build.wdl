version 1.0

workflow majiq_build {
    input {
        Array[File] bam
        Array[String] bam_dirs
        Array[File] sj
        Array[String] sj_dirs
        File gff3
        String ref_genome
        String dest_gs_uri = "NULL"
    }

    call build {
        input:
        bam = bam,
        bam_dirs = bam_dirs,
        sj = sj,
        sj_dirs = sj_dirs,
        gff3 = gff3,
        ref_genome = ref_genome,
        dest_gs_uri = dest_gs_uri,
    }

    output {
        Array[File] majiq = build.majiq
        File splicegraph = build.splicegraph
    }
}

task build {
    input {
        Array[File] bam
        Array[String] bam_dirs
        Array[File] sj
        Array[String] sj_dirs
        File gff3
        String ref_genome
        String dest_gs_uri
    }

    ## Determine disk request based on input
    Int input_size_gb = ceil(size(sj, "GB")) + ceil(size(gff3, "GB"))
    Int disk_size_gb = input_size_gb + 10  # Add buffer

    command <<<
        samples=""
        for i in ~{sj}; do
            bn=$(basename ${i} .sj)
            if [ -z ${samples} ]; then
                samples="${bn}"
            else
                samples="${samples},${bn}"
            fi
        done
        bam_dirs=""
        for i in ~{bam_dirs}; do
            bn=$(basename ${i} .sj)
            if [ -z ${bam_dirs} ]; then
                bam_dirs="${bn}"
            else
                bam_dirs="${bam_dirs},${bn}"
            fi
        done
        sj_dirs=""
        for i in ~{sj_dirs}; do
            bn=$(basename ${i} .sj)
            if [ -z ${sj_dirs} ]; then
                sj_dirs="${bn}"
            else
                sj_dirs="${sj_dirs},${bn}"
            fi
        done
        echo -e "[info]\nbamdirs=${bam_dirs}\nsjdirs=${sj_dirs}\ngenome=~{ref_genome}\n[experiments]\nsamples=${samples}" > settings.ini
        majiq build -j 4 -c settings.ini -o . ~{gff3} --incremental \
        --disable-ir --disable-denovo --disable-denovo-ir \
        --min-experiments 0.5 --min-intronic-cov 0.1 --min-denovo 5 --minreads 10 --minpos 3 \
        --simplify-denovo 0 --simplify-annotated 0 --simplify-ir 0 --simplify 0.01 \
        --m 30 --irnbins 0.5
        if [[ ~{dest_gs_uri} != "NULL" ]]; then
            gsutil cp *.majiq ~{dest_gs_uri}
            gsutil cp splicegraph.sql ~{dest_gs_uri}
            gsutil cp majiq.log ~{dest_gs_uri}
        fi
    >>>

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: 4
        memory: "4 GB"
        disks: "local-disk ~{disk_size_gb} HDD"
    }

    output {
        Array[File] majiq = glob("*.majiq")
        String splicegraph = "splicegraph.sql"
    }
}