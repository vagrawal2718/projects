#!/bin/bash

# Function to create directories and files
create_structure() {
    local base_dir="$1"
    shift
    mkdir -p "$base_dir"
    for path in "$@"; do
        if [[ "$path" =~ \.[^/]+$ ]]; then
            # Create file
            mkdir -p "$(dirname "$base_dir/$path")"
            touch "$base_dir/$path"
        else
            # Create directory
            mkdir -p "$base_dir/$path"
        fi
    done
}

# SS1 setup
create_structure "SS1" \
    "root_directory/dir_pbcui" \
    "dir_bzaca" \
    "dir_bzaca/file_ofr.txt" \
    "dir_bzaca/file_qsw.txt" \
    "dir_bzaca/file_uag.txt" \
    "dir_bzaca/dir_ccftl/dir_hbsfj" \
    "dir_qkdez/dir_htcrv/dir_mrrcz" \
    "dir_qkdez/dir_htcrv/dir_mrrcz/file_imz.txt"

# SS2 setup
create_structure "SS2" \
    "root_directory/dir_gywnw/dir_fzxpq" \
    "dir_rzuni/dir_eqfej" \
    "dir_rzuni/dir_eqfej/file_wux.txt" \
    "dir_rzuni/dir_aqmhk"

# SS3 setup
create_structure "SS3" \
    "root_directory/dir_vhfih/dir_lhkzx" \
    "dir_ctpcj" \
    "dir_ctpcj/dir_apsck" \
    "dir_lhkzx/dir_ctpcj/dir_apsck/file_hwa.txt" \
    "dir_ctpcj/dir_apsck/file_rkn.txt" \
    "dir_ctpcj/dir_hfccx" \
    "dir_ctpcj/dir_hfccx/here.txt"

# SS4 setup
create_structure "SS4" \
    "root_directory/dir_psjio/dir_ctyuy" \
    "dir_bqays" \
    "dir_bqays/dir_adecw/file_qdh.txt" \
    "dir_bqays/dir_hlxuh" \
    "dir_bqays/dir_hlxuh/file_xmu.txt" \
    "dir_bqays/dir_hlxuh/file_rwf.txt" \
    "dir_bqays/dir_hlxuh/file_zsb.txt"

# SS5 setup
create_structure "SS5" \
    "root_directory/dir_psjio/dir_kgabk/dir_jtngu" \
    "dir_sptuh" \
    "dir_sptuh/file_nda.txt" \
    "dir_sptuh/file_ytw.txt"

# SS6 setup
create_structure "SS6" \
    "root_directory/dir_vymdo" \
    "dir_pfaau" \
    "dir_pfaau/student_song" \
    "dir_pfaau/student_song/your_song.mp3" \
    "dir_pfaau/coldplay.mp3" \
    "dir_pfaau/dir_cscou" \
    "dir_pfaau/dir_cscou/dir_mbbdr" \
    "dir_pfaau/dir_cscou/dir_mbbdr/file_mpe.txt" \
    "dir_pfaau/dir_cscou/dir_rjmdf" \
    "dir_pfaau/dir_cscou/dir_rjmdf/file_kdx.txt" \
    "dir_pfaau/dir_fpkwl" \
    "dir_pfaau/dir_fpkwl/dir_cgpqn" \
    "dir_pfaau/dir_fpkwl/dir_gxueg" \
    "dir_picqp/dir_odqtp" \
    "dir_picqp/dir_picaz/dir_cdsdh" \
    "dir_picqp/dir_picaz/dir_cdsdh/file_dar.txt" \
    "dir_picqp/dir_picaz/dir_cdsdh/file_yyj.txt" \
    "dir_picqp/dir_picaz/dir_zdoid" \
    "dir_picqp/dir_picaz/dir_tnaqz" \
    "dir_picqp/dir_picaz/dir_tnaqz/file_kox.txt"

# SS7 setup
create_structure "SS7" \
    "root_directory/a_song_ice_fire" \
    "./plot_dir" \
    "./plot_dir/plot.txt"

# SS8 setup
create_structure "SS8" \
    "root_directory/gravity_falls" \
    "./gravity_subdir" \
    "./gravity_subdir/so-good.webp" \
    "./gravity_subdir2"

# SS9 setup
create_structure "SS9" \
    "root_directory/dir_gywnw/dir_fzxpq/dir_wewny" \
    "./dir_juqnm/file_pzb.txt" \
    "./dir_juqnm/file_veg.txt" \
    "./dir_juqnm/file_vpx.txt" \
    "./dir_juqnm/big_dir_test" \
    "./dir_juqnm/big_dir_test/big_file_70MB.txt" \
    "./dir_juqnm/big_dir_test/med_file_10MB.txt" \
    "./dir_juqnm/big_dir_test/med_file_15MB.txt"
