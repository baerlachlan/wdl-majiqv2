version 1.0

workflow majiq_v2 {
    input {
        Array[File] bam_g1
        Array[File] bam_g2
        File gencode_gtf
        String out_dir
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf
    }

    scatter(i in range(length(bam_g1))) {
        call majiq_sj as majiq_sj_g1 {
            input:
            bam = bam_g1[i]
            out_dir = out_dir
            gff3 = gtf_to_gff3.gff3
        }
    }

    scatter(i in range(length(bam_g2))) {
        call majiq_sj as majiq_sj_g2 {
            input:
            bam = bam_g2[i]
            out_dir = out_dir
            gff3 = gtf_to_gff3.gff3
        }
    }

    output {
        File sj = flatten([majiq_sj_g1.sj, majiq_sj_g2.sj])
    }

    meta {
        author: "Lachlan Baer"
    }
}

task gtf_to_gff3 {
    input {
        File gencode_gtf
        String out_dir
    }

    String out_gff3 = "${out_dir}/resources/annotation.gff3"

    command <<<
        cat ${gencode_gtf} | \
            sed 's/chrM/chrMT/;s/chr//' | \
            gffread -T -o ${out_gff3}
    >>>

    runtime {
        docker: "baerlachlan/gffread:v0.12.7"
        cpu: "1"
        memory: "2 GB"
        disks: "local-disk 4 HDD"
    }

    output {
        File gff3 = "${out_gff3}"
    }
}

task majiq_sj {
    input {
        File bam
        String out_dir
        File gff3
    }

    String bam_dir = basename(bam, basename(bam))
    String sample = replace(basename(bam), ".bam", "")
    String sj_file = "${sample}.sj"

    command <<<
        mkdir tmp_dir
        echo "[info]\nbamdirs=${bam_dir}\ngenome=${gff3}\n[experiments]\nsample=${sample}" > majiq.conf
		majiq build -j 1 -c majiq.conf -o tmp_dir ${gff3} --junc-files-only
		mv tmp_dir/${sj_file} ${out_dir}/sj
    >>>

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: "1"
        memory: "4 GB"
        disks: "local-disk 4 HDD"
    }

    output {
        File sj = "${out_dir}/sj/${sj_file}"
    }
}