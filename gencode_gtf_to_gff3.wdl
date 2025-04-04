version 1.0

workflow gencode_gtf_to_gff3 {
    input {
        File gencode_gtf
        String dest_gs_uri = "NULL"
        String machine_mem = "32 GB"
        String machine_disk = "local-disk 8 HDD"
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf,
        dest_gs_uri = dest_gs_uri,
        machine_mem = machine_mem,
        machine_disk = machine_disk,
    }

    output {
        File gff3 = gtf_to_gff3.gff3
    }
}

task gtf_to_gff3 {
    input {
        File gencode_gtf
        String dest_gs_uri
        String machine_mem
        String machine_disk
    }

    String ref_name = basename(gencode_gtf, ".gtf")
    String gff3_out = "~{ref_name}.gff3"

    command <<<
        ## Create the default config file for AGAT
        agat config --expose
        ## Turn off checks etc
        sed -i -E '/^(check|remove_orphan)/s/:.*/: false/' agat_config.yaml
        ## Convert GTF to GFF3
        agat_convert_sp_gxf2gxf.pl -g ~{gencode_gtf} -o ~{gff3_out}
        ## Copy to gcloud storage
        if [[ ~{dest_gs_uri} != "NULL" ]]; then
            gsutil cp ~{gff3_out} ~{dest_gs_uri}
        fi
    >>>

    runtime {
        docker: "baerlachlan/agat:v1.4.2"
        cpu: 1
        memory: machine_mem
        disks: machine_disk
    }

    output {
        File gff3 = "~{gff3_out}"
    }
}