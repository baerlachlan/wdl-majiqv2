version 1.0

workflow majiq_v2 {
    input {
        Array[File] bam_g1
        Array[File] bam_g2
        String out_dir
        String reference_genome
        File gencode_gtf
        ## Debug
        Int gtf_to_gff3_cpu = 1
        String gtf_to_gff3_mem = "4 GB"
        String gtf_to_gff3_disk = "local-disk 4 HDD"
        Int majiq_sj_cpu = 1
        String majiq_sj_mem = "4 GB"
        String majiq_sj_disk = "local-disk 4 HDD"
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf,
        out_dir = out_dir,
        ## Debug
        gtf_to_gff3_cpu = gtf_to_gff3_cpu,
        gtf_to_gff3_mem = gtf_to_gff3_mem,
        gtf_to_gff3_disk = gtf_to_gff3_disk,
    }

    scatter(i in range(length(bam_g1))) {
        call majiq_sj as majiq_sj_g1 {
            input:
            bam = bam_g1[i],
            out_dir = out_dir,
            reference_genome = reference_genome,
            gff3 = gtf_to_gff3.gff3,
            ## Debug
            majiq_sj_cpu = majiq_sj_cpu,
            majiq_sj_mem = majiq_sj_mem,
            majiq_sj_disk = majiq_sj_disk,
        }
    }

    scatter(i in range(length(bam_g2))) {
        call majiq_sj as majiq_sj_g2 {
            input:
            bam = bam_g2[i],
            out_dir = out_dir,
            reference_genome = reference_genome,
            gff3 = gtf_to_gff3.gff3,
            ## Debug
            majiq_sj_cpu = majiq_sj_cpu,
            majiq_sj_mem = majiq_sj_mem,
            majiq_sj_disk = majiq_sj_disk,
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
        ## Debug
        Int gtf_to_gff3_cpu
        String gtf_to_gff3_mem
        String gtf_to_gff3_disk
    }

    String resources_dir = "~{out_dir}/resources"
    String gff3_out = "~{resources_dir}/annotation.gff3"

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
        agat_convert_sp_gxf2gxf.pl -g patched.gtf -o ~{gff3_out}
    >>>

    runtime {
        docker: "quay.io/biocontainers/agat:1.4.2--pl5321hdfd78af_0"
        cpu: gtf_to_gff3_cpu
        memory: gtf_to_gff3_mem
        disks: gtf_to_gff3_disk
    }

    output {
        File gff3 = "~{gff3_out}"
    }
}

task majiq_sj {
    input {
        File bam
        File bai = "~{bam}.bai"
        String out_dir
        String reference_genome
        File gff3
        ## Debug
        Int majiq_sj_cpu
        String majiq_sj_mem
        String majiq_sj_disk
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
        cpu: majiq_sj_cpu
        memory: majiq_sj_mem
        disks: majiq_sj_disk
    }

    output {
        File sj = "~{out_dir}/sj/~{sj_file}"
    }
}