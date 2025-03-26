version 1.0

workflow majiq_v2 {
    input {
        Array[File] bam_g1
        Array[File] bam_g2
        String out_dir
        String name
        String reference_genome
        File gencode_gtf
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf,
        out_dir = out_dir,
    }

    scatter(i in range(length(bam_g1))) {
        call majiq_sj as majiq_sj_g1 {
            input:
            bam = bam_g1[i],
            out_dir = out_dir,
            reference_genome = reference_genome,
            gff3 = gtf_to_gff3.gff3,
        }
    }

    scatter(i in range(length(bam_g2))) {
        call majiq_sj as majiq_sj_g2 {
            input:
            bam = bam_g2[i],
            out_dir = out_dir,
            reference_genome = reference_genome,
            gff3 = gtf_to_gff3.gff3,
        }
    }

    output {
        Array[File] sj = flatten([majiq_sj_g1.sj, majiq_sj_g2.sj])
    }
}

task gtf_to_gff3 {
    input {
        File gencode_gtf
        String out_dir
    }

    String resources_dir = "~{out_dir}/resources"
    String gff3 = "~{resources_dir}/annotation.gff3"

    command <<<
        mkdir -p ~{resources_dir}
        ## Create the default config file for AGAT
        agat config --expose
        ## Turn off checks etc
        sed -i -E '/^(check|remove_orphan)/s/:.*/: false/' agat_config.yaml
        ## Patch GTF to use Ensembl chromosome names
        cat ~{gencode_gtf} | \
            sed 's/chrM/chrMT/;s/chr//' > patched.gtf
        ## Convert GTF to GFF3
        agat_convert_sp_gxf2gxf.pl -g patched.gtf -o ~{gff3}
    >>>

    runtime {
        docker: "quay.io/biocontainers/agat:1.4.2--pl5321hdfd78af_0"
        cpu: "1"
        memory: "2 GB"
        disks: "local-disk 4 HDD"
    }

    output {
        File gff3 = "~{gff3}"
    }
}

task majiq_sj {
    input {
        File bam
        File bai = "~{bam}.bai"
        String out_dir
        String reference_genome
        File gff3
    }

    String sample = basename(bam, ".bam")
    String sj_file = "~{sample}.sj"

    command <<<
        mkdir -p ~{out_dir}/sj
        echo -e "[info]\nbamdirs=$(dirname ~{bam})\ngenome=~{reference_genome}\n[experiments]\nsample=~{sample}" > majiq.conf
        majiq build -j 1 -c majiq.conf -o . ~{gff3} --junc-files-only
        mv ~{sj_file} ~{out_dir}/sj
    >>>

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: "1"
        memory: "4 GB"
        disks: "local-disk 4 HDD"
    }

    output {
        File sj = "~{out_dir}/sj/~{sj_file}"
    }
}