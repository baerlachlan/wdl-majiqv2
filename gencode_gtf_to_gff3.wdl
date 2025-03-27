version 1.0

workflow gencode_gtf_to_gff3 {
    input {
        File gencode_gtf
        String out_dir
        String machine_mem = "32 GB"
        String machine_disk = "local-disk 8 HDD"
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf,
        out_dir = out_dir,
		machine_mem = machine_mem,
		machine_disk = machine_disk,
    }

    output {
        Array[File] gff3 = gtf_to_gff3.gff3
    }
}

task gtf_to_gff3 {
    input {
        File gencode_gtf
        String out_dir
        String machine_mem
        String machine_disk
    }

    String gff3_out = "~{out_dir}/annotation.gff3"

    command <<<
        mkdir -p ~{out_dir}
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
        cpu: 1
        memory: machine_mem
        disks: machine_disk
    }

    output {
        File gff3 = "~{gff3_out}"
    }
}